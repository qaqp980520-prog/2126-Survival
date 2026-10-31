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
	var report: Dictionary = BinderScript.bind_patches([west, east, south, far])
	_expect(bool(report.get("ok", false)), "binder accepts a valid live patch set")
	_expect(int(report.get("pair_count", -1)) == 2, "binder discovers exactly the east and south adjacent pairs")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "west/east pair resolves to a flush join")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "flush_join", "west/south pair resolves to a flush join")
	_expect(not _ramp_enabled(west, "East") and not _ramp_enabled(east, "West"), "both sides of east/west shared edge disable their ground ramps")
	_expect(not _ramp_enabled(west, "South") and not _ramp_enabled(south, "North"), "both sides of north/south shared edge disable their ground ramps")
	_expect(_ramp_enabled(far, "West"), "non-adjacent patch retains its isolated ground ramp")
	var raised := {"height_level": 2, "surface_type": "metal", "revision": 1}
	_expect(bool(west.call("apply_world_object_state", raised)), "live terrain edit accepts a higher persisted state")
	_expect(str(east.call("get_edge_policy", "west").get("mode", "")) == "neighbor_higher", "east neighbor immediately receives west patch height changes")
	_expect(str(south.call("get_edge_policy", "north").get("mode", "")) == "neighbor_higher", "south neighbor immediately receives west patch height changes")
	var reduced := {"height_level": 0, "surface_type": "soil", "revision": 2}
	_expect(bool(east.call("apply_world_object_state", reduced)), "neighbor can independently restore a lower terrain state")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "local_higher", "west patch updates its policy after east neighbor changes")
	var after_unload: Dictionary = BinderScript.bind_patches([west, south, far])
	_expect(bool(after_unload.get("ok", false)) and int(after_unload.get("pair_count", -1)) == 1, "rebinding after one patch unload removes only its stale adjacency")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "ground_ramp", "unloaded neighbor restores the west outer ramp")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "neighbor_higher", "remaining south neighbor stays bound")
	var duplicate := PatchScript.new()
	duplicate.name = "Duplicate"
	duplicate.position = west.position
	holder.add_child(duplicate)
	await process_frame
	var rejected: Dictionary = BinderScript.bind_patches([west, south, duplicate])
	_expect(not bool(rejected.get("ok", true)) and str(rejected.get("error", "")) == "duplicate_position", "duplicate patch positions are rejected before rebinding")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "neighbor_higher", "rejected duplicate leaves the existing valid adjacency intact")
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
