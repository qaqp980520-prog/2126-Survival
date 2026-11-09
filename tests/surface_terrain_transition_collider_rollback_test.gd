extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const FaultPatchScript = preload("res://tests/fixtures/fault_injecting_surface_terrain_patch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://tests/fixtures/fault_injecting_surface_terrain_transition_collider_manager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_edge_staging_failure_preserves_committed_resources()
	await _test_corner_cap_staging_failure_preserves_committed_resources()
	await _test_second_patch_activation_failure_rolls_back_new_activation()
	if failures.is_empty():
		print("Surface terrain collider rollback fault-injection tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _test_edge_staging_failure_preserves_committed_resources() -> void:
	var fixture: Dictionary = await _make_two_seam_fixture()
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var manager: Variant = fixture["manager"]
	var edge_keys: Array[String] = fixture["edge_keys"]
	var patches: Array[Node3D] = fixture["patches"]
	var patches_by_stable_id: Dictionary = fixture["patches_by_stable_id"]
	var stable_ids: Dictionary = fixture["stable_ids"]
	var original_bodies: Dictionary = {}
	for edge_key in edge_keys:
		original_bodies[edge_key] = manager.call("get_transition_body", edge_key)
	_expect(edge_keys.size() == 2 and int(manager.call("get_transition_count")) == 2, "two-seam fixture commits two real managed edge bodies")
	for patch_index in [1, 3]:
		_expect(_apply_height(patches[patch_index], 1, 2), "changed seam endpoint accepts new height")
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "two-seam candidate descriptors rebuild successfully")
	if not bool(binding.get("ok", false)):
		await _release_holder(holder)
		return
	manager.fail_edge_stage_at = int(manager.edge_stage_calls) + 2
	var result: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
	_expect(not bool(result.get("ok", true)) and str(result.get("error", "")) == "edge_staging_failed", "second real edge staging failure aborts the manager transaction")
	_expect(int(manager.call("get_transition_count")) == 2, "edge staging failure retains the committed edge count")
	for edge_key in edge_keys:
		var current_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
		var original_body: StaticBody3D = original_bodies.get(edge_key) as StaticBody3D
		_expect(is_instance_valid(original_body) and current_body == original_body and current_body.collision_layer == 1, "%s retains its exact committed active body" % edge_key)
	await process_frame
	await process_frame
	var staged_ref: WeakRef = manager.last_staged_edge_ref
	_expect(staged_ref != null and staged_ref.get_ref() == null, "first staged edge body is released after the second edge fails")
	await _release_holder(holder)


func _test_corner_cap_staging_failure_preserves_committed_resources() -> void:
	var fixture: Dictionary = await _make_checkerboard_fixture()
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var manager: Variant = fixture["manager"]
	var patches: Array[Node3D] = fixture["patches"]
	var patches_by_stable_id: Dictionary = fixture["patches_by_stable_id"]
	var stable_ids: Dictionary = fixture["stable_ids"]
	var corner_refs: Array[Dictionary] = fixture["corner_refs"]
	var original_bodies: Dictionary = {}
	for entry in corner_refs:
		var key: String = str(entry["stable_id"]) + "|" + str(entry["corner"])
		original_bodies[key] = manager.call("get_corner_cap_body", str(entry["stable_id"]), str(entry["corner"]))
	_expect(int(manager.call("get_transition_count")) == 4 and int(manager.call("get_corner_cap_count")) == 4, "checkerboard fixture commits four edges and four real corner-cap bodies")
	for patch in patches:
		var state: Dictionary = patch.call("get_world_object_state")
		var next_height: int = int(state.get("height_level", 0)) + 1
		_expect(_apply_height(patch, next_height, 2), "%s accepts uniform height translation" % patch.name)
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "translated checkerboard descriptors rebuild successfully")
	if not bool(binding.get("ok", false)):
		await _release_holder(holder)
		return
	manager.fail_corner_stage_at = int(manager.corner_stage_calls) + 2
	var result: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
	_expect(not bool(result.get("ok", true)) and str(result.get("error", "")) == "corner_cap_staging_failed", "second real corner-cap staging failure aborts before edge publication")
	_expect(int(manager.call("get_transition_count")) == 4 and int(manager.call("get_corner_cap_count")) == 4, "corner-cap staging failure preserves committed edge and cap counts")
	for entry in corner_refs:
		var stable_id: String = str(entry["stable_id"])
		var corner: String = str(entry["corner"])
		var key: String = stable_id + "|" + corner
		var original_body: StaticBody3D = original_bodies.get(key) as StaticBody3D
		var current_body: StaticBody3D = manager.call("get_corner_cap_body", stable_id, corner) as StaticBody3D
		_expect(is_instance_valid(original_body) and current_body == original_body and current_body.collision_layer == 1, "%s preserves its exact active corner-cap body" % key)
	await process_frame
	await process_frame
	var staged_ref: WeakRef = manager.last_staged_corner_ref
	_expect(staged_ref != null and staged_ref.get_ref() == null, "first staged corner-cap body is released after the second cap fails")
	await _release_holder(holder)


