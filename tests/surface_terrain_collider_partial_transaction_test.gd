extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const DescriptorScript = preload("res://systems/SurfaceTerrainTransitionDescriptor.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await _test_partial_replacement_preserves_unaffected_edge()
    await _test_partial_removal_preserves_unaffected_edge()
    await _test_underseeded_change_fails_closed()
    if failures.is_empty():
        print("Surface terrain partial collider transaction tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error("FAIL: " + failure)
    quit(1)


func _test_partial_replacement_preserves_unaffected_edge() -> void:
    var fixture: Dictionary = await _make_two_pair_fixture()
    if fixture.is_empty():
        return
    var manager: Node3D = fixture["manager"]
    var holder: Node3D = fixture["holder"]
    var edge_a: String = str(fixture["edge_a"])
    var edge_b: String = str(fixture["edge_b"])
    var old_a: StaticBody3D = manager.call("get_transition_body", edge_a) as StaticBody3D
    var old_b: StaticBody3D = manager.call("get_transition_body", edge_b) as StaticBody3D

    _expect(_apply_height(fixture["b1"], 1), "changed patch accepts a new height")
    var candidate_descriptors: Dictionary = _build_descriptors(fixture["pairs"])
    var prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        fixture["patches_by_stable_id"],
        [edge_a]
    )
    _expect(bool(prepared.get("ok", false)), "partial replacement prepare succeeds")
    if not bool(prepared.get("ok", false)):
        await _release_holder(holder)
        return
    _expect(int(prepared.get("pending_staged_edge_count", -1)) == 1, "partial replacement stages only the changed edge")
    _expect(int(prepared.get("pending_reused_edge_count", -1)) == 1, "partial replacement preserves the unrelated edge")
    _expect(manager.call("get_transition_body", edge_a) == old_a, "prepare leaves the committed changed edge untouched")
    _expect(manager.call("get_transition_body", edge_b) == old_b, "prepare leaves the unrelated committed edge untouched")

    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var committed: Dictionary = manager.call("commit_sync_transitions", transaction_id)
    _expect(bool(committed.get("ok", false)), "partial replacement commit succeeds")
    _expect(bool(committed.get("partial_update", false)), "commit reports the partial-update mode")
    _expect(int(committed.get("affected_edge_count", -1)) == 1, "commit reports one affected edge")
    var new_a: StaticBody3D = manager.call("get_transition_body", edge_a) as StaticBody3D
    var current_b: StaticBody3D = manager.call("get_transition_body", edge_b) as StaticBody3D
    _expect(is_instance_valid(new_a) and new_a != old_a, "changed edge receives a replacement body")
    _expect(is_instance_valid(current_b) and current_b == old_b, "unrelated edge retains its exact original body")
    _expect(is_instance_valid(new_a) and new_a.collision_layer == 1 and new_a.collision_mask == 0, "replacement edge publishes canonical collision state")
    _expect(int(committed.get("staged_edge_count", -1)) == 1, "commit reports one staged edge")
    _expect(int(committed.get("retired_edge_count", -1)) == 1, "commit retires only the replaced old edge")
    await process_frame
    await process_frame
    _expect(not is_instance_valid(old_a), "replaced old edge is released")
    await _release_holder(holder)


func _test_partial_removal_preserves_unaffected_edge() -> void:
    var fixture: Dictionary = await _make_two_pair_fixture()
    if fixture.is_empty():
        return
    var manager: Node3D = fixture["manager"]
    var holder: Node3D = fixture["holder"]
    var edge_a: String = str(fixture["edge_a"])
    var edge_b: String = str(fixture["edge_b"])
    var old_a: StaticBody3D = manager.call("get_transition_body", edge_a) as StaticBody3D
    var old_b: StaticBody3D = manager.call("get_transition_body", edge_b) as StaticBody3D
    var candidate_descriptors: Dictionary = _build_descriptors([fixture["pair_a"]])
    var candidate_patch_map: Dictionary = {
        "pair/a": fixture["a1"],
        "pair/b": fixture["b1"]
    }

    var prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        candidate_patch_map,
        [edge_b]
    )
    _expect(bool(prepared.get("ok", false)), "partial removal prepare succeeds")
    if not bool(prepared.get("ok", false)):
        await _release_holder(holder)
        return
    _expect(int(prepared.get("pending_staged_edge_count", -1)) == 0, "partial removal stages no replacement edge")
    _expect(int(prepared.get("pending_reused_edge_count", -1)) == 1, "partial removal preserves the unrelated edge")
    var committed: Dictionary = manager.call("commit_sync_transitions", int(prepared.get("transaction_id", -1)))
    _expect(bool(committed.get("ok", false)), "partial removal commit succeeds")
    _expect(manager.call("get_transition_body", edge_a) == old_a, "partial removal keeps the unrelated edge instance")
    _expect(manager.call("get_transition_body", edge_b) == null, "partial removal removes the targeted edge")
    _expect(int(committed.get("retired_edge_count", -1)) == 1, "partial removal retires exactly one old edge")
    _expect(not bool(fixture["a2"].call("is_shared_transition_active", "east")), "removed edge deactivates its old first patch side")
    _expect(not bool(fixture["b2"].call("is_shared_transition_active", "west")), "removed edge deactivates its old second patch side")
    await process_frame
    await process_frame
    _expect(not is_instance_valid(old_b), "removed old edge is released")
    await _release_holder(holder)


