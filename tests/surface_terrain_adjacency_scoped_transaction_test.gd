extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ScopedTransactionScript = preload("res://systems/SurfaceTerrainAdjacencyScopedTransaction.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await _test_prepare_is_non_mutating()
    await _test_apply_rebinds_only_scoped_endpoints_and_batches_refresh()
    await _test_rollback_restores_old_nodes_and_shared_flags()
    await _test_underseeded_projection_is_rejected_without_mutation()
    if failures.is_empty():
        print("Surface terrain scoped neighbor-state transaction tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error("FAIL: " + failure)
    quit(1)


func _test_prepare_is_non_mutating() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    var transaction = ScopedTransactionScript.new()
    var prepared: Dictionary = _prepare_replacement(transaction, fixture, ["patch/b"])
    _expect(bool(prepared.get("ok", false)), "scoped replacement prepare succeeds")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "prepare leaves the old first endpoint bound")
    _expect(fixture["b"].call("get_bound_neighbor_patch", "west") == fixture["a"], "prepare leaves the old reciprocal endpoint bound")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == null, "prepare leaves the replacement endpoint untouched")
    _expect(not bool(fixture["a"].call("is_shared_transition_active", "east")), "prepare does not change the old shared-transition flag")
    if bool(prepared.get("ok", false)):
        var aborted: Dictionary = transaction.abort(int(prepared.get("transaction_id", -1)))
        _expect(bool(aborted.get("ok", false)), "unapplied scoped transaction can be aborted")
    await _release_fixture(fixture)


func _test_apply_rebinds_only_scoped_endpoints_and_batches_refresh() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    var transaction = ScopedTransactionScript.new()
    var prepared: Dictionary = _prepare_replacement(transaction, fixture, ["patch/b"])
    _expect(bool(prepared.get("ok", false)), "scoped apply fixture prepares")
    if not bool(prepared.get("ok", false)):
        await _release_fixture(fixture)
        return

    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var applied: Dictionary = transaction.apply(transaction_id)
    _expect(bool(applied.get("ok", false)), "scoped neighbor-state apply succeeds")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b_replacement"], "changed endpoint binds to the replacement Patch")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == fixture["a"], "replacement endpoint binds reciprocally")
    _expect(fixture["b"].call("get_bound_neighbor_patch", "west") == null, "retired Patch no longer holds the old reciprocal binding")
    _expect(fixture["c"].call("get_bound_neighbor_patch", "east") == fixture["d"], "unrelated first endpoint remains the exact original Node")
    _expect(fixture["d"].call("get_bound_neighbor_patch", "west") == fixture["c"], "unrelated reciprocal endpoint remains the exact original Node")
    _expect(_refresh_count(fixture["a"]) == 0 and _refresh_count(fixture["b"]) == 0 and _refresh_count(fixture["b_replacement"]) == 0, "segmentation refresh stays deferred while the transaction is open")

    _expect(bool(fixture["a"].call("set_shared_transition_active", "east", true)), "downstream collider commit can activate the new first side")
    _expect(bool(fixture["b_replacement"].call("set_shared_transition_active", "west", true)), "downstream collider commit can activate the new reciprocal side")
    var finalized: Dictionary = transaction.finalize(transaction_id)
    _expect(bool(finalized.get("ok", false)), "scoped transaction finalizes after downstream collider commit")
    _expect(_refresh_count(fixture["a"]) == 1, "changed first Patch refreshes segmentation exactly once")
    _expect(_refresh_count(fixture["b"]) == 1, "retired Patch flushes its pending segmentation exactly once")
    _expect(_refresh_count(fixture["b_replacement"]) == 1, "replacement Patch refreshes segmentation exactly once")
    _expect(_refresh_count(fixture["c"]) == 0 and _refresh_count(fixture["d"]) == 0, "unrelated Patch segmentation is never refreshed")
    await _release_fixture(fixture)


