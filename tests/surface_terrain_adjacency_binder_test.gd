extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencyBinderTestRoot"
	root.add_child(holder)
	var west: Node3D = PatchScript.new()
	west.name = "West"
	var east: Node3D = PatchScript.new()
	east.name = "East"
	east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	var south: Node3D = PatchScript.new()
	south.name = "South"
	south.position = Vector3(0.0, 0.0, PatchScript.PATCH_SIZE)
	var far: Node3D = PatchScript.new()
	far.name = "Far"
	far.position = Vector3(20.0, 0.0, 0.0)
	holder.add_child(west)
	holder.add_child(east)
	holder.add_child(south)
	holder.add_child(far)
	await process_frame
	await physics_frame
	var stable_ids: Dictionary = {
		west.get_instance_id(): "test/chunk/object/West",
		east.get_instance_id(): "test/chunk/object/East",
		south.get_instance_id(): "test/chunk/object/South",
		far.get_instance_id(): "test/chunk/object/Far"
	}
	var report: Dictionary = BinderScript.bind_patches([west, east, south, far], stable_ids)
	_expect(bool(report.get("ok", false)), "binder accepts a valid live patch set with persistent Stable IDs")
	_expect(int(report.get("pair_count", -1)) == 2, "binder discovers exactly the east and south adjacent pairs")
	_expect(int(report.get("descriptor_count", -1)) == 2, "binder returns one deterministic descriptor for each adjacent pair")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "west/east pair resolves to a flush join")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "flush_join", "west/south pair resolves to a flush join")
	_expect(not _ramp_enabled(west, "East") and not _ramp_enabled(east, "West"), "both sides of east/west shared edge disable their ground ramps")
	_expect(not _ramp_enabled(west, "South") and not _ramp_enabled(south, "North"), "both sides of north/south shared edge disable their ground ramps")
	_expect(_ramp_enabled(far, "West"), "non-adjacent patch retains its isolated ground ramp")

	var east_descriptor: Dictionary = _descriptor_for(report, "test/chunk/object/West", "test/chunk/object/East")
	_expect(not east_descriptor.is_empty(), "east/west seam is keyed by the two persistent Stable IDs")
	_expect(str(east_descriptor.get("owner_stable_id", "")) == "test/chunk/object/East", "descriptor owner is canonical and independent of patch array order")
	_expect(str(east_descriptor.get("first_side", "")) == "west" and str(east_descriptor.get("second_side", "")) == "east", "canonical descriptor preserves the correct reversed side orientation")

	var invalid_ids: Dictionary = stable_ids.duplicate()
	invalid_ids[east.get_instance_id()] = ""
	var invalid_report: Dictionary = BinderScript.bind_patches([west, east, south, far], invalid_ids)
	_expect(not bool(invalid_report.get("ok", true)) and str(invalid_report.get("error", "")) == "invalid_stable_id", "empty production Stable IDs are rejected during preflight")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "invalid Stable ID rejection leaves existing live adjacency unchanged")

	var duplicate_ids: Dictionary = stable_ids.duplicate()
	duplicate_ids[east.get_instance_id()] = duplicate_ids[west.get_instance_id()]
	var duplicate_id_report: Dictionary = BinderScript.bind_patches([west, east, south, far], duplicate_ids)
	_expect(not bool(duplicate_id_report.get("ok", true)) and str(duplicate_id_report.get("error", "")) == "duplicate_stable_id", "duplicate Stable IDs are rejected before live edges are cleared")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "duplicate Stable ID rejection preserves the previous adjacency")

	var raised := {"height_level": 2, "surface_type": "metal", "revision": 1}
	_expect(bool(west.call("apply_world_object_state", raised)), "live terrain edit accepts a higher persisted state")
	var raised_report: Dictionary = BinderScript.bind_patches([west, east, south, far], stable_ids)
	_expect(bool(raised_report.get("ok", false)), "binder rebuilds descriptors after a terrain edit")
	_expect(str(east.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "east neighbor immediately receives west patch height changes")
	_expect(str(south.call("get_edge_policy", "north").get("mode", "")) == "neighbor_higher", "south neighbor immediately receives west patch height changes")
	var raised_descriptor: Dictionary = _descriptor_for(raised_report, stable_ids[west.get_instance_id()], stable_ids[east.get_instance_id()])
	_expect(str(raised_descriptor.get("mode", "")) == "unequal_height", "unequal-height seam descriptor switches to transition-required mode")
	_expect(str(raised_descriptor.get("higher_stable_id", "")) == stable_ids[west.get_instance_id()], "descriptor records the higher terrain patch")
	_expect(is_equal_approx(float(raised_descriptor.get("height_delta", 0.0)), 0.5), "descriptor records the exact 0.5 metre height difference")

	var reduced := {"height_level": 0, "surface_type": "soil", "revision": 2}
	_expect(bool(east.call("apply_world_object_state", reduced)), "neighbor can independently restore a lower terrain state")
	var reduced_report: Dictionary = BinderScript.bind_patches([west, east, south, far], stable_ids)
	_expect(bool(reduced_report.get("ok", false)), "binder rebuilds after the second side changes")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "local_higher", "west patch updates its policy after east neighbor changes")

	var after_unload: Dictionary = BinderScript.bind_patches([west, south, far], stable_ids)
	_expect(bool(after_unload.get("ok", false)) and int(after_unload.get("pair_count", -1)) == 1, "rebinding after one patch unload removes only its stale adjacency")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "ground_ramp", "unloaded neighbor restores the west outer ramp")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "local_higher", "remaining south neighbor stays bound with the correct local-higher policy")

	var duplicate := PatchScript.new()
	duplicate.name = "Duplicate"
	duplicate.position = west.position
	holder.add_child(duplicate)
	await process_frame
	var rejected: Dictionary = BinderScript.bind_patches([west, south, duplicate], stable_ids)
	_expect(not bool(rejected.get("ok", true)) and str(rejected.get("error", "")) == "duplicate_position", "duplicate patch positions are rejected before rebinding")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "local_higher", "rejected duplicate leaves the existing valid adjacency intact")
	holder.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("Surface terrain adjacency binder tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _descriptor_for(report: Dictionary, first_id: String, second_id: String) -> Dictionary:
	for descriptor_value in report.get("descriptors", {}).values():
		var descriptor: Dictionary = descriptor_value
		var matches: bool = (
			str(descriptor.get("first_stable_id", "")) == first_id and str(descriptor.get("second_stable_id", "")) == second_id
		) or (
			str(descriptor.get("first_stable_id", "")) == second_id and str(descriptor.get("second_stable_id", "")) == first_id
		)
		if matches:
			return descriptor
	return {}

func _ramp_enabled(patch: Node3D, side: String) -> bool:
	var body := patch.get_node_or_null("TerrainRampBody_" + side) as StaticBody3D
	if body == null:
		return false
	var collision := body.get_node_or_null("TerrainRampCollision_" + side) as CollisionShape3D
	return body.collision_layer == 1 and collision != null and not collision.disabled

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