func _test_underseeded_change_fails_closed() -> void:
    var fixture: Dictionary = await _make_two_pair_fixture()
    if fixture.is_empty():
        return
    var manager: Node3D = fixture["manager"]
    var holder: Node3D = fixture["holder"]
    var old_a: StaticBody3D = manager.call("get_transition_body", str(fixture["edge_a"])) as StaticBody3D
    var old_b: StaticBody3D = manager.call("get_transition_body", str(fixture["edge_b"])) as StaticBody3D
    _expect(_apply_height(fixture["b1"], 1), "first changed patch accepts a new height")
    _expect(_apply_height(fixture["b2"], 1), "second changed patch accepts a new height")
    var candidate_descriptors: Dictionary = _build_descriptors(fixture["pairs"])
    var rejected: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        fixture["patches_by_stable_id"],
        [str(fixture["edge_a"])]
    )
    _expect(not bool(rejected.get("ok", true)), "partial prepare rejects an incomplete changed-edge seed list")
    _expect(
        str(rejected.get("error", "")) == "candidate_edge_changed_outside_affected_closure",
        "under-seeded partial update reports the changed edge outside the closure"
    )
    _expect(manager.call("get_transition_body", str(fixture["edge_a"])) == old_a, "under-seeded rejection preserves the first committed edge")
    _expect(manager.call("get_transition_body", str(fixture["edge_b"])) == old_b, "under-seeded rejection preserves the second committed edge")
    var pending: Dictionary = manager.get("_pending_sync_transaction")
    _expect(pending.is_empty(), "under-seeded rejection leaves no pending transaction")
    await _release_holder(holder)


func _make_two_pair_fixture() -> Dictionary:
    var holder := Node3D.new()
    holder.name = "PartialColliderTransactionFixture"
    root.add_child(holder)
    await process_frame

    var a1: Node3D = _new_patch(holder, "A1", Vector3.ZERO)
    var b1: Node3D = _new_patch(holder, "B1", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
    var a2: Node3D = _new_patch(holder, "A2", Vector3(100.0, 0.0, 0.0))
    var b2: Node3D = _new_patch(holder, "B2", Vector3(100.0 + PatchScript.PATCH_SIZE, 0.0, 0.0))
    await process_frame
    _expect(_apply_height(a1, 0), "first pair lower patch state is valid")
    _expect(_apply_height(b1, 2), "first pair higher patch state is valid")
    _expect(_apply_height(a2, 0), "second pair lower patch state is valid")
    _expect(_apply_height(b2, 2), "second pair higher patch state is valid")
    _expect(bool(a1.call("bind_neighbor_patch", "east", b1)), "first pair forward neighbor binding succeeds")
    _expect(bool(b1.call("bind_neighbor_patch", "west", a1)), "first pair reciprocal neighbor binding succeeds")
    _expect(bool(a2.call("bind_neighbor_patch", "east", b2)), "second pair forward neighbor binding succeeds")
    _expect(bool(b2.call("bind_neighbor_patch", "west", a2)), "second pair reciprocal neighbor binding succeeds")

    var patch_map: Dictionary = {
        "pair/a": a1,
        "pair/b": b1,
        "other/a": a2,
        "other/b": b2
    }
    var pairs: Array[Dictionary] = [
        {"first": a1, "first_id": "pair/a", "second": b1, "second_id": "pair/b"},
        {"first": a2, "first_id": "other/a", "second": b2, "second_id": "other/b"}
    ]
    var descriptors: Dictionary = _build_descriptors(pairs)
    _expect(descriptors.size() == 2, "initial full topology contains two transition descriptors")
    var manager := ManagerScript.new()
    manager.name = "PartialColliderManager"
    holder.add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call("sync_transitions", descriptors, patch_map)
    _expect(bool(initial.get("ok", false)), "initial full-rebuild transaction commits both edges")
    if not bool(initial.get("ok", false)):
        await _release_holder(holder)
        return {}
    return {
        "holder": holder,
        "manager": manager,
        "a1": a1,
        "b1": b1,
        "a2": a2,
        "b2": b2,
        "pair_a": pairs[0],
        "pairs": pairs,
        "patches_by_stable_id": patch_map,
        "edge_a": _edge_key_for_pair(descriptors, "pair/a"),
        "edge_b": _edge_key_for_pair(descriptors, "other/a")
    }


func _new_patch(holder: Node3D, patch_name: String, position: Vector3) -> Node3D:
    var patch: Node3D = PatchScript.new()
    patch.name = patch_name
    patch.position = position
    holder.add_child(patch)
    return patch


func _build_descriptors(pairs: Array) -> Dictionary:
    var result: Dictionary = {}
    for pair_value in pairs:
        if not (pair_value is Dictionary):
            continue
        var pair: Dictionary = pair_value
        var first: Node3D = pair.get("first") as Node3D
        var second: Node3D = pair.get("second") as Node3D
        if not is_instance_valid(first) or not is_instance_valid(second):
            continue
        var built: Dictionary = DescriptorScript.build(
            _snapshot(first, str(pair.get("first_id", ""))),
            _snapshot(second, str(pair.get("second_id", "")))
        )
        if not bool(built.get("ok", false)):
            continue
        var descriptor: Dictionary = built.get("descriptor", {})
        if bool(descriptor.get("transition_required", false)):
            result[str(descriptor.get("edge_key", ""))] = descriptor
    return result


func _snapshot(patch: Node3D, stable_id: String) -> Dictionary:
    var state: Dictionary = patch.call("get_world_object_state")
    return {
        "stable_id": stable_id,
        "position": patch.global_position,
        "patch_size": PatchScript.PATCH_SIZE,
        "height_level": int(state.get("height_level", 0)),
        "revision": int(state.get("revision", 0))
    }


func _edge_key_for_pair(descriptors: Dictionary, first_id: String) -> String:
    for key_value in descriptors.keys():
        var descriptor: Dictionary = descriptors[key_value]
        if str(descriptor.get("first_stable_id", "")) == first_id:
            return str(key_value)
    return ""


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