func _test_rollback_restores_old_nodes_and_shared_flags() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    _expect(bool(fixture["a"].call("set_shared_transition_active", "east", true)), "old first shared-transition flag is active before prepare")
    _expect(bool(fixture["b"].call("set_shared_transition_active", "west", true)), "old reciprocal shared-transition flag is active before prepare")
    _reset_refresh_counters(fixture)

    var transaction = ScopedTransactionScript.new()
    var prepared: Dictionary = _prepare_replacement(transaction, fixture, ["patch/b"])
    _expect(bool(prepared.get("ok", false)), "rollback fixture prepares")
    if not bool(prepared.get("ok", false)):
        await _release_fixture(fixture)
        return
    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var applied: Dictionary = transaction.apply(transaction_id)
    _expect(bool(applied.get("ok", false)), "rollback fixture applies candidate bindings")
    _expect(bool(fixture["a"].call("set_shared_transition_active", "east", true)), "simulated collider commit activates the candidate first side")
    _expect(bool(fixture["b_replacement"].call("set_shared_transition_active", "west", true)), "simulated collider commit activates the candidate reciprocal side")

    var rolled_back: Dictionary = transaction.rollback(transaction_id)
    _expect(bool(rolled_back.get("ok", false)), "downstream failure rollback succeeds")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "rollback restores the exact old first neighbor Node")
    _expect(fixture["b"].call("get_bound_neighbor_patch", "west") == fixture["a"], "rollback restores the exact old reciprocal neighbor Node")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == null, "rollback clears the replacement Patch binding")
    _expect(bool(fixture["a"].call("is_shared_transition_active", "east")), "rollback restores the old first shared-transition flag")
    _expect(bool(fixture["b"].call("is_shared_transition_active", "west")), "rollback restores the old reciprocal shared-transition flag")
    _expect(not bool(fixture["b_replacement"].call("is_shared_transition_active", "west")), "rollback clears the replacement shared-transition flag")
    _expect(_refresh_count(fixture["c"]) == 0 and _refresh_count(fixture["d"]) == 0, "rollback never refreshes unrelated Patch segmentation")
    await _release_fixture(fixture)


func _test_underseeded_projection_is_rejected_without_mutation() -> void:
    var fixture: Dictionary = await _make_fixture(true)
    if fixture.is_empty():
        return
    var transaction = ScopedTransactionScript.new()
    var old_scoped: Dictionary = _filter_descriptors(fixture["old_report"].get("descriptors", {}), ["patch/b", "patch/d"])
    var candidate_scoped: Dictionary = _filter_descriptors(fixture["candidate_report"].get("descriptors", {}), ["patch/b", "patch/d"])
    var all_keys: Array[String] = _union_keys(old_scoped, candidate_scoped)
    var underseeded: Array[String] = []
    if not all_keys.is_empty():
        underseeded.append(all_keys[0])
    var rejected: Dictionary = transaction.prepare(
        old_scoped,
        candidate_scoped,
        fixture["old_patches_by_stable_id"],
        fixture["candidate_patches_by_stable_id"],
        underseeded
    )
    _expect(not bool(rejected.get("ok", true)), "scoped prepare rejects an incomplete changed-edge projection")
    _expect(str(rejected.get("error", "")) == "changed_edge_key_mismatch", "under-seeded projection reports an exact key-set mismatch")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "under-seeded rejection preserves the first old binding")
    _expect(fixture["c"].call("get_bound_neighbor_patch", "east") == fixture["d"], "under-seeded rejection preserves the second old binding")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == null, "under-seeded rejection leaves the first replacement untouched")
    _expect(fixture["d_replacement"].call("get_bound_neighbor_patch", "west") == null, "under-seeded rejection leaves the second replacement untouched")
    _expect(not transaction.has_pending_transaction(), "under-seeded rejection creates no pending transaction")
    await _release_fixture(fixture)