func _test_second_patch_activation_failure_rolls_back_new_activation() -> void:
	var fixture: Dictionary = await _make_two_patch_fixture()
	if fixture.is_empty():
		return
	var holder: Node3D = fixture["holder"]
	var manager: Variant = fixture["manager"]
	var lower: Node3D = fixture["lower"]
	var higher: Node3D = fixture["higher"]
	var fault_patch: Variant = fixture["fault_patch"]
	var patches: Array[Node3D] = fixture["patches"]
	var patches_by_stable_id: Dictionary = fixture["patches_by_stable_id"]
	var stable_ids: Dictionary = fixture["stable_ids"]
	var edge_key: String = str(fixture["edge_key"])
	var original_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
	_expect(is_instance_valid(original_body) and original_body.collision_layer == 1, "activation fixture starts with one committed active edge body")
	_expect(_apply_height(higher, 1, 2), "activation fixture endpoint accepts changed height")
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	_expect(bool(binding.get("ok", false)), "activation candidate descriptor rebuilds successfully")
	if not bool(binding.get("ok", false)):
		await _release_holder(holder)
		return
	var descriptor: Dictionary = binding.get("descriptors", {}).get(edge_key, {})
	var first_id: String = str(descriptor.get("first_stable_id", ""))
	var second_id: String = str(descriptor.get("second_stable_id", ""))
	var first_side: String = str(descriptor.get("first_side", ""))
	var second_side: String = str(descriptor.get("second_side", ""))
	var first_patch: Node3D = patches_by_stable_id.get(first_id) as Node3D
	var second_patch: Node3D = patches_by_stable_id.get(second_id) as Node3D
	_expect(second_patch == higher and second_patch == fault_patch, "fault-injecting patch is the manager's second activation endpoint")
	if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
		await _release_holder(holder)
		return
	_expect(bool(first_patch.call("set_shared_transition_active", first_side, false)), "first endpoint enters the inactive pre-commit state")
	_expect(bool(second_patch.call("set_shared_transition_active", second_side, false)), "second endpoint enters the inactive pre-commit state")
	fault_patch.fail_activation_on_call = int(fault_patch.activation_call_count) + 1
	var result: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
	_expect(not bool(result.get("ok", true)) and str(result.get("error", "")) == "second_patch_activation_failed", "real manager aborts when the second endpoint rejects activation")
	_expect(int(manager.call("get_transition_count")) == 1 and manager.call("get_transition_body", edge_key) == original_body and original_body.collision_layer == 1, "activation failure retains the exact previously committed active collider")
	_expect(not bool(first_patch.call("is_shared_transition_active", first_side)), "first endpoint activation is rolled back after second endpoint rejection")
	_expect(not bool(second_patch.call("is_shared_transition_active", second_side)), "rejecting endpoint remains inactive after failed activation")
	await process_frame
	await process_frame
	var staged_ref: WeakRef = manager.last_staged_edge_ref
	_expect(staged_ref != null and staged_ref.get_ref() == null, "new edge body is released after activation rollback")
	await _release_holder(holder)


func _make_two_patch_fixture() -> Dictionary:
	var holder := Node3D.new()
	holder.name = "ColliderActivationRollbackFixture"
	root.add_child(holder)
	var lower: Node3D = PatchScript.new()
	lower.name = "Lower"
	var higher: Node3D = FaultPatchScript.new()
	higher.name = "Higher"
	higher.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	holder.add_child(lower)
	holder.add_child(higher)
	await process_frame
	_expect(_apply_height(lower, 0, 1), "activation lower patch accepts baseline")
	_expect(_apply_height(higher, 2, 1), "activation higher patch accepts baseline")
	var patches: Array[Node3D] = [lower, higher]
	var stable_ids: Dictionary = {
		lower.get_instance_id(): "a/activation/lower",
		higher.get_instance_id(): "z/activation/higher"
	}
	var patches_by_stable_id: Dictionary = {
		"a/activation/lower": lower,
		"z/activation/higher": higher
	}
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	if not bool(binding.get("ok", false)):
		_expect(false, "activation fixture binder succeeds")
		await _release_holder(holder)
		return {}
	var descriptors: Dictionary = binding.get("descriptors", {})
	var edge_key: String = _first_key(descriptors)
	var manager: Variant = ManagerScript.new()
	holder.add_child(manager)
	await process_frame
	var initial: Dictionary = manager.call("sync_transitions", descriptors, patches_by_stable_id)
	_expect(bool(initial.get("ok", false)) and int(initial.get("active_count", -1)) == 1, "activation fixture commits its initial real transition")
	if not bool(initial.get("ok", false)):
		await _release_holder(holder)
		return {}
	return {
		"holder": holder,
		"manager": manager,
		"lower": lower,
		"higher": higher,
		"fault_patch": higher,
		"patches": patches,
		"stable_ids": stable_ids,
		"patches_by_stable_id": patches_by_stable_id,
		"edge_key": edge_key
	}


