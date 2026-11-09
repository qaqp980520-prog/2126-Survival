extends SceneTree

const PlannerScript = preload("res://systems/SurfaceTerrainAffectedComponentPlanner.gd")
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	holder.name = "TerrainAffectedComponentPlannerTestRoot"
	root.add_child(holder)
	var old_patch := Node3D.new()
	old_patch.name = "OldSharedPatch"
	var candidate_patch := Node3D.new()
	candidate_patch.name = "CandidateSharedPatch"
	var isolated_patch := Node3D.new()
	isolated_patch.name = "IsolatedPatch"
	isolated_patch.position = Vector3(20.0, 0.0, 0.0)
	holder.add_child(old_patch)
	holder.add_child(candidate_patch)
	holder.add_child(isolated_patch)
	await process_frame

	_test_old_and_candidate_topology_union(old_patch, candidate_patch, isolated_patch)
	_test_seed_without_corner_reports()
	_test_invalid_reports_fail_closed(old_patch)
	_test_corner_keys_match_transition_manager(old_patch)
	await _test_real_resolver_reports_include_ineligible_fallback()

	holder.queue_free()
	await process_frame
	if failures.is_empty():
		print("Surface terrain affected-component planner tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _test_old_and_candidate_topology_union(old_patch: Node3D, candidate_patch: Node3D, isolated_patch: Node3D) -> void:
	var old_reports: Array = [
		{
			"stable_id": "terrain/shared",
			"corner": "north_east",
			"edge_keys": ["seed", "bridge"],
			"policy": "step_fallback"
		}
	]
	var candidate_reports: Array = [
		{
			"stable_id": "terrain/shared",
			"corner": "south_east",
			"edge_keys": ["bridge", "tail"],
			"policy": "step_fallback"
		},
		{
			"stable_id": "terrain/isolated",
			"corner": "north_east",
			"edge_keys": ["isolated_a", "isolated_b"],
			"policy": "step_fallback"
		}
	]
	var old_patches: Dictionary = {"terrain/shared": old_patch}
	var candidate_patches: Dictionary = {
		"terrain/shared": candidate_patch,
		"terrain/isolated": isolated_patch
	}
	var result: Dictionary = PlannerScript.build_closure(
		["seed"],
		old_reports,
		old_patches,
		candidate_reports,
		candidate_patches,
		2.0
	)
	_expect(bool(result.get("ok", false)), "old and candidate report union builds a valid closure")
	_expect(result.get("edge_keys", []) == ["bridge", "seed", "tail"], "closure crosses a shared edge from old topology into candidate topology")
	_expect(result.get("junction_keys", []) == ["1.000|0.000|-1.000", "1.000|0.000|1.000"], "closure contains both endpoint junctions in deterministic order")
	_expect(not result.get("edge_keys", []).has("isolated_a") and not result.get("edge_keys", []).has("isolated_b"), "disconnected ineligible fallback component remains outside the closure")
	_expect(int(result.get("old_report_count", -1)) == 1 and int(result.get("candidate_report_count", -1)) == 2, "closure records both old and candidate report counts")

	var reordered_reports: Array = candidate_reports.duplicate(true)
	reordered_reports.reverse()
	var reordered: Dictionary = PlannerScript.build_closure(
		["tail", "seed", "seed"],
		old_reports.duplicate(true),
		old_patches,
		reordered_reports,
		candidate_patches,
		2.0
	)
	_expect(bool(reordered.get("ok", false)), "duplicate and unsorted seeds are normalized")
	_expect(reordered.get("edge_keys", []) == result.get("edge_keys", []), "edge closure ordering is independent of seed insertion order")
	_expect(reordered.get("junction_keys", []) == result.get("junction_keys", []), "junction closure ordering is deterministic")


func _test_seed_without_corner_reports() -> void:
	var orphan: Dictionary = PlannerScript.build_closure(["orphan"], [], {}, [], {}, 2.0)
	_expect(bool(orphan.get("ok", false)) and orphan.get("edge_keys", []) == ["orphan"], "edge without corner reports remains a one-edge component")
	_expect(orphan.get("junction_keys", []).is_empty(), "edge without reports has no synthetic junction")
	var empty: Dictionary = PlannerScript.build_closure([], [], {}, [], {}, 2.0)
	_expect(bool(empty.get("ok", false)) and empty.get("edge_keys", []).is_empty(), "empty seed set returns an empty successful closure")


func _test_invalid_reports_fail_closed(patch: Node3D) -> void:
	var missing_patch: Dictionary = PlannerScript.build_closure(
		["seed"],
		[{"stable_id": "missing", "corner": "north_east", "edge_keys": ["seed", "other"]}],
		{},
		[],
		{},
		2.0
	)
	_expect(not bool(missing_patch.get("ok", true)) and str(missing_patch.get("error", "")) == "missing_report_patch", "report referencing an absent old patch fails closed")
	var invalid_corner: Dictionary = PlannerScript.build_closure(
		["seed"],
		[{"stable_id": "terrain/valid", "corner": "center", "edge_keys": ["seed", "other"]}],
		{"terrain/valid": patch},
		[],
		{},
		2.0
	)
	_expect(not bool(invalid_corner.get("ok", true)) and str(invalid_corner.get("error", "")) == "invalid_corner_or_position", "unknown corner fails closed")
	var invalid_edge: Dictionary = PlannerScript.build_closure(
		["seed"],
		[{"stable_id": "terrain/valid", "corner": "north_east", "edge_keys": ["seed", 7]}],
		{"terrain/valid": patch},
		[],
		{},
		2.0
	)
	_expect(not bool(invalid_edge.get("ok", true)) and str(invalid_edge.get("error", "")) == "invalid_report_edge_key", "non-string report edge key fails closed")


func _test_corner_keys_match_transition_manager(patch: Node3D) -> void:
	var manager: Node3D = ManagerScript.new()
	root.add_child(manager)
	for corner in ["north_east", "south_east", "south_west", "north_west"]:
		var offset: Vector3 = manager.call("_corner_offset", corner)
		var expected: String = str(manager.call("_corner_key", patch.global_position + offset))
		var actual: String = PlannerScript.junction_key_for_corner(patch.global_position, corner, 2.0)
		_expect(actual == expected, "%s junction key matches the production manager format" % corner)
	_expect(PlannerScript.junction_key_for_corner(patch.global_position, "invalid", 2.0).is_empty(), "unknown corner does not produce a junction key")
	manager.queue_free()


func _test_real_resolver_reports_include_ineligible_fallback() -> void:
	var holder := Node3D.new()
	holder.name = "RealResolverAffectedComponentFixture"
	root.add_child(holder)
	var north_west: Node3D = PatchScript.new()
	north_west.name = "NorthWest"
	var north_east: Node3D = PatchScript.new()
	north_east.name = "NorthEast"
	north_east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	var south_west: Node3D = PatchScript.new()
	south_west.name = "SouthWest"
	south_west.position = Vector3(0.0, 0.0, PatchScript.PATCH_SIZE)
	var south_east: Node3D = PatchScript.new()
	south_east.name = "SouthEast"
	south_east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, PatchScript.PATCH_SIZE)
	var patches: Array[Node3D] = [north_west, north_east, south_west, south_east]
	for patch in patches:
		holder.add_child(patch)
	await process_frame
	_expect(_apply_patch_state(north_west, 0, 1), "real checkerboard north-west baseline is valid")
	_expect(_apply_patch_state(north_east, 2, 1), "real checkerboard north-east baseline is valid")
	_expect(_apply_patch_state(south_west, 2, 1), "real checkerboard south-west baseline is valid")
	_expect(_apply_patch_state(south_east, 0, 1), "real checkerboard south-east baseline is valid")
	var stable_ids: Dictionary = {
		north_west.get_instance_id(): "real/north_west",
		north_east.get_instance_id(): "real/north_east",
		south_west.get_instance_id(): "real/south_west",
		south_east.get_instance_id(): "real/south_east"
	}
	var patches_by_stable_id: Dictionary = {
		"real/north_west": north_west,
		"real/north_east": north_east,
		"real/south_west": south_west,
		"real/south_east": south_east
	}
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "real checkerboard binder builds its four-edge topology")
	if not bool(binding.get("ok", false)):
		holder.queue_free()
		await process_frame
		return
	var edge_keys: Array[String] = []
	for key in binding.get("descriptors", {}).keys():
		edge_keys.append(str(key))
	edge_keys.sort()
	var manager: Node3D = ManagerScript.new()
	holder.add_child(manager)
	await process_frame
	var initial: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
	_expect(bool(initial.get("ok", false)) and int(initial.get("corner_cap_count", -1)) == 4, "real manager commits the eligible four-way checkerboard caps")
	var eligible_reports: Array = manager.call("get_blocked_corner_reports")
	_expect(eligible_reports.size() == 4 and edge_keys.size() == 4, "real resolver emits four corner reports for the junction")
	var eligible_closure: Dictionary = PlannerScript.build_closure(
		[edge_keys[0]],
		eligible_reports,
		patches_by_stable_id,
		[],
		{},
		PatchScript.PATCH_SIZE
	)
	_expect(bool(eligible_closure.get("ok", false)), "planner accepts the real resolver's eligible reports")
	_expect(eligible_closure.get("edge_keys", []) == edge_keys, "one seeded edge reaches all four real checkerboard edges")
	_expect(eligible_closure.get("junction_keys", []).size() == 1, "eligible checkerboard closure contains its single shared junction")

	_expect(_apply_patch_state(north_west, 1, 2), "one corner height change creates a valid but cap-ineligible checkerboard")
	var changed_binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(changed_binding.get("ok", false)), "cap-ineligible checkerboard still has valid edge descriptors")
	var changed_sync: Dictionary = manager.call("sync_transitions", changed_binding.get("descriptors", {}), patches_by_stable_id)
	_expect(bool(changed_sync.get("ok", false)) and int(manager.call("get_corner_cap_count")) == 0, "real manager falls back to steps when the eight midpoints disagree")
	var fallback_reports: Array = manager.call("get_blocked_corner_reports")
	_expect(fallback_reports.size() == 4, "real resolver retains all four reports after cap eligibility fails")
	var all_fallback: bool = true
	for report_value in fallback_reports:
		if not (report_value is Dictionary) or str(report_value.get("policy", "")) != "step_fallback":
			all_fallback = false
	_expect(all_fallback, "ineligible real resolver reports retain the step-fallback policy")
	var fallback_closure: Dictionary = PlannerScript.build_closure(
		[edge_keys[0]],
		[],
		{},
		fallback_reports,
		patches_by_stable_id,
		PatchScript.PATCH_SIZE
	)
	_expect(bool(fallback_closure.get("ok", false)), "planner accepts real ineligible fallback reports")
	_expect(fallback_closure.get("edge_keys", []) == edge_keys, "fallback reports still connect the full four-edge affected component")
	await _release_holder(holder)


func _apply_patch_state(patch: Node3D, height_level: int, revision: int) -> bool:
	return bool(patch.call("apply_world_object_state", {
		"height_level": height_level,
		"surface_type": "metal" if height_level >= 2 else "soil",
		"revision": revision
	}))


func _release_holder(holder: Node3D) -> void:
	if is_instance_valid(holder):
		holder.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