func _make_fixture(replace_two_pairs: bool) -> Dictionary:
    var holder := Node3D.new()
    holder.name = "ScopedNeighborStateTransactionFixture"
    root.add_child(holder)

    var patch_size: float = PatchScript.PATCH_SIZE
    var a: Node3D = _new_patch(holder, "A", Vector3.ZERO, 1)
    var b: Node3D = _new_patch(holder, "B", Vector3(patch_size, 0.0, 0.0), 0)
    var c: Node3D = _new_patch(holder, "C", Vector3(20.0, 0.0, 0.0), 1)
    var d: Node3D = _new_patch(holder, "D", Vector3(20.0 + patch_size, 0.0, 0.0), 0)
    await process_frame
    await physics_frame

    var old_patches: Array[Node3D] = [a, b, c, d]
    var old_instance_ids: Dictionary = {
        a.get_instance_id(): "patch/a",
        b.get_instance_id(): "patch/b",
        c.get_instance_id(): "patch/c",
        d.get_instance_id(): "patch/d"
    }
    var old_report: Dictionary = BinderScript.build_candidate_descriptors(old_patches, old_instance_ids)
    _expect(bool(old_report.get("ok", false)), "old production Patch set produces candidate descriptors")
    var old_bind: Dictionary = BinderScript.bind_patches(old_patches, old_instance_ids)
    _expect(bool(old_bind.get("ok", false)), "old production Patch set binds reciprocal neighbor state")

    var b_replacement: Node3D = _new_patch(holder, "BReplacement", Vector3(patch_size, 0.0, 0.0), 0)
    var d_replacement: Node3D = _new_patch(holder, "DReplacement", Vector3(20.0 + patch_size, 0.0, 0.0), 0)
    await process_frame
    await physics_frame

    var candidate_patches: Array[Node3D] = [a, b_replacement, c, d]
    if replace_two_pairs:
        candidate_patches = [a, b_replacement, c, d_replacement]
    var candidate_instance_ids: Dictionary = {
        a.get_instance_id(): "patch/a",
        b_replacement.get_instance_id(): "patch/b",
        c.get_instance_id(): "patch/c",
        d.get_instance_id(): "patch/d" if replace_two_pairs else "patch/d"
    }
    var candidate_report: Dictionary = BinderScript.build_candidate_descriptors(candidate_patches, candidate_instance_ids)
    _expect(bool(candidate_report.get("ok", false)), "candidate production Patch set produces descriptors")

    for patch in [a, b, c, d, b_replacement, d_replacement]:
        patch.call("set_collision_segmentation_refresh_counter_enabled", true)
        patch.call("set_collision_segmentation_refresh_counter_enabled", false)
        patch.call("set_collision_segmentation_refresh_counter_enabled", true)

    var old_map: Dictionary = {
        "patch/a": a,
        "patch/b": b,
        "patch/c": c,
        "patch/d": d
    }
    var candidate_map: Dictionary = {
        "patch/a": a,
        "patch/b": b_replacement,
        "patch/c": c,
        "patch/d": d_replacement if replace_two_pairs else d
    }
    return {
        "holder": holder,
        "a": a,
        "b": b,
        "c": c,
        "d": d,
        "b_replacement": b_replacement,
        "d_replacement": d_replacement,
        "old_report": old_report,
        "candidate_report": candidate_report,
        "old_patches_by_stable_id": old_map,
        "candidate_patches_by_stable_id": candidate_map
    }


func _new_patch(holder: Node3D, patch_name: String, patch_position: Vector3, height: int) -> Node3D:
    var patch: Node3D = PatchScript.new()
    patch.name = patch_name
    patch.position = patch_position
    holder.add_child(patch)
    patch.call("apply_world_object_state", {
        "height_level": height,
        "surface_type": "soil",
        "revision": height + 1
    })
    return patch


func _prepare_replacement(transaction: RefCounted, fixture: Dictionary, target_ids: Array) -> Dictionary:
    var old_scoped: Dictionary = _filter_descriptors(fixture["old_report"].get("descriptors", {}), target_ids)
    var candidate_scoped: Dictionary = _filter_descriptors(fixture["candidate_report"].get("descriptors", {}), target_ids)
    var changed_keys: Array[String] = _union_keys(old_scoped, candidate_scoped)
    return transaction.call(
        "prepare",
        old_scoped,
        candidate_scoped,
        fixture["old_patches_by_stable_id"],
        fixture["candidate_patches_by_stable_id"],
        changed_keys
    )


func _filter_descriptors(descriptors: Dictionary, stable_ids: Array) -> Dictionary:
    var result: Dictionary = {}
    for edge_key_value in descriptors.keys():
        var descriptor: Dictionary = descriptors[edge_key_value]
        if stable_ids.has(str(descriptor.get("first_stable_id", ""))) or stable_ids.has(str(descriptor.get("second_stable_id", ""))):
            result[str(edge_key_value)] = descriptor.duplicate(true)
    return result


func _union_keys(first: Dictionary, second: Dictionary) -> Array[String]:
    var keys: Dictionary = {}
    for key in first.keys():
        keys[str(key)] = true
    for key in second.keys():
        keys[str(key)] = true
    var result: Array[String] = []
    for key_value in keys.keys():
        result.append(str(key_value))
    result.sort()
    return result


func _reset_refresh_counters(fixture: Dictionary) -> void:
    for patch in [fixture["a"], fixture["b"], fixture["c"], fixture["d"], fixture["b_replacement"], fixture["d_replacement"]]:
        patch.call("set_collision_segmentation_refresh_counter_enabled", false)
        patch.call("set_collision_segmentation_refresh_counter_enabled", true)


func _refresh_count(patch: Node3D) -> int:
    if not is_instance_valid(patch):
        return -1
    return int(patch.call("get_collision_segmentation_refresh_count"))


func _release_fixture(fixture: Dictionary) -> void:
    var holder: Node3D = fixture.get("holder") as Node3D
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
