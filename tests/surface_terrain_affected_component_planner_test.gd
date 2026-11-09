extends SceneTree

const PlannerScript = preload("res://systems/SurfaceTerrainAffectedComponentPlanner.gd")
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

	var reordered: Dictionary = PlannerScript.build_closure(
		["tail", "seed", "seed"],
		[],
		old_patches,
		candidate_reports.duplicate(true),
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
	await process_frame
	for corner in ["north_east", "south_east", "south_west", "north_west"]:
		var offset: Vector3 = manager.call("_corner_offset", corner)
		var expected: String = str(manager.call("_corner_key", patch.global_position + offset))
		var actual: String = PlannerScript.junction_key_for_corner(patch.global_position, corner, 2.0)
		_expect(actual == expected, "%s junction key matches the production manager format" % corner)
	_expect(PlannerScript.junction_key_for_corner(patch.global_position, "invalid", 2.0).is_empty(), "unknown corner does not produce a junction key")
	manager.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
