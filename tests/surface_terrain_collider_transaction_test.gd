extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const FaultPatchScript = preload("res://tests/fixtures/transactional_surface_terrain_patch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://tests/fixtures/transactional_surface_terrain_collider_manager.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await _test_prepare_abort_preserves_committed_edge()
    await _test_prepare_abort_preserves_committed_corner_caps()
    await _test_commit_publishes_replacement_edge()
    await _test_stale_patch_snapshot_rejects_commit()
    await _test_activation_failure_restores_patch_flags()
    await _test_clear_all_aborts_pending_transaction()
    if failures.is_empty():
        print("Surface terrain collider prepare/commit/abort transaction tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error("FAIL: " + failure)
    quit(1)


func _test_prepare_abort_preserves_committed_edge() -> void:
    var fixture: Dictionary = await _make_two_patch_fixture(false)
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Variant = fixture["manager"]
    var higher: Node3D = fixture["higher"]
    var edge_key: String = str(fixture["edge_key"])
    var original_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D

    _expect(_apply_height(higher, 1, 2), "prepare/abort candidate changes the real edge geometry")
    var binding: Dictionary = _bind_fixture(fixture)
    _expect(bool(binding.get("ok", false)), "prepare/abort candidate binder succeeds")
    if not bool(binding.get("ok", false)):
        await _release_holder(holder)
        return

    var prepared: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(bool(prepared.get("ok", false)), "prepare creates a pending edge transaction")
    _expect(int(prepared.get("pending_staged_edge_count", -1)) == 1, "prepare stages exactly one replacement edge")
    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var staged_ref: WeakRef = manager.last_staged_edge_ref
    var staged_body: StaticBody3D = staged_ref.get_ref() as StaticBody3D
    _expect(is_instance_valid(staged_body) and staged_body.collision_layer == 0, "prepared replacement edge remains collision-disabled")
    _expect(is_instance_valid(original_body) and manager.call("get_transition_body", edge_key) == original_body and original_body.collision_layer == 1, "prepare leaves the exact committed edge active")

    var wrong_abort: Dictionary = manager.call("abort_sync_transitions", transaction_id + 1)
    _expect(not bool(wrong_abort.get("ok", true)) and str(wrong_abort.get("error", "")) == "invalid_transaction_id", "wrong transaction id cannot abort the pending transaction")
    _expect(is_instance_valid(staged_ref.get_ref()), "wrong transaction id leaves staged resource owned")
    var second_prepare: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(not bool(second_prepare.get("ok", true)) and str(second_prepare.get("error", "")) == "transaction_in_progress", "manager rejects a concurrent second prepare")
    var first_active_before_abort: bool = bool(fixture["lower"].call("is_shared_transition_active", str(fixture["first_side"])))
    var second_active_before_abort: bool = bool(higher.call("is_shared_transition_active", str(fixture["second_side"])))

    var aborted: Dictionary = manager.call("abort_sync_transitions", transaction_id)
    _expect(bool(aborted.get("ok", false)) and bool(aborted.get("aborted", false)), "matching transaction id aborts successfully")
    await process_frame
    await process_frame
    _expect(staged_ref.get_ref() == null, "abort releases the staged replacement edge")
    _expect(is_instance_valid(original_body) and manager.call("get_transition_body", edge_key) == original_body and original_body.collision_layer == 1, "abort preserves the exact old committed edge")
    _expect(bool(fixture["lower"].call("is_shared_transition_active", str(fixture["first_side"]))) == first_active_before_abort, "abort leaves the first patch transition flag unchanged")
    _expect(bool(higher.call("is_shared_transition_active", str(fixture["second_side"]))) == second_active_before_abort, "abort leaves the second patch transition flag unchanged")
    await _release_holder(holder)


func _test_prepare_abort_preserves_committed_corner_caps() -> void:
    var fixture: Dictionary = await _make_checkerboard_fixture()
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Variant = fixture["manager"]
    var patches: Array[Node3D] = fixture["patches"]
    var original_caps: Dictionary = {}
    for entry in fixture["corner_refs"]:
        var stable_id: String = str(entry["stable_id"])
        var corner: String = str(entry["corner"])
        original_caps[stable_id + "|" + corner] = manager.call("get_corner_cap_body", stable_id, corner)

    for patch in patches:
        var state: Dictionary = patch.call("get_world_object_state")
        var current_height: int = int(state.get("height_level", 0))
        _expect(_apply_height(patch, 2 - current_height, 2), patch.name + " accepts checkerboard inversion")
    var binding: Dictionary = _bind_fixture(fixture)
    _expect(bool(binding.get("ok", false)), "checkerboard candidate binder succeeds")
    if not bool(binding.get("ok", false)):
        await _release_holder(holder)
        return

    var prepared: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(bool(prepared.get("ok", false)), "checkerboard prepare creates a pending transaction")
    _expect(int(prepared.get("pending_staged_corner_cap_count", -1)) == 4, "checkerboard prepare stages four replacement corner caps")
    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var staged_ref: WeakRef = manager.last_staged_corner_ref
    var staged_body: StaticBody3D = staged_ref.get_ref() as StaticBody3D
    _expect(is_instance_valid(staged_body) and staged_body.collision_layer == 0, "prepared replacement corner cap remains collision-disabled")
    for key in original_caps.keys():
        var old_body: StaticBody3D = original_caps[key] as StaticBody3D
        _expect(is_instance_valid(old_body) and old_body.collision_layer == 1, key + " remains committed while replacement caps are staged")

    var aborted: Dictionary = manager.call("abort_sync_transitions", transaction_id)
    _expect(bool(aborted.get("ok", false)), "checkerboard transaction abort succeeds")
    await process_frame
    await process_frame
    _expect(staged_ref.get_ref() == null, "abort releases the staged replacement corner cap")
    for key in original_caps.keys():
        var parts: PackedStringArray = key.split("|")
        var current_body: StaticBody3D = manager.call("get_corner_cap_body", parts[0], parts[1]) as StaticBody3D
        var old_body: StaticBody3D = original_caps[key] as StaticBody3D
        _expect(is_instance_valid(old_body) and current_body == old_body and current_body.collision_layer == 1, key + " retains its exact committed cap after abort")
    await _release_holder(holder)


func _test_commit_publishes_replacement_edge() -> void:
    var fixture: Dictionary = await _make_two_patch_fixture(false)
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Variant = fixture["manager"]
    var higher: Node3D = fixture["higher"]
    var edge_key: String = str(fixture["edge_key"])
    var original_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
    _expect(_apply_height(higher, 1, 2), "commit candidate changes the real edge geometry")
    var binding: Dictionary = _bind_fixture(fixture)
    var prepared: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(bool(prepared.get("ok", false)), "commit test prepares successfully")
    var staged_ref: WeakRef = manager.last_staged_edge_ref
    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var committed: Dictionary = manager.call("commit_sync_transitions", transaction_id)
    _expect(bool(committed.get("ok", false)), "matching transaction id commits successfully")
    _expect(int(committed.get("staged_edge_count", -1)) == 1 and int(committed.get("retired_edge_count", -1)) == 1, "commit reports one staged and one retired edge")
    var new_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
    _expect(is_instance_valid(new_body) and new_body != original_body and new_body.collision_layer == 1, "commit publishes the new active edge body")
    _expect(is_instance_valid(original_body) and original_body.is_queued_for_deletion(), "commit retires the old edge only after replacement activation")
    await process_frame
    await process_frame
    _expect(not is_instance_valid(original_body), "retired edge is released after commit")
    _expect(staged_ref.get_ref() == new_body, "staged edge becomes the exact committed edge")
    await _release_holder(holder)


func _test_stale_patch_snapshot_rejects_commit() -> void:
    var fixture: Dictionary = await _make_two_patch_fixture(false)
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Variant = fixture["manager"]
    var lower: Node3D = fixture["lower"]
    var higher: Node3D = fixture["higher"]
    var edge_key: String = str(fixture["edge_key"])
    var original_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
    _expect(_apply_height(higher, 1, 2), "stale-snapshot candidate changes the edge geometry")
    var binding: Dictionary = _bind_fixture(fixture)
    var prepared: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(bool(prepared.get("ok", false)), "stale-snapshot test prepares successfully")
    var staged_ref: WeakRef = manager.last_staged_edge_ref
    var transaction_id: int = int(prepared.get("transaction_id", -1))

    var changed_state: Dictionary = lower.call("get_world_object_state")
    changed_state["revision"] = int(changed_state.get("revision", 0)) + 1
    _expect(bool(lower.call("apply_world_object_state", changed_state)), "external patch revision changes after prepare")
    var rejected: Dictionary = manager.call("commit_sync_transitions", transaction_id)
    _expect(not bool(rejected.get("ok", true)) and str(rejected.get("error", "")) == "stale_transaction_snapshot", "commit rejects a patch state changed after prepare")
    await process_frame
    await process_frame
    _expect(staged_ref.get_ref() == null, "stale transaction releases its staged edge")
    _expect(is_instance_valid(original_body) and manager.call("get_transition_body", edge_key) == original_body and original_body.collision_layer == 1, "stale transaction preserves the previously committed edge")
    _expect(int(lower.call("get_world_object_state").get("revision", -1)) == int(changed_state["revision"]), "stale transaction does not overwrite the external patch state")
    await _release_holder(holder)


func _test_activation_failure_restores_patch_flags() -> void:
    var fixture: Dictionary = await _make_two_patch_fixture(true)
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Variant = fixture["manager"]
    var lower: Node3D = fixture["lower"]
    var higher: Variant = fixture["higher"]
    var edge_key: String = str(fixture["edge_key"])
    var original_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D

    _expect(bool(lower.call("set_shared_transition_active", str(fixture["first_side"]), false)), "lower patch can be reset before activation fault injection")
    _expect(bool(higher.call("set_shared_transition_active", str(fixture["second_side"]), false)), "higher patch can be reset before activation fault injection")
    _expect(_apply_height(higher, 1, 2), "activation-failure candidate changes the edge geometry")
    var binding: Dictionary = _bind_fixture(fixture)
    var prepared: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(bool(prepared.get("ok", false)), "activation-failure transaction prepares successfully")
    var staged_ref: WeakRef = manager.last_staged_edge_ref
    var transaction_id: int = int(prepared.get("transaction_id", -1))
    higher.fail_activation_on_call = int(higher.activation_call_count) + 1

    var rejected: Dictionary = manager.call("commit_sync_transitions", transaction_id)
    _expect(not bool(rejected.get("ok", true)) and str(rejected.get("error", "")) == "second_patch_activation_failed", "second endpoint activation rejection aborts commit")
    _expect(bool(rejected.get("rollback_ok", false)), "patch-side rollback reports success")
    _expect(not bool(lower.call("is_shared_transition_active", str(fixture["first_side"]))), "first endpoint activation is restored to its pre-transaction state")
    _expect(not bool(higher.call("is_shared_transition_active", str(fixture["second_side"]))), "rejecting endpoint remains at its pre-transaction state")
    await process_frame
    await process_frame
    _expect(staged_ref.get_ref() == null, "activation failure releases the staged edge")
    _expect(is_instance_valid(original_body) and manager.call("get_transition_body", edge_key) == original_body and original_body.collision_layer == 1, "activation failure preserves the exact old committed edge")
    await _release_holder(holder)


func _test_clear_all_aborts_pending_transaction() -> void:
    var fixture: Dictionary = await _make_two_patch_fixture(false)
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Variant = fixture["manager"]
    var higher: Node3D = fixture["higher"]
    var edge_key: String = str(fixture["edge_key"])
    var original_body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
    _expect(_apply_height(higher, 1, 2), "clear-all candidate changes the edge geometry")
    var binding: Dictionary = _bind_fixture(fixture)
    var prepared: Dictionary = manager.call("prepare_sync_transitions", binding.get("descriptors", {}), fixture["patches_by_stable_id"])
    _expect(bool(prepared.get("ok", false)), "clear-all test prepares successfully")
    var staged_ref: WeakRef = manager.last_staged_edge_ref

    manager.call("clear_all")
    await process_frame
    await process_frame
    _expect(int(manager.call("get_transition_count")) == 0 and int(manager.call("get_corner_cap_count")) == 0, "clear_all retires committed maps and aborts the pending transaction")
    _expect(staged_ref.get_ref() == null, "clear_all releases pending staged resources")
    _expect(not is_instance_valid(original_body), "clear_all releases the formerly committed edge")
    await _release_holder(holder)


func _make_two_patch_fixture(use_fault_patch: bool) -> Dictionary:
    var holder := Node3D.new()
    holder.name = "ColliderTransactionFixture"
    root.add_child(holder)
    var lower: Node3D = PatchScript.new()
    lower.name = "Lower"
    var higher: Node3D = FaultPatchScript.new() as Node3D if use_fault_patch else PatchScript.new()
    higher.name = "Higher"
    higher.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
    holder.add_child(lower)
    holder.add_child(higher)
    await process_frame
    _expect(_apply_height(lower, 0, 1), "lower patch accepts baseline state")
    _expect(_apply_height(higher, 2, 1), "higher patch accepts baseline state")

    var stable_ids: Dictionary = {
        lower.get_instance_id(): "a/transaction/lower",
        higher.get_instance_id(): "b/transaction/higher"
    }
    var patches_by_stable_id: Dictionary = {
        "a/transaction/lower": lower,
        "b/transaction/higher": higher
    }
    var patches: Array[Node3D] = [lower, higher]
    var binding: Dictionary = BinderScript.bind_patches(patches, stable_ids)
    _expect(bool(binding.get("ok", false)), "two-patch fixture binder succeeds")
    if not bool(binding.get("ok", false)):
        await _release_holder(holder)
        return {}

    var descriptors: Dictionary = binding.get("descriptors", {})
    var edge_key: String = _first_key(descriptors)
    var descriptor: Dictionary = descriptors.get(edge_key, {})
    var manager: Variant = ManagerScript.new()
    holder.add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call("sync_transitions", descriptors, patches_by_stable_id)
    _expect(bool(initial.get("ok", false)) and int(initial.get("active_count", -1)) == 1, "two-patch fixture commits one real transition")
    if not bool(initial.get("ok", false)):
        await _release_holder(holder)
        return {}
    return {
        "holder": holder,
        "manager": manager,
        "lower": lower,
        "higher": higher,
        "patches": patches,
        "stable_ids": stable_ids,
        "patches_by_stable_id": patches_by_stable_id,
        "descriptors": descriptors,
        "edge_key": edge_key,
        "first_side": str(descriptor.get("first_side", "")),
        "second_side": str(descriptor.get("second_side", ""))
    }


func _make_checkerboard_fixture() -> Dictionary:
    var holder := Node3D.new()
    holder.name = "ColliderTransactionCornerFixture"
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
    _expect(_apply_height(north_west, 0, 1), "checkerboard north-west accepts low baseline")
    _expect(_apply_height(north_east, 2, 1), "checkerboard north-east accepts high baseline")
    _expect(_apply_height(south_west, 2, 1), "checkerboard south-west accepts high baseline")
    _expect(_apply_height(south_east, 0, 1), "checkerboard south-east accepts low baseline")

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
    _expect(bool(binding.get("ok", false)), "checkerboard fixture binder succeeds")
    if not bool(binding.get("ok", false)):
        await _release_holder(holder)
        return {}
    var manager: Variant = ManagerScript.new()
    holder.add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches_by_stable_id)
    _expect(bool(initial.get("ok", false)) and int(initial.get("corner_cap_count", -1)) == 4, "checkerboard fixture commits four real corner caps")
    if not bool(initial.get("ok", false)):
        await _release_holder(holder)
        return {}
    return {
        "holder": holder,
        "manager": manager,
        "patches": patches,
        "patches_by_stable_id": patches_by_stable_id,
        "stable_ids": stable_ids,
        "corner_refs": [
            {"stable_id": "cap/north_west", "corner": "south_east"},
            {"stable_id": "cap/north_east", "corner": "south_west"},
            {"stable_id": "cap/south_west", "corner": "north_east"},
            {"stable_id": "cap/south_east", "corner": "north_west"}
        ]
    }


func _bind_fixture(fixture: Dictionary) -> Dictionary:
    var patches: Array[Node3D] = fixture.get("patches", [])
    var stable_ids: Dictionary = fixture.get("stable_ids", {})
    return BinderScript.bind_patches(patches, stable_ids)


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
