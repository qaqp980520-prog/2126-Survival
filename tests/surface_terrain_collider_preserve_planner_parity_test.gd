extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const ClosurePlannerScript = preload("res://systems/SurfaceTerrainAffectedComponentPlanner.gd")
const PreservePlannerScript = preload("res://systems/SurfaceTerrainColliderPreservePlanner.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_edge_addition_parity()
	await _test_edge_removal_parity()
	await _test_edge_replacement_parity()
	await _test_edge_reactivation_parity()
	await _test_corner_cap_addition_parity()
	await _test_corner_cap_removal_parity()
	await _test_corner_cap_replacement_parity()
	await _test_connected_two_junction_component_parity()
	if failures.is_empty():
		print("Surface terrain preserve planner full-rebuild parity tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _test_edge_addition_parity() -> void:
	var holder := _new_holder("EdgeAdditionParity")
	var low: Node3D = _new_patch(holder, "Low", Vector3.ZERO)
	var high: Node3D = _new_patch(holder, "High", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
	await process_frame
	_expect(_apply_height(low, 0), "edge-addition low patch state is valid")
	_expect(_apply_height(high, 2), "edge-addition high patch state is valid")
	var old_patches: Array[Node3D] = [low]
	var candidate_patches: Array[Node3D] = [low, high]
	await _run_parity_case(
		"edge addition",
		holder,
		old_patches,
		candidate_patches,
		{"Low": "edge/low", "High": "edge/high"},
		{},
		false,
		{"stage_edge_count": 1}
	)
	await _release_holder(holder)


func _test_edge_removal_parity() -> void:
	var holder := _new_holder("EdgeRemovalParity")
	var low: Node3D = _new_patch(holder, "Low", Vector3.ZERO)
	var high: Node3D = _new_patch(holder, "High", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
	await process_frame
	_expect(_apply_height(low, 0), "edge-removal low patch state is valid")
	_expect(_apply_height(high, 2), "edge-removal high patch state is valid")
	var old_patches: Array[Node3D] = [low, high]
	var candidate_patches: Array[Node3D] = [low]
	await _run_parity_case(
		"edge removal",
		holder,
		old_patches,
		candidate_patches,
		{"Low": "edge/low", "High": "edge/high"},
		{},
		false,
		{"retire_edge_count": 1}
	)
	await _release_holder(holder)


func _test_edge_replacement_parity() -> void:
	var holder := _new_holder("EdgeReplacementParity")
	var low: Node3D = _new_patch(holder, "Low", Vector3.ZERO)
	var high: Node3D = _new_patch(holder, "High", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
	await process_frame
	_expect(_apply_height(low, 0), "edge-replacement low patch state is valid")
	_expect(_apply_height(high, 2), "edge-replacement initial high patch state is valid")
	var patches: Array[Node3D] = [low, high]
	await _run_parity_case(
		"edge replacement",
		holder,
		patches,
		patches,
		{"Low": "edge/low", "High": "edge/high"},
		{"High": 1},
		false,
		{"stage_edge_count": 1, "retire_edge_count": 1}
	)
	await _release_holder(holder)


func _test_edge_reactivation_parity() -> void:
	var holder := _new_holder("EdgeReactivationParity")
	var low: Node3D = _new_patch(holder, "Low", Vector3.ZERO)
	var high: Node3D = _new_patch(holder, "High", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
	await process_frame
	_expect(_apply_height(low, 0), "edge-reactivation low patch state is valid")
	_expect(_apply_height(high, 2), "edge-reactivation high patch state is valid")
	var patches: Array[Node3D] = [low, high]
	await _run_parity_case(
		"edge reactivation",
		holder,
		patches,
		patches,
		{"Low": "edge/low", "High": "edge/high"},
		{},
		true,
		{"preserve_edge_count": 1, "reactivate_edge_count": 1, "stage_edge_count": 0, "retire_edge_count": 0}
	)
	await _release_holder(holder)


func _test_corner_cap_addition_parity() -> void:
	var holder := _new_holder("CornerCapAdditionParity")
	var patches: Dictionary = await _make_checkerboard(holder)
	var old_patches: Array[Node3D] = [patches["NW"], patches["NE"], patches["SW"]]
	var candidate_patches: Array[Node3D] = [patches["NW"], patches["NE"], patches["SW"], patches["SE"]]
	await _run_parity_case(
		"corner-cap addition",
		holder,
		old_patches,
		candidate_patches,
		{"NW": "cap/nw", "NE": "cap/ne", "SW": "cap/sw", "SE": "cap/se"},
		{},
		false,
		{"stage_corner_cap_count": 4}
	)
	await _release_holder(holder)


func _test_corner_cap_removal_parity() -> void:
	var holder := _new_holder("CornerCapRemovalParity")
	var patches: Dictionary = await _make_checkerboard(holder)
	var old_patches: Array[Node3D] = [patches["NW"], patches["NE"], patches["SW"], patches["SE"]]
	var candidate_patches: Array[Node3D] = [patches["NW"], patches["NE"], patches["SW"]]
	await _run_parity_case(
		"corner-cap removal",
		holder,
		old_patches,
		candidate_patches,
		{"NW": "cap/nw", "NE": "cap/ne", "SW": "cap/sw", "SE": "cap/se"},
		{},
		false,
		{"retire_corner_cap_count": 4}
	)
	await _release_holder(holder)


func _test_corner_cap_replacement_parity() -> void:
	var holder := _new_holder("CornerCapReplacementParity")
	var patches: Dictionary = await _make_checkerboard(holder)
	var all_patches: Array[Node3D] = [patches["NW"], patches["NE"], patches["SW"], patches["SE"]]
	await _run_parity_case(
		"corner-cap replacement",
		holder,
		all_patches,
		all_patches,
		{"NW": "cap/nw", "NE": "cap/ne", "SW": "cap/sw", "SE": "cap/se"},
		{"NW": 2, "NE": 0, "SW": 0, "SE": 2},
		false,
		{"stage_corner_cap_count": 4, "retire_corner_cap_count": 4}
	)
	await _release_holder(holder)


func _test_connected_two_junction_component_parity() -> void:
	var holder := _new_holder("ConnectedTwoJunctionComponentParity")
	var north_west: Node3D = _new_patch(holder, "NW", Vector3.ZERO)
	var north_east: Node3D = _new_patch(holder, "NE", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
	var north_outer: Node3D = _new_patch(holder, "N2", Vector3(PatchScript.PATCH_SIZE * 2.0, 0.0, 0.0))
	var south_west: Node3D = _new_patch(holder, "SW", Vector3(0.0, 0.0, PatchScript.PATCH_SIZE))
	var south_east: Node3D = _new_patch(holder, "SE", Vector3(PatchScript.PATCH_SIZE, 0.0, PatchScript.PATCH_SIZE))
	var south_outer: Node3D = _new_patch(holder, "S2", Vector3(PatchScript.PATCH_SIZE * 2.0, 0.0, PatchScript.PATCH_SIZE))
	await process_frame
	_expect(_apply_height(north_west, 0), "connected component north-west state is valid")
	_expect(_apply_height(north_east, 2), "connected component north-east state is valid")
	_expect(_apply_height(north_outer, 0), "connected component north-outer state is valid")
	_expect(_apply_height(south_west, 2), "connected component south-west state is valid")
	_expect(_apply_height(south_east, 0), "connected component south-east state is valid")
	_expect(_apply_height(south_outer, 2), "connected component south-outer state is valid")
	var all_patches: Array[Node3D] = [
		north_west,
		north_east,
		north_outer,
		south_west,
		south_east,
		south_outer
	]
	var stable_ids_by_name: Dictionary = {
		"NW": "cap/nw",
		"NE": "cap/ne",
		"N2": "cap/n2",
		"SW": "cap/sw",
		"SE": "cap/se",
		"S2": "cap/s2"
	}
	var left_junction_key: String = ClosurePlannerScript.junction_key_for_corner(
		north_east.global_position,
		"south_west",
		PatchScript.PATCH_SIZE
	)
	var right_junction_key: String = ClosurePlannerScript.junction_key_for_corner(
		north_outer.global_position,
		"south_west",
		PatchScript.PATCH_SIZE
	)
	var seed_patch_names: Array[String] = ["N2"]
	var required_junction_keys: Array[String] = [left_junction_key, right_junction_key]
	_expect(
		not left_junction_key.is_empty()
		and not right_junction_key.is_empty()
		and left_junction_key != right_junction_key,
		"connected component exposes two distinct adjacent junction keys"
	)
	await _run_parity_case(
		"connected two-junction fallback propagation",
		holder,
		all_patches,
		all_patches,
		stable_ids_by_name,
		{"N2": 1},
		false,
		{"retire_corner_cap_count": 8},
		seed_patch_names,
		required_junction_keys
	)
	await _release_holder(holder)


func _run_parity_case(
	label: String,
	holder: Node3D,
	old_patches: Array[Node3D],
	candidate_patches: Array[Node3D],
	stable_ids_by_name: Dictionary,
	candidate_height_changes: Dictionary,
	force_reactivation: bool,
	expected_plan_counts: Dictionary,
	seed_patch_names: Array[String] = [],
	required_junction_keys: Array[String] = []
) -> void:
	var old_maps: Dictionary = _build_patch_maps(old_patches, stable_ids_by_name)
	var old_binding: Dictionary = BinderScript.bind_patches(old_patches, old_maps["by_instance"])
	_expect(bool(old_binding.get("ok", false)), label + ": old full-rebuild binder succeeds")
	if not bool(old_binding.get("ok", false)):
		return
	var old_manager: Node3D = ManagerScript.new()
	old_manager.name = "OldFullRebuildManager"
	holder.add_child(old_manager)
	await process_frame
	var old_sync: Dictionary = old_manager.call("sync_transitions", old_binding.get("descriptors", {}), old_maps["by_stable_id"])
	_expect(bool(old_sync.get("ok", false)), label + ": old manager commits its initial resource map")
	if not bool(old_sync.get("ok", false)):
		return
	if force_reactivation:
		_set_manager_edges_active(old_manager, false)

	var old_edges: Dictionary = _capture_edge_snapshot(old_manager, true)
	var old_caps: Dictionary = _capture_cap_snapshot(old_manager, true)
	var old_reports: Array = _manager_reports(old_manager)

	for patch in candidate_patches:
		if candidate_height_changes.has(patch.name):
			_expect(_apply_height(patch, int(candidate_height_changes[patch.name])), label + ": candidate state applies to " + patch.name)

	var candidate_maps: Dictionary = _build_patch_maps(candidate_patches, stable_ids_by_name)
	var candidate_binding: Dictionary = BinderScript.bind_patches(candidate_patches, candidate_maps["by_instance"])
	_expect(bool(candidate_binding.get("ok", false)), label + ": candidate full-rebuild binder succeeds")
	if not bool(candidate_binding.get("ok", false)):
		return
	var candidate_manager: Node3D = ManagerScript.new()
	candidate_manager.name = "CandidateFullRebuildManager"
	holder.add_child(candidate_manager)
	await process_frame
	var candidate_sync: Dictionary = candidate_manager.call(
		"sync_transitions",
		candidate_binding.get("descriptors", {}),
		candidate_maps["by_stable_id"]
	)
	_expect(bool(candidate_sync.get("ok", false)), label + ": candidate manager builds the full-rebuild oracle")
	if not bool(candidate_sync.get("ok", false)):
		return
	if force_reactivation:
		_set_manager_edges_active(old_manager, false)

	var candidate_edges: Dictionary = _capture_edge_snapshot(candidate_manager, false)
	var candidate_caps: Dictionary = _capture_cap_snapshot(candidate_manager, false)
	var candidate_reports: Array = _manager_reports(candidate_manager)
	var seed_edge_keys: Array[String] = _collect_seed_edge_keys(old_edges, candidate_edges, old_reports, candidate_reports)
	if not seed_patch_names.is_empty():
		var managers: Array[Node3D] = [old_manager, candidate_manager]
		seed_edge_keys = _collect_seed_edge_keys_for_patch_names(managers, stable_ids_by_name, seed_patch_names)
		_expect(seed_edge_keys.size() == 2, label + ": changed patch contributes exactly two transition-edge seeds")
	var closure: Dictionary = ClosurePlannerScript.build_closure(
		seed_edge_keys,
		old_reports,
		old_maps["by_stable_id"],
		candidate_reports,
		candidate_maps["by_stable_id"],
		PatchScript.PATCH_SIZE
	)
	_expect(bool(closure.get("ok", false)), label + ": old/candidate topology closure succeeds")
	if not bool(closure.get("ok", false)):
		return
	var closure_junction_keys: Array = closure.get("junction_keys", [])
	for required_junction_key in required_junction_keys:
		_expect(
			closure_junction_keys.has(required_junction_key),
			label + ": affected closure reaches connected junction " + required_junction_key
		)

	var edge_scope: Dictionary = _to_set(closure.get("edge_keys", []))
	var junction_scope: Dictionary = _to_set(closure.get("junction_keys", []))
	var candidate_edge_records: Dictionary = _filter_candidate_edges(candidate_edges["records"], edge_scope)
	var candidate_cap_records: Dictionary = _filter_candidate_caps(candidate_caps["records"], junction_scope)
	var plan: Dictionary = PreservePlannerScript.build_plan(
		closure.get("edge_keys", []),
		closure.get("junction_keys", []),
		old_edges["records"],
		candidate_edge_records,
		old_caps["records"],
		candidate_cap_records
	)
	_expect(bool(plan.get("ok", false)), label + ": preserve planner accepts the production-manager snapshots")
	if not bool(plan.get("ok", false)):
		return

	var final_sync: Dictionary = old_manager.call(
		"sync_transitions",
		candidate_binding.get("descriptors", {}),
		candidate_maps["by_stable_id"]
	)
	_expect(bool(final_sync.get("ok", false)), label + ": existing full-rebuild manager commits candidate topology")
	if not bool(final_sync.get("ok", false)):
		return

	var final_edges: Dictionary = _capture_edge_snapshot(old_manager, false)
	var final_caps: Dictionary = _capture_cap_snapshot(old_manager, false)
	var actual_edges: Dictionary = _derive_actual_edge_sets(old_edges, final_edges)
	var actual_caps: Dictionary = _derive_actual_cap_sets(old_caps, final_caps)
	_expect(plan.get("preserve_edge_keys", []) == actual_edges["preserve"], label + ": planner edge preserve set matches full-rebuild object identity")
	_expect(plan.get("reactivate_edge_keys", []) == actual_edges["reactivate"], label + ": planner edge reactivation set matches full-rebuild patch state")
	_expect(plan.get("stage_edge_keys", []) == actual_edges["stage"], label + ": planner edge stage set matches full-rebuild object identity")
	_expect(plan.get("retire_edge_keys", []) == actual_edges["retire"], label + ": planner edge retire set matches full-rebuild object identity")
	_expect(plan.get("preserve_corner_cap_keys", []) == actual_caps["preserve"], label + ": planner cap preserve set matches full-rebuild object identity")
	_expect(plan.get("stage_corner_cap_keys", []) == actual_caps["stage"], label + ": planner cap stage set matches full-rebuild object identity")
	_expect(plan.get("retire_corner_cap_keys", []) == actual_caps["retire"], label + ": planner cap retire set matches full-rebuild object identity")
	_assert_final_signature_parity(label, final_edges, candidate_edges, "edge")
	_assert_final_signature_parity(label, final_caps, candidate_caps, "corner cap")

	for count_key in expected_plan_counts.keys():
		_expect(int(plan.get(str(count_key), -1)) == int(expected_plan_counts[count_key]), label + ": expected " + str(count_key))


func _new_holder(holder_name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = holder_name
	root.add_child(holder)
	return holder


func _new_patch(holder: Node3D, patch_name: String, position: Vector3) -> Node3D:
	var patch: Node3D = PatchScript.new()
	patch.name = patch_name
	patch.position = position
	holder.add_child(patch)
	return patch


func _make_checkerboard(holder: Node3D) -> Dictionary:
	var north_west: Node3D = _new_patch(holder, "NW", Vector3.ZERO)
	var north_east: Node3D = _new_patch(holder, "NE", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
	var south_west: Node3D = _new_patch(holder, "SW", Vector3(0.0, 0.0, PatchScript.PATCH_SIZE))
	var south_east: Node3D = _new_patch(holder, "SE", Vector3(PatchScript.PATCH_SIZE, 0.0, PatchScript.PATCH_SIZE))
	await process_frame
	_expect(_apply_height(north_west, 0), "checkerboard north-west state is valid")
	_expect(_apply_height(north_east, 2), "checkerboard north-east state is valid")
	_expect(_apply_height(south_west, 2), "checkerboard south-west state is valid")
	_expect(_apply_height(south_east, 0), "checkerboard south-east state is valid")
	return {"NW": north_west, "NE": north_east, "SW": south_west, "SE": south_east}


func _apply_height(patch: Node3D, height_level: int) -> bool:
	var current: Dictionary = patch.call("get_world_object_state")
	var surface_types: Array[String] = ["soil", "rock", "metal"]
	if height_level < 0 or height_level >= surface_types.size():
		return false
	return bool(patch.call("apply_world_object_state", {
		"height_level": height_level,
		"surface_type": surface_types[height_level],
		"revision": int(current.get("revision", 0)) + 1
	}))


func _build_patch_maps(patches: Array[Node3D], stable_ids_by_name: Dictionary) -> Dictionary:
	var by_instance: Dictionary = {}
	var by_stable_id: Dictionary = {}
	for patch in patches:
		var stable_id: String = str(stable_ids_by_name.get(patch.name, ""))
		if stable_id.is_empty():
			return {"ok": false, "by_instance": {}, "by_stable_id": {}}
		by_instance[patch.get_instance_id()] = stable_id
		by_stable_id[stable_id] = patch
	return {"ok": true, "by_instance": by_instance, "by_stable_id": by_stable_id}


func _capture_edge_snapshot(manager: Node3D, include_old_state: bool) -> Dictionary:
	var raw_value: Variant = manager.get("_managed_edges")
	if not (raw_value is Dictionary):
		_expect(false, "manager exposes its committed edge resource map")
		return {"records": {}, "bodies": {}, "patch_active": {}}
	var records: Dictionary = {}
	var bodies: Dictionary = {}
	var patch_active: Dictionary = {}
	var raw: Dictionary = raw_value
	for key_value in raw.keys():
		var key: String = str(key_value)
		var record: Dictionary = raw[key_value]
		var body: StaticBody3D = record.get("body") as StaticBody3D
		var signature: Array = record.get("reuse_signature", []).duplicate(true)
		bodies[key] = body
		if include_old_state:
			records[key] = {
				"reuse_signature": signature,
				"body_reusable": bool(manager.call("_is_reusable_managed_body", body)),
				"patch_states_active": bool(manager.call("_edge_patch_states_are_active", record))
			}
			patch_active[key] = bool(manager.call("_edge_patch_states_are_active", record))
		else:
			records[key] = {"reuse_signature": signature}
	return {"records": records, "bodies": bodies, "patch_active": patch_active}


func _capture_cap_snapshot(manager: Node3D, include_old_state: bool) -> Dictionary:
	var raw_value: Variant = manager.get("_managed_corner_caps")
	if not (raw_value is Dictionary):
		_expect(false, "manager exposes its committed corner-cap resource map")
		return {"records": {}, "bodies": {}}
	var records: Dictionary = {}
	var bodies: Dictionary = {}
	var raw: Dictionary = raw_value
	for key_value in raw.keys():
		var key: String = str(key_value)
		var record: Dictionary = raw[key_value]
		var body: StaticBody3D = record.get("body") as StaticBody3D
		var signature: Array = record.get("reuse_signature", []).duplicate(true)
		bodies[key] = body
		if include_old_state:
			records[key] = {
				"junction_key": str(record.get("junction_key", "")),
				"reuse_signature": signature,
				"body_reusable": bool(manager.call("_is_reusable_managed_body", body))
			}
		else:
			records[key] = {
				"junction_key": str(record.get("junction_key", "")),
				"reuse_signature": signature
			}
	return {"records": records, "bodies": bodies}


func _manager_reports(manager: Node3D) -> Array:
	var reports_value: Variant = manager.call("get_blocked_corner_reports")
	return reports_value if reports_value is Array else []


func _collect_seed_edge_keys(
	old_edges: Dictionary,
	candidate_edges: Dictionary,
	old_reports: Array,
	candidate_reports: Array
) -> Array[String]:
	var unique: Dictionary = {}
	for key_value in old_edges["bodies"].keys():
		unique[str(key_value)] = true
	for key_value in candidate_edges["bodies"].keys():
		unique[str(key_value)] = true
	for reports in [old_reports, candidate_reports]:
		for report_value in reports:
			if not (report_value is Dictionary):
				continue
			var edge_keys_value: Variant = report_value.get("edge_keys", [])
			if not (edge_keys_value is Array):
				continue
			for edge_key_value in edge_keys_value:
				if edge_key_value is String and not str(edge_key_value).is_empty():
					unique[str(edge_key_value)] = true
	var result: Array[String] = []
	for key_value in unique.keys():
		result.append(str(key_value))
	result.sort()
	return result


func _collect_seed_edge_keys_for_patch_names(
	managers: Array[Node3D],
	stable_ids_by_name: Dictionary,
	patch_names: Array[String]
) -> Array[String]:
	var changed_stable_ids: Dictionary = {}
	for patch_name in patch_names:
		var stable_id: String = str(stable_ids_by_name.get(patch_name, ""))
		if stable_id.is_empty():
			_expect(false, "changed patch has a registered Stable ID: " + patch_name)
			continue
		changed_stable_ids[stable_id] = true
	var unique: Dictionary = {}
	for manager in managers:
		var raw_value: Variant = manager.get("_managed_edges")
		if not (raw_value is Dictionary):
			_expect(false, "manager exposes committed edge records for changed-patch seed discovery")
			continue
		var raw_edges: Dictionary = raw_value
		for key_value in raw_edges.keys():
			var record_value: Variant = raw_edges[key_value]
			if not (record_value is Dictionary):
				_expect(false, "managed edge record is a Dictionary during seed discovery")
				continue
			var record: Dictionary = record_value
			if (
				changed_stable_ids.has(str(record.get("first_id", "")))
				or changed_stable_ids.has(str(record.get("second_id", "")))
			):
				unique[str(key_value)] = true
	var result: Array[String] = []
	for key_value in unique.keys():
		result.append(str(key_value))
	result.sort()
	return result


func _to_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[str(value)] = true
	return result


func _filter_candidate_edges(records: Dictionary, edge_scope: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in records.keys():
		var key: String = str(key_value)
		if edge_scope.has(key):
			result[key] = records[key_value]
	return result


func _filter_candidate_caps(records: Dictionary, junction_scope: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in records.keys():
		var record: Dictionary = records[key_value]
		if junction_scope.has(str(record.get("junction_key", ""))):
			result[str(key_value)] = record
	return result


func _derive_actual_edge_sets(old_snapshot: Dictionary, final_snapshot: Dictionary) -> Dictionary:
	var preserve: Array[String] = []
	var reactivate: Array[String] = []
	var stage: Array[String] = []
	var retire: Array[String] = []
	for key_value in old_snapshot["bodies"].keys():
		var key: String = str(key_value)
		var old_body: StaticBody3D = old_snapshot["bodies"][key]
		if final_snapshot["bodies"].has(key) and final_snapshot["bodies"][key] == old_body:
			preserve.append(key)
			if not bool(old_snapshot["patch_active"].get(key, true)):
				reactivate.append(key)
		else:
			retire.append(key)
	for key_value in final_snapshot["bodies"].keys():
		var key: String = str(key_value)
		if not old_snapshot["bodies"].has(key) or final_snapshot["bodies"][key] != old_snapshot["bodies"][key]:
			stage.append(key)
	preserve.sort()
	reactivate.sort()
	stage.sort()
	retire.sort()
	return {"preserve": preserve, "reactivate": reactivate, "stage": stage, "retire": retire}


func _derive_actual_cap_sets(old_snapshot: Dictionary, final_snapshot: Dictionary) -> Dictionary:
	var preserve: Array[String] = []
	var stage: Array[String] = []
	var retire: Array[String] = []
	for key_value in old_snapshot["bodies"].keys():
		var key: String = str(key_value)
		var old_body: StaticBody3D = old_snapshot["bodies"][key]
		if final_snapshot["bodies"].has(key) and final_snapshot["bodies"][key] == old_body:
			preserve.append(key)
		else:
			retire.append(key)
	for key_value in final_snapshot["bodies"].keys():
		var key: String = str(key_value)
		if not old_snapshot["bodies"].has(key) or final_snapshot["bodies"][key] != old_snapshot["bodies"][key]:
			stage.append(key)
	preserve.sort()
	stage.sort()
	retire.sort()
	return {"preserve": preserve, "stage": stage, "retire": retire}


func _assert_final_signature_parity(label: String, final_snapshot: Dictionary, candidate_snapshot: Dictionary, resource_name: String) -> void:
	var final_keys: Array[String] = _sorted_keys(final_snapshot["records"])
	var candidate_keys: Array[String] = _sorted_keys(candidate_snapshot["records"])
	_expect(final_keys == candidate_keys, label + ": full-rebuild " + resource_name + " resource keys match the candidate oracle")
	for key in final_keys:
		if not candidate_snapshot["records"].has(key):
			continue
		var final_record: Dictionary = final_snapshot["records"][key]
		var candidate_record: Dictionary = candidate_snapshot["records"][key]
		_expect(
			_signatures_match(final_record.get("reuse_signature", []), candidate_record.get("reuse_signature", [])),
			label + ": full-rebuild " + resource_name + " signature matches the candidate oracle for " + key
		)


func _signatures_match(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if first[index] != second[index]:
			return false
	return true


func _sorted_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in source.keys():
		result.append(str(key_value))
	result.sort()
	return result


func _set_manager_edges_active(manager: Node3D, active: bool) -> void:
	var raw_value: Variant = manager.get("_managed_edges")
	if not (raw_value is Dictionary):
		return
	var raw: Dictionary = raw_value
	for record_value in raw.values():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var first_patch: Node3D = record.get("first_patch") as Node3D
		var second_patch: Node3D = record.get("second_patch") as Node3D
		if is_instance_valid(first_patch):
			first_patch.call("set_shared_transition_active", str(record.get("first_side", "")), active)
		if is_instance_valid(second_patch):
			second_patch.call("set_shared_transition_active", str(record.get("second_side", "")), active)


func _release_holder(holder: Node3D) -> void:
	if not is_instance_valid(holder):
		return
	for child in holder.get_children():
		if child.has_method("clear_all"):
			child.call("clear_all")
	holder.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