func _make_two_seam_fixture() -> Dictionary:
	var holder := Node3D.new()
	holder.name = "ColliderEdgeStagingRollbackFixture"
	root.add_child(holder)
	var lower_a: Node3D = PatchScript.new()
	lower_a.name = "LowerA"
	var higher_a: Node3D = PatchScript.new()
	higher_a.name = "HigherA"
	higher_a.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
	var lower_b: Node3D = PatchScript.new()
	lower_b.name = "LowerB"
	lower_b.position = Vector3(10.0, 0.0, 0.0)
	var higher_b: Node3D = PatchScript.new()
	higher_b.name = "HigherB"
	higher_b.position = Vector3(10.0 + PatchScript.PATCH_SIZE, 0.0, 0.0)
	var patches: Array[Node3D] = [lower_a, higher_a, lower_b, higher_b]
	for patch in patches:
		holder.add_child(patch)
	await process_frame
	_expect(_apply_height(lower_a, 0, 1) and _apply_height(lower_b, 0, 1), "two-seam lower patches accept baseline")
	_expect(_apply_height(higher_a, 2, 1) and _apply_height(higher_b, 2, 1), "two-seam upper patches accept baseline")
	var stable_ids: Dictionary = {
		lower_a.get_instance_id(): "a/staging/lower",
		higher_a.get_instance_id(): "b/staging/higher",
		lower_b.get_instance_id(): "c/staging/lower",
		higher_b.get_instance_id(): "d/staging/higher"
	}
	var patches_by_stable_id: Dictionary = {
		"a/staging/lower": lower_a,
		"b/staging/higher": higher_a,
		"c/staging/lower": lower_b,
		"d/staging/higher": higher_b
	}
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	if not bool(binding.get("ok", false)):
		_expect(false, "two-seam fixture binder succeeds")
		await _release_holder(holder)
		return {}
	var descriptors: Dictionary = binding.get("descriptors", {})
	var edge_keys: Array[String] = []
	for key in descriptors.keys():
		edge_keys.append(str(key))
	edge_keys.sort()
	var manager: Variant = ManagerScript.new()
	holder.add_child(manager)
	await process_frame
	var initial: Dictionary = manager.call("sync_transitions", descriptors, patches_by_stable_id)
	_expect(bool(initial.get("ok", false)) and int(initial.get("active_count", -1)) == 2, "two-seam fixture commits both real transition bodies")
	if not bool(initial.get("ok", false)):
		await _release_holder(holder)
		return {}
	return {
		"holder": holder,
		"manager": manager,
		"patches": patches,
		"stable_ids": stable_ids,
		"patches_by_stable_id": patches_by_stable_id,
		"edge_keys": edge_keys
	}


func _make_checkerboard_fixture() -> Dictionary:
	var holder := Node3D.new()
	holder.name = "ColliderCornerCapRollbackFixture"
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
	_expect(_apply_height(north_west, 0, 1), "checkerboard north-west patch accepts low baseline")
	_expect(_apply_height(north_east, 2, 1), "checkerboard north-east patch accepts high baseline")
	_expect(_apply_height(south_west, 2, 1), "checkerboard south-west patch accepts high baseline")
	_expect(_apply_height(south_east, 0, 1), "checkerboard south-east patch accepts low baseline")
	var stable_ids: Dictionary = {
		north_west.get_instance_id(): "cap/north_west",
		north_east.get_instance_id(): "cap/north_east",
		south_west.get_instance_id(): "cap/south_west",
		south_east.get_instance_id(): "cap/south_east"
	}
	var patches_by_stable_id: Dictionary = {
		"cap/north_west": north_west,
		"cap/north_east": north_east,
		"cap/south_west": south_west,
		"cap/south_east": south_east
	}
	var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
	if not bool(binding.get("ok", false)):
		_expect(false, "checkerboard fixture binder succeeds")
		await _release_holder(holder)
		return {}
	var descriptors: Dictionary = binding.get("descriptors", {})
	var manager: Variant = ManagerScript.new()
	holder.add_child(manager)
	await process_frame
	var initial: Dictionary = manager.call("sync_transitions", descriptors, patches_by_stable_id)
	_expect(bool(initial.get("ok", false)) and int(initial.get("corner_cap_count", -1)) == 4, "checkerboard fixture commits four real corner caps")
	if not bool(initial.get("ok", false)):
		await _release_holder(holder)
		return {}
	var corner_refs: Array[Dictionary] = [
		{"stable_id": "cap/north_west", "corner": "south_east"},
		{"stable_id": "cap/north_east", "corner": "south_west"},
		{"stable_id": "cap/south_west", "corner": "north_east"},
		{"stable_id": "cap/south_east", "corner": "north_west"}
	]
	return {
		"holder": holder,
		"manager": manager,
		"patches": patches,
		"stable_ids": stable_ids,
		"patches_by_stable_id": patches_by_stable_id,
		"corner_refs": corner_refs
	}


func _apply_height(patch: Node3D, height_level: int, revision: int) -> bool:
	return bool(patch.call("apply_world_object_state", {
		"height_level": height_level,
		"surface_type": "metal" if height_level >= 2 else "soil",
		"revision": revision
	}))


func _first_key(source: Dictionary) -> String:
	for key in source.keys():
		return str(key)
	return ""


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
