extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")

class FixturePatch:
	extends Node3D
	const FIXTURE_PATCH_SIZE: float = 2.0

	var neighbors: Dictionary = {}
	var state: Dictionary = {"height_level": 0, "surface_type": "soil", "revision": 0}
	var fail_bind: bool = false
	var fail_clear: bool = false
	var batch_depth: int = 0
	var batch_begin_count: int = 0
	var batch_end_count: int = 0
	var clear_call_count: int = 0

	func bind_neighbor_patch(side: String, neighbor: Node3D) -> bool:
		if fail_bind or not ["east", "west", "north", "south"].has(side) or neighbor == null:
			return false
		neighbors[side] = neighbor
		return true

	func clear_neighbor_edge_state(side: String) -> bool:
		if fail_clear:
			return false
		clear_call_count += 1
		var neighbor: Node3D = neighbors.get(side) as Node3D
		neighbors.erase(side)
		if is_instance_valid(neighbor) and neighbor.has_method("clear_neighbor_edge_state_local"):
			neighbor.call("clear_neighbor_edge_state_local", _opposite_side(side))
		return true

	func clear_neighbor_edge_state_local(side: String) -> void:
		neighbors.erase(side)

	func get_bound_neighbor_patch(side: String) -> Node3D:
		return neighbors.get(side) as Node3D

	func _opposite_side(side: String) -> String:
		match side:
			"east": return "west"
			"west": return "east"
			"north": return "south"
			"south": return "north"
			_: return ""

	func get_bound_neighbor_patches() -> Array[Node3D]:
		var result: Array[Node3D] = []
		for neighbor_value in neighbors.values():
			var neighbor: Node3D = neighbor_value as Node3D
			if is_instance_valid(neighbor) and not result.has(neighbor):
				result.append(neighbor)
		return result

	func begin_collision_segmentation_batch() -> void:
		batch_depth += 1
		batch_begin_count += 1

	func end_collision_segmentation_batch() -> bool:
		if batch_depth <= 0:
			return false
		batch_depth -= 1
		batch_end_count += 1
		return true

	func get_edge_ramp_profile() -> Dictionary:
		return {"patch_size": FIXTURE_PATCH_SIZE}

	func get_world_object_state() -> Dictionary:
		return state.duplicate(true)

	func validate_world_object_state(candidate: Dictionary) -> bool:
		if candidate.size() != 3 or not candidate.has("height_level") or not candidate.has("surface_type") or not candidate.has("revision"):
			return false
		return (
			candidate["height_level"] is int
			and int(candidate["height_level"]) >= 0
			and int(candidate["height_level"]) <= 2
			and candidate["surface_type"] is String
			and ["soil", "rock", "metal"].has(str(candidate["surface_type"]))
			and candidate["revision"] is int
			and int(candidate["revision"]) >= 0
		)

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
	for patch in [west, east, south, far]:
		_expect(_segmentation_refresh_count(patch) == 0, "%s refresh counter is disabled by default" % patch.name)
		patch.call("set_collision_segmentation_refresh_counter_enabled", true)
	var stable_ids: Dictionary = {
		west.get_instance_id(): "test/chunk/object/West",
		east.get_instance_id(): "test/chunk/object/East",
		south.get_instance_id(): "test/chunk/object/South",
		far.get_instance_id(): "test/chunk/object/Far"
	}
	var initial_refresh_counts: Dictionary = {}
	for patch in [west, east, south, far]:
		initial_refresh_counts[patch.get_instance_id()] = _segmentation_refresh_count(patch)
	var report: Dictionary = BinderScript.bind_patches([west, east, south, far], stable_ids)
	_expect(bool(report.get("ok", false)), "binder accepts a valid live patch set with persistent Stable IDs")
	_expect(int(report.get("pair_count", -1)) == 2, "binder discovers exactly the east and south adjacent pairs")
	_expect(int(report.get("descriptor_count", -1)) == 2, "binder returns one deterministic descriptor for each adjacent pair")
	for patch in [west, east, south, far]:
		var refresh_delta: int = _segmentation_refresh_count(patch) - int(initial_refresh_counts[patch.get_instance_id()])
		_expect(refresh_delta == 0, "%s empty-side clear does not refresh unchanged segmentation during initial bind" % patch.name)
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

	# Invalid persisted patch state must be rejected before the binder clears any live edge.
	east.set("_surface_type", "unsupported_material")
	var invalid_state_report: Dictionary = BinderScript.bind_patches([west, east, south, far], stable_ids)
	_expect(not bool(invalid_state_report.get("ok", true)) and str(invalid_state_report.get("error", "")) == "invalid_patch_state", "invalid terrain material is rejected during binder preflight")
	east.set("_surface_type", "soil")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "flush_join", "invalid terrain-state rejection preserves the previous live adjacency")

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

	var unload_refresh_counts_before: Dictionary = {}
	for patch in [west, east, south, far]:
		unload_refresh_counts_before[patch.get_instance_id()] = _segmentation_refresh_count(patch)
	var after_unload: Dictionary = BinderScript.bind_patches([west, south, far], stable_ids)
	_expect(bool(after_unload.get("ok", false)) and int(after_unload.get("pair_count", -1)) == 1, "rebinding after one patch unload removes only its stale adjacency")
	_expect(str(west.call("get_edge_policy", "east").get("mode", "")) == "ground_ramp", "unloaded neighbor restores the west outer ramp")
	_expect(str(west.call("get_edge_policy", "south").get("mode", "")) == "local_higher", "remaining south neighbor stays bound with the correct local-higher policy")
	for patch in [west, east, south, far]:
		var refresh_delta: int = _segmentation_refresh_count(patch) - int(unload_refresh_counts_before[patch.get_instance_id()])
		var expected_refresh_delta: int = 0 if patch == far else 1
		_expect(refresh_delta == expected_refresh_delta, "%s refreshes only when an existing reciprocal edge changes during unload" % patch.name)

	var nested_refresh_before: int = _segmentation_refresh_count(west)
	west.call("begin_collision_segmentation_batch")
	west.call("begin_collision_segmentation_batch")
	west.call("clear_neighbor_edge_state", "south")
	west.call("clear_neighbor_edge_state", "west")
	_expect(_segmentation_refresh_count(west) == nested_refresh_before, "nested segmentation batch defers refresh while scopes remain open")
	_expect(bool(west.call("end_collision_segmentation_batch")), "inner segmentation batch closes successfully")
	_expect(_segmentation_refresh_count(west) == nested_refresh_before, "inner batch close does not refresh before the outer scope ends")
	_expect(bool(west.call("end_collision_segmentation_batch")), "outer segmentation batch closes successfully")
	_expect(_segmentation_refresh_count(west) == nested_refresh_before + 1, "outer batch close performs exactly one deferred segmentation refresh")
	_expect(not bool(west.call("end_collision_segmentation_batch")), "unmatched segmentation batch close is rejected")
	var west_immediate_before: int = _segmentation_refresh_count(west)
	var east_immediate_before: int = _segmentation_refresh_count(east)
	_expect(bool(west.call("bind_neighbor_patch", "east", east)) and bool(east.call("bind_neighbor_patch", "west", west)), "public immediate-clear fixture establishes a reciprocal seam")
	west.call("clear_neighbor_edge_state", "east")
	_expect(_segmentation_refresh_count(west) == west_immediate_before + 1, "public single-side clear immediately refreshes a changed local patch outside a batch")
	_expect(_segmentation_refresh_count(east) == east_immediate_before + 1, "public single-side clear immediately refreshes its changed reciprocal patch")
	var no_op_refresh_before: int = _segmentation_refresh_count(west)
	west.call("clear_neighbor_edge_state", "north")
	_expect(_segmentation_refresh_count(west) == no_op_refresh_before, "clearing an already-empty side does not refresh unchanged collision segmentation")
	_expect(bool(west.call("bind_neighbor_patch", "south", south)) and bool(south.call("bind_neighbor_patch", "north", west)), "restore the existing south seam before duplicate-position preflight")

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
	await _test_large_spatial_index_grid()
	await _test_spatial_index_tolerance_boundaries()
	await _test_batch_scope_cleanup_on_failures()
	await _test_reciprocal_clear_deduplication()
	if failures.is_empty():
		print("Surface terrain adjacency binder tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func _test_large_spatial_index_grid() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencySpatialIndexGridFixture"
	root.add_child(holder)
	var patches: Array[Node3D] = []
	var stable_ids: Dictionary = {}
	for x_index in range(20):
		for z_index in range(20):
			var patch := FixturePatch.new()
			patch.name = "Patch_%d_%d" % [x_index, z_index]
			patch.position = Vector3(float(x_index - 10) * 2.0, 0.0, float(z_index - 10) * 2.0)
			holder.add_child(patch)
			patches.append(patch)
			stable_ids[patch.get_instance_id()] = "spatial/grid/%d/%d" % [x_index, z_index]
	await process_frame
	await physics_frame

	var report: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	var expected_pairs: int = 20 * 19 + 19 * 20
	var patch_count: int = 20 * 20
	_expect(bool(report.get("ok", false)), "spatial index accepts a 20x20 patch grid across negative and positive coordinates")
	_expect(int(report.get("patch_count", -1)) == patch_count, "spatial index reports all 400 patches")
	_expect(int(report.get("pair_count", -1)) == expected_pairs, "spatial index discovers exactly 760 cardinal adjacency pairs")
	_expect(int(report.get("descriptor_count", -1)) == expected_pairs, "spatial index builds one descriptor per cardinal pair")
	_expect(int(report.get("adjacency_candidate_checks", -1)) == expected_pairs, "adjacency candidate checks equal the 760 actual neighbor pairs")
	_expect(int(report.get("duplicate_position_candidate_checks", -1)) == 0, "well-spaced grid requires no duplicate-position candidate comparisons")
	_expect(int(report.get("position_bucket_lookups", -1)) == patch_count * 27, "duplicate validation checks a fixed 27-bucket neighborhood per patch")
	_expect(int(report.get("adjacency_bucket_lookups", -1)) == patch_count * 4 * 27, "adjacency discovery checks a fixed 27-bucket neighborhood per cardinal side")
	var center_index: int = 10 * 20 + 10
	var center: FixturePatch = patches[center_index] as FixturePatch
	_expect(center.neighbors.size() == 4, "interior grid patch binds all four cardinal neighbors")
	holder.queue_free()
	await process_frame
	await process_frame

func _test_spatial_index_tolerance_boundaries() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencySpatialIndexToleranceFixture"
	root.add_child(holder)
	var left := FixturePatch.new()
	left.name = "ToleranceLeft"
	left.position = Vector3(-0.001, 0.0, 0.0)
	var right := FixturePatch.new()
	right.name = "ToleranceRight"
	right.position = Vector3(2.001, 0.0, 0.0)
	holder.add_child(left)
	holder.add_child(right)
	await process_frame
	var stable_ids: Dictionary = {
		left.get_instance_id(): "spatial/tolerance/left",
		right.get_instance_id(): "spatial/tolerance/right"
	}
	var valid_report: Dictionary = BinderScript.bind_patches([left, right], stable_ids)
	_expect(bool(valid_report.get("ok", false)) and int(valid_report.get("pair_count", -1)) == 1, "adjacency within the 0.01 tolerance is found across neighboring spatial buckets")
	_expect(left.neighbors.get("east") == right and right.neighbors.get("west") == left, "tolerance-boundary adjacency binds both reciprocal sides")

	var duplicate := FixturePatch.new()
	duplicate.name = "NearDuplicate"
	duplicate.position = left.position + Vector3(0.005, 0.0, 0.0)
	holder.add_child(duplicate)
	await process_frame
	var extended_ids: Dictionary = stable_ids.duplicate()
	extended_ids[duplicate.get_instance_id()] = "spatial/tolerance/duplicate"
	var duplicate_report: Dictionary = BinderScript.bind_patches([left, right, duplicate], extended_ids)
	_expect(not bool(duplicate_report.get("ok", true)) and str(duplicate_report.get("error", "")) == "duplicate_position", "near-duplicate positions across a bucket boundary are rejected")
	_expect(left.neighbors.get("east") == right and right.neighbors.get("west") == left, "duplicate-position preflight preserves existing live adjacency")
	holder.queue_free()
	await process_frame
	await process_frame

func _test_batch_scope_cleanup_on_failures() -> void:
	var clear_holder := Node3D.new()
	clear_holder.name = "TerrainAdjacencyClearFailureBatchFixture"
	root.add_child(clear_holder)
	var clear_first := FixturePatch.new()
	clear_first.position = Vector3.ZERO
	var clear_second := FixturePatch.new()
	clear_second.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	clear_first.fail_clear = true
	clear_holder.add_child(clear_first)
	clear_holder.add_child(clear_second)
	await process_frame
	var clear_ids: Dictionary = {
		clear_first.get_instance_id(): "batch/clear/first",
		clear_second.get_instance_id(): "batch/clear/second"
	}
	var clear_report: Dictionary = BinderScript.bind_patches([clear_first, clear_second], clear_ids)
	_expect(not bool(clear_report.get("ok", true)) and str(clear_report.get("error", "")) == "clear_neighbor_failed", "binder reports a clear failure while a segmentation batch is open")
	_expect(clear_first.batch_depth == 0 and clear_second.batch_depth == 0, "clear failure closes every started segmentation batch scope")
	_expect(clear_first.batch_begin_count == 1 and clear_first.batch_end_count == 1 and clear_second.batch_begin_count == 1 and clear_second.batch_end_count == 1, "clear failure begins and closes each patch batch exactly once")
	clear_holder.queue_free()
	await process_frame
	await process_frame

	var bind_holder := Node3D.new()
	bind_holder.name = "TerrainAdjacencyBindFailureBatchFixture"
	root.add_child(bind_holder)
	var bind_first := FixturePatch.new()
	bind_first.position = Vector3.ZERO
	var bind_second := FixturePatch.new()
	bind_second.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	bind_second.fail_bind = true
	bind_holder.add_child(bind_first)
	bind_holder.add_child(bind_second)
	await process_frame
	var bind_ids: Dictionary = {
		bind_first.get_instance_id(): "batch/bind/first",
		bind_second.get_instance_id(): "batch/bind/second"
	}
	var bind_report: Dictionary = BinderScript.bind_patches([bind_first, bind_second], bind_ids)
	_expect(not bool(bind_report.get("ok", true)) and str(bind_report.get("error", "")) == "neighbor_bind_failed", "binder reports a neighbor-bind failure while a segmentation batch is open")
	_expect(bind_first.batch_depth == 0 and bind_second.batch_depth == 0, "neighbor-bind failure closes every started segmentation batch scope")
	_expect(bind_first.batch_begin_count == 1 and bind_first.batch_end_count == 1 and bind_second.batch_begin_count == 1 and bind_second.batch_end_count == 1, "neighbor-bind failure begins and closes each patch batch exactly once")
	_expect(bind_first.neighbors.is_empty() and bind_second.neighbors.is_empty(), "neighbor-bind failure cleanup removes partially applied fixture edges")
	bind_holder.queue_free()
	await process_frame
	await process_frame

func _test_reciprocal_clear_deduplication() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAdjacencyReciprocalClearDedupFixture"
	root.add_child(holder)
	var west := FixturePatch.new()
	west.name = "DedupWest"
	var east := FixturePatch.new()
	east.name = "DedupEast"
	east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	var south := FixturePatch.new()
	south.name = "DedupSouth"
	south.position = Vector3(0.0, 0.0, PatchScript.PATCH_SIZE)
	var external := FixturePatch.new()
	external.name = "DedupExternalSouth"
	external.position = Vector3(0.0, 0.0, PatchScript.PATCH_SIZE * 2.0)
	for patch in [west, east, south, external]:
		holder.add_child(patch)
	await process_frame
	var stable_ids: Dictionary = {
		west.get_instance_id(): "dedup/chunk/west",
		east.get_instance_id(): "dedup/chunk/east",
		south.get_instance_id(): "dedup/chunk/south",
		external.get_instance_id(): "dedup/chunk/external"
	}
	var initial: Dictionary = BinderScript.bind_patches([west, east, south, external], stable_ids)
	_expect(bool(initial.get("ok", false)) and int(initial.get("pair_count", -1)) == 3, "dedup fixture creates two loaded seams and one outgoing external seam")
	for patch in [west, east, south, external]:
		patch.clear_call_count = 0
	var partial: Dictionary = BinderScript.bind_patches([west, east, south], stable_ids)
	_expect(bool(partial.get("ok", false)) and int(partial.get("pair_count", -1)) == 2, "deduplicated clear rebuilds the two retained loaded seams")
	var clear_calls: int = west.clear_call_count + east.clear_call_count + south.clear_call_count
	_expect(clear_calls == 10, "two loaded reciprocal seams require one public clear call each instead of two")
	_expect(external.neighbors.is_empty(), "one-sided unload clear removes the outgoing external reciprocal neighbor")
	_expect(west.neighbors.get("east") == east and east.neighbors.get("west") == west, "deduplicated clear preserves the rebuilt east/west reciprocal seam")
	_expect(west.neighbors.get("south") == south and south.neighbors.get("north") == west, "deduplicated clear preserves the rebuilt north/south reciprocal seam")
	holder.queue_free()
	await process_frame
	await process_frame


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

func _segmentation_refresh_count(patch: Node3D) -> int:
	if not is_instance_valid(patch) or not patch.has_method("get_collision_segmentation_refresh_count"):
		return -1
	return int(patch.call("get_collision_segmentation_refresh_count"))

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
