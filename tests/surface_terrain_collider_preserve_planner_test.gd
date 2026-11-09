extends SceneTree

const PlannerScript = preload("res://systems/SurfaceTerrainColliderPreservePlanner.gd")
const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_edge_preserve_stage_retire_partition()
	_test_edge_closure_fail_closed()
	_test_corner_cap_preserve_stage_retire_partition()
	_test_corner_cap_closure_fail_closed()
	await _test_real_manager_corner_cap_records()
	if failures.is_empty():
		print("Surface terrain collider preserve planner tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _test_edge_preserve_stage_retire_partition() -> void:
	var old_edges: Dictionary = {
		"edge/outside": {"reuse_signature": ["same", 1], "body_reusable": true, "patch_states_active": false},
		"edge/same": {"reuse_signature": ["same", 2], "body_reusable": true, "patch_states_active": true},
		"edge/changed": {"reuse_signature": ["old", 3], "body_reusable": true, "patch_states_active": true},
		"edge/removed": {"reuse_signature": ["removed", 4], "body_reusable": true, "patch_states_active": true},
		"edge/rebuild": {"reuse_signature": ["rebuild", 5], "body_reusable": false, "patch_states_active": true}
	}
	var candidate_edges: Dictionary = {
		"edge/same": {"reuse_signature": ["same", 2]},
		"edge/changed": {"reuse_signature": ["new", 3]},
		"edge/rebuild": {"reuse_signature": ["rebuild", 5]},
		"edge/new": {"reuse_signature": ["new", 6]}
	}
	var result: Dictionary = PlannerScript.build_plan(
		["edge/new", "edge/rebuild", "edge/removed", "edge/changed", "edge/same", "edge/same"],
		[],
		old_edges,
		candidate_edges,
		{},
		{}
	)
	_expect(bool(result.get("ok", false)), "valid edge resource inputs produce a plan")
	_expect(result.get("preserve_edge_keys", []) == ["edge/outside", "edge/same"], "unchanged live edges inside and outside the closure are preserved")
	_expect(result.get("reactivate_edge_keys", []) == ["edge/outside"], "preserved edge with inactive patch flags is scheduled for reactivation")
	_expect(result.get("stage_edge_keys", []) == ["edge/changed", "edge/new", "edge/rebuild"], "changed, new and non-reusable edges are staged")
	_expect(result.get("retire_edge_keys", []) == ["edge/changed", "edge/rebuild", "edge/removed"], "replaced and removed old edges are retired exactly once")
	_expect(int(result.get("preserve_edge_count", -1)) == 2 and int(result.get("stage_edge_count", -1)) == 3, "edge plan counts match the deterministic key sets")


func _test_edge_closure_fail_closed() -> void:
	var old_edges: Dictionary = {
		"edge/outside": {"reuse_signature": ["old"], "body_reusable": true, "patch_states_active": true}
	}
	var candidate_outside: Dictionary = {
		"edge/outside": {"reuse_signature": ["changed"]}
	}
	var changed_outside: Dictionary = PlannerScript.build_plan([], [], old_edges, candidate_outside, {}, {})
	_expect(not bool(changed_outside.get("ok", true)) and str(changed_outside.get("error", "")) == "candidate_edge_outside_affected_closure", "candidate edge outside the closure is rejected")
	var stale_outside_edges: Dictionary = {
		"edge/outside": {"reuse_signature": ["old"], "body_reusable": false, "patch_states_active": true}
	}
	var stale_outside: Dictionary = PlannerScript.build_plan([], [], stale_outside_edges, {}, {}, {})
	_expect(not bool(stale_outside.get("ok", true)) and str(stale_outside.get("error", "")) == "stale_edge_outside_affected_closure", "stale old edge outside the closure is rejected")
	var invalid_seed: Dictionary = PlannerScript.build_plan([" "], [], {}, {}, {}, {})
	_expect(not bool(invalid_seed.get("ok", true)) and str(invalid_seed.get("error", "")) == "invalid_affected_edge_key", "blank affected edge key fails closed")


func _test_corner_cap_preserve_stage_retire_partition() -> void:
	var old_caps: Dictionary = {
		"cap/outside": {"junction_key": "junction/0", "reuse_signature": ["same", 0], "body_reusable": true},
		"cap/same": {"junction_key": "junction/1", "reuse_signature": ["same", 1], "body_reusable": true},
		"cap/changed": {"junction_key": "junction/1", "reuse_signature": ["old", 2], "body_reusable": true},
		"cap/removed": {"junction_key": "junction/1", "reuse_signature": ["removed", 3], "body_reusable": true},
		"cap/rebuild": {"junction_key": "junction/1", "reuse_signature": ["rebuild", 4], "body_reusable": false}
	}
	var candidate_caps: Dictionary = {
		"cap/same": {"junction_key": "junction/1", "reuse_signature": ["same", 1]},
		"cap/changed": {"junction_key": "junction/1", "reuse_signature": ["new", 2]},
		"cap/rebuild": {"junction_key": "junction/1", "reuse_signature": ["rebuild", 4]},
		"cap/new": {"junction_key": "junction/1", "reuse_signature": ["new", 5]}
	}
	var result: Dictionary = PlannerScript.build_plan([], ["junction/1"], {}, {}, old_caps, candidate_caps)
	_expect(bool(result.get("ok", false)), "valid corner-cap resource inputs produce a plan")
	_expect(result.get("preserve_corner_cap_keys", []) == ["cap/outside", "cap/same"], "unaffected and signature-identical corner caps are preserved")
	_expect(result.get("stage_corner_cap_keys", []) == ["cap/changed", "cap/new", "cap/rebuild"], "changed, new and non-reusable corner caps are staged")
	_expect(result.get("retire_corner_cap_keys", []) == ["cap/changed", "cap/rebuild", "cap/removed"], "replaced and removed corner caps are retired exactly once")
	_expect(int(result.get("preserve_corner_cap_count", -1)) == 2 and int(result.get("stage_corner_cap_count", -1)) == 3, "corner-cap plan counts match the deterministic key sets")


func _test_corner_cap_closure_fail_closed() -> void:
	var old_caps: Dictionary = {
		"cap/move": {"junction_key": "junction/old", "reuse_signature": ["old"], "body_reusable": true}
	}
	var moved_candidate: Dictionary = {
		"cap/move": {"junction_key": "junction/new", "reuse_signature": ["new"]}
	}
	var moved: Dictionary = PlannerScript.build_plan([], ["junction/new"], {}, {}, old_caps, moved_candidate)
	_expect(not bool(moved.get("ok", true)) and str(moved.get("error", "")) == "old_corner_cap_junction_outside_affected_closure", "cap movement requires both old and new junctions in the closure")
	var candidate_outside: Dictionary = {
		"cap/new": {"junction_key": "junction/outside", "reuse_signature": ["new"]}
	}
	var outside: Dictionary = PlannerScript.build_plan([], ["junction/inside"], {}, {}, {}, candidate_outside)
	_expect(not bool(outside.get("ok", true)) and str(outside.get("error", "")) == "candidate_corner_cap_outside_affected_closure", "candidate cap outside the closure is rejected")
	var stale_caps: Dictionary = {
		"cap/stale": {"junction_key": "junction/outside", "reuse_signature": ["old"], "body_reusable": false}
	}
	var stale: Dictionary = PlannerScript.build_plan([], [], {}, {}, stale_caps, {})
	_expect(not bool(stale.get("ok", true)) and str(stale.get("error", "")) == "stale_corner_cap_outside_affected_closure", "stale old cap outside the closure is rejected")


func _test_real_manager_corner_cap_records() -> void:
	var holder := Node3D.new()
	holder.name = "RealManagerCornerCapPreserveFixture"
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
	_expect(_apply_patch_state(north_west, 0), "real cap fixture north-west state is valid")
	_expect(_apply_patch_state(north_east, 2), "real cap fixture north-east state is valid")
	_expect(_apply_patch_state(south_west, 2), "real cap fixture south-west state is valid")
	_expect(_apply_patch_state(south_east, 0), "real cap fixture south-east state is valid")

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
	_expect(bool(binding.get("ok", false)), "real cap fixture binder succeeds")
	if not bool(binding.get("ok", false)):
		await _release_holder(holder)
		return

	var manager: Node3D = ManagerScript.new()
	holder.add_child(manager)
	await process_frame
	var sync_result: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
	_expect(bool(sync_result.get("ok", false)), "real manager commits checkerboard resources")
	_expect(int(manager.call("get_corner_cap_count")) == 4, "real manager owns four checkerboard cap resources")
	if not bool(sync_result.get("ok", false)) or int(manager.call("get_corner_cap_count")) != 4:
		await _release_holder(holder)
		return

	var managed_value: Variant = manager.get("_managed_corner_caps")
	_expect(managed_value is Dictionary, "real manager exposes the expected managed cap dictionary")
	if not (managed_value is Dictionary):
		await _release_holder(holder)
		return
	var managed: Dictionary = managed_value
	var old_caps: Dictionary = {}
	var candidate_caps: Dictionary = {}
	var affected_junctions: Array[String] = []
	for key_value in managed.keys():
		var key: String = str(key_value)
		var record: Dictionary = managed[key]
		var body: StaticBody3D = record.get("body") as StaticBody3D
		var reusable: bool = bool(manager.call("_is_reusable_managed_body", body))
		var junction_key: String = str(record.get("junction_key", ""))
		var signature: Array = record.get("reuse_signature", []).duplicate(true)
		old_caps[key] = {"junction_key": junction_key, "reuse_signature": signature, "body_reusable": reusable}
		candidate_caps[key] = {"junction_key": junction_key, "reuse_signature": signature.duplicate(true)}
		if not affected_junctions.has(junction_key):
			affected_junctions.append(junction_key)
	affected_junctions.sort()

	var unchanged: Dictionary = PlannerScript.build_plan([], affected_junctions, {}, {}, old_caps, candidate_caps)
	_expect(bool(unchanged.get("ok", false)), "planner accepts actual manager-owned cap records")
	_expect(int(unchanged.get("preserve_corner_cap_count", -1)) == 4, "actual unchanged manager cap signatures preserve all four resources")

	var changed_candidate: Dictionary = candidate_caps.duplicate(true)
	var changed_key: String = str(changed_candidate.keys()[0])
	var changed_record: Dictionary = changed_candidate[changed_key]
	var changed_signature: Array = changed_record["reuse_signature"].duplicate(true)
	changed_signature[6] = float(changed_signature[6]) + 0.25
	changed_record["reuse_signature"] = changed_signature
	changed_candidate[changed_key] = changed_record
	var changed_plan: Dictionary = PlannerScript.build_plan([], affected_junctions, {}, {}, old_caps, changed_candidate)
	_expect(bool(changed_plan.get("ok", false)), "one changed real cap signature produces a valid local plan")
	_expect(int(changed_plan.get("preserve_corner_cap_count", -1)) == 3, "three unchanged real caps remain preserved")
	_expect(int(changed_plan.get("stage_corner_cap_count", -1)) == 1, "one changed real cap is staged")
	_expect(int(changed_plan.get("retire_corner_cap_count", -1)) == 1, "one replaced real cap is retired")
	await _release_holder(holder)


func _apply_patch_state(patch: Node3D, height_level: int) -> bool:
	return bool(patch.call("apply_world_object_state", {
		"height_level": height_level,
		"surface_type": "metal" if height_level >= 2 else "soil",
		"revision": 1
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
