extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const ScopedTransactionScript = preload("res://systems/SurfaceTerrainAdjacencyScopedTransaction.gd")

class FaultInjectingPatch extends SurfaceTerrainPatch:
    var clear_failures_remaining: int = 0

    func clear_neighbor_edge_state(side: String) -> bool:
        if clear_failures_remaining > 0:
            clear_failures_remaining -= 1
            return false
        return super.clear_neighbor_edge_state(side)

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await _test_prepare_is_non_mutating()
    await _test_apply_rebinds_only_scoped_endpoints_and_batches_refresh()
    await _test_rollback_restores_old_nodes_and_shared_flags()
    await _test_apply_recovery_retains_pending_transaction_for_retry()
    await _test_partial_collider_commit_coordinates_scoped_neighbor_apply()
    await _test_partial_collider_failure_rolls_back_scoped_neighbor_apply()
    await _test_stale_old_snapshot_is_rejected_before_mutation()
    await _test_stale_candidate_snapshot_is_rejected_before_mutation()
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




func _test_apply_recovery_retains_pending_transaction_for_retry() -> void:
    var holder := Node3D.new()
    holder.name = "ScopedNeighborRecoveryFixture"
    root.add_child(holder)

    var a: FaultInjectingPatch = FaultInjectingPatch.new()
    a.name = "FaultInjectingA"
    a.position = Vector3.ZERO
    holder.add_child(a)
    a.call("apply_world_object_state", {
        "height_level": 1,
        "surface_type": "soil",
        "revision": 2
    })
    var b: Node3D = _new_patch(holder, "B", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0), 0)
    await process_frame
    await physics_frame

    var old_patches: Array[Node3D] = [a, b]
    var old_instance_ids: Dictionary = {
        a.get_instance_id(): "patch/a",
        b.get_instance_id(): "patch/b"
    }
    var old_report: Dictionary = BinderScript.build_candidate_descriptors(old_patches, old_instance_ids)
    _expect(bool(old_report.get("ok", false)), "recovery fixture builds the committed old descriptor")
    var old_bind: Dictionary = BinderScript.bind_patches(old_patches, old_instance_ids)
    _expect(bool(old_bind.get("ok", false)), "recovery fixture binds the original reciprocal edge")

    var b_replacement: Node3D = _new_patch(holder, "BReplacement", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0), 0)
    await process_frame
    await physics_frame
    var candidate_patches: Array[Node3D] = [a, b_replacement]
    var candidate_instance_ids: Dictionary = {
        a.get_instance_id(): "patch/a",
        b_replacement.get_instance_id(): "patch/b"
    }
    var candidate_report: Dictionary = BinderScript.build_candidate_descriptors(candidate_patches, candidate_instance_ids)
    _expect(bool(candidate_report.get("ok", false)), "recovery fixture builds the replacement candidate descriptor")

    var old_map: Dictionary = {"patch/a": a, "patch/b": b}
    var candidate_map: Dictionary = {"patch/a": a, "patch/b": b_replacement}
    var old_descriptors: Dictionary = old_report.get("descriptors", {})
    var candidate_descriptors: Dictionary = candidate_report.get("descriptors", {})
    var changed_keys: Array[String] = _union_keys(old_descriptors, candidate_descriptors)
    var transaction = ScopedTransactionScript.new()
    var prepared: Dictionary = transaction.call(
        "prepare",
        old_descriptors,
        candidate_descriptors,
        old_map,
        candidate_map,
        changed_keys
    )
    _expect(bool(prepared.get("ok", false)), "recovery fixture prepares before injecting a transient clear failure")
    if not bool(prepared.get("ok", false)):
        holder.queue_free()
        await process_frame
        return

    var transaction_id: int = int(prepared.get("transaction_id", -1))
    a.clear_failures_remaining = 3
    var failed_apply: Dictionary = transaction.call("apply", transaction_id)
    _expect(not bool(failed_apply.get("ok", true)), "injected old-edge clear failure aborts Apply")
    _expect(str(failed_apply.get("error", "")) == "apply_failed_and_rollback_failed", "injected rollback failure is reported explicitly")
    _expect(not bool(failed_apply.get("rollback_restored", true)), "injected rollback failure is not reported as restored")
    _expect(bool(failed_apply.get("batches_ended", false)), "segmentation batches that did close are reported as ended")
    _expect(bool(failed_apply.get("pending_retained", false)), "failed recovery retains its pending transaction and strong Patch references")
    _expect(transaction.has_pending_transaction(), "caller can still recover the failed transaction")
    _expect(transaction.get("_pending").get("batch_patches", []).is_empty(), "successfully ended batches are removed from the retry list")

    a.clear_failures_remaining = 0
    var retried_rollback: Dictionary = transaction.call("rollback", transaction_id)
    _expect(bool(retried_rollback.get("ok", false)), "rollback can be retried after the transient failure is removed")
    _expect(not transaction.has_pending_transaction(), "successful retry finally releases pending transaction references")
    _expect(a.call("get_bound_neighbor_patch", "east") == b, "retry restores the exact original first neighbor Node")
    _expect(b.call("get_bound_neighbor_patch", "west") == a, "retry restores the exact original reciprocal neighbor Node")
    _expect(b_replacement.call("get_bound_neighbor_patch", "west") == null, "retry leaves the replacement Patch unbound")

    holder.queue_free()
    await process_frame
    await process_frame


func _test_partial_collider_commit_coordinates_scoped_neighbor_apply() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    var manager = ManagerScript.new()
    fixture["holder"].add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call(
        "sync_transitions",
        fixture["old_report"].get("descriptors", {}),
        fixture["old_patches_by_stable_id"]
    )
    _expect(bool(initial.get("ok", false)) and int(initial.get("active_count", -1)) == 3, "real collider manager commits all three initial transition edges")
    if not bool(initial.get("ok", false)):
        await _release_fixture(fixture)
        return

    var old_scoped: Dictionary = _filter_descriptors(fixture["old_report"].get("descriptors", {}), ["patch/b"])
    var candidate_scoped: Dictionary = _filter_descriptors(fixture["candidate_report"].get("descriptors", {}), ["patch/b"])
    var changed_keys: Array[String] = _union_keys(old_scoped, candidate_scoped)
    var changed_edge_key: String = changed_keys[0]
    var west_edge_key: String = ""
    var unrelated_edge_key: String = ""
    for key_value in fixture["old_report"].get("descriptors", {}).keys():
        var key: String = str(key_value)
        if key == changed_edge_key:
            continue
        var descriptor: Dictionary = fixture["old_report"].get("descriptors", {}).get(key, {})
        if str(descriptor.get("first_stable_id", "")) == "patch/a" and str(descriptor.get("second_stable_id", "")) == "patch/e":
            west_edge_key = key
        else:
            unrelated_edge_key = key
    var old_body: StaticBody3D = manager.call("get_transition_body", changed_edge_key) as StaticBody3D
    var west_body: StaticBody3D = manager.call("get_transition_body", west_edge_key) as StaticBody3D
    var unrelated_body: StaticBody3D = manager.call("get_transition_body", unrelated_edge_key) as StaticBody3D

    var collider_prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        fixture["candidate_report"].get("descriptors", {}),
        fixture["candidate_patches_by_stable_id"],
        changed_keys
    )
    _expect(bool(collider_prepared.get("ok", false)), "partial collider manager prepares the same scoped edge delta: " + str(collider_prepared))
    _expect(int(collider_prepared.get("pending_staged_edge_count", -1)) == 1, "partial collider manager stages only the replaced edge")
    _expect(int(collider_prepared.get("pending_reused_edge_count", -1)) == 2, "partial collider manager preserves both unrelated edges")
    if not bool(collider_prepared.get("ok", false)):
        await _release_fixture(fixture)
        return

    var scoped = ScopedTransactionScript.new()
    var scoped_prepared: Dictionary = scoped.call(
        "prepare",
        old_scoped,
        candidate_scoped,
        fixture["old_patches_by_stable_id"],
        fixture["candidate_patches_by_stable_id"],
        changed_keys
    )
    _expect(bool(scoped_prepared.get("ok", false)), "scoped neighbor participant prepares beside the real collider transaction")
    if not bool(scoped_prepared.get("ok", false)):
        manager.call("abort_sync_transitions", int(collider_prepared.get("transaction_id", -1)))
        await _release_fixture(fixture)
        return

    var scoped_id: int = int(scoped_prepared.get("transaction_id", -1))
    var scoped_applied: Dictionary = scoped.call("apply", scoped_id)
    _expect(bool(scoped_applied.get("ok", false)), "scoped neighbor participant applies while collider resources remain staged")
    if not bool(scoped_applied.get("ok", false)):
        manager.call("abort_sync_transitions", int(collider_prepared.get("transaction_id", -1)))
        await _release_fixture(fixture)
        return

    var unscoped_flag_changed: bool = bool(fixture["a"].call("set_shared_transition_active", "west", false))
    _expect(unscoped_flag_changed, "unaffected west-side transition can be toggled during the scoped transaction")
    var unscoped_rejected: Dictionary = manager.call(
        "accept_scoped_neighbor_state_apply",
        int(collider_prepared.get("transaction_id", -1)),
        scoped_applied.get("endpoint_expectations", [])
    )
    _expect(not bool(unscoped_rejected.get("ok", true)) and str(unscoped_rejected.get("error", "")) == "unexpected_unscoped_patch_flag_change", "collider handshake rejects an unlisted side-state mutation")
    _expect(bool(fixture["a"].call("set_shared_transition_active", "west", true)), "unaffected west-side transition is restored before retry")
    var accepted: Dictionary = manager.call(
        "accept_scoped_neighbor_state_apply",
        int(collider_prepared.get("transaction_id", -1)),
        scoped_applied.get("endpoint_expectations", [])
    )
    _expect(bool(accepted.get("ok", false)), "collider manager rebases only explicitly changed endpoints and preserves every other side snapshot")
    var committed: Dictionary = manager.call("commit_sync_transitions", int(collider_prepared.get("transaction_id", -1)))
    _expect(bool(committed.get("ok", false)), "real partial collider commit succeeds after scoped neighbor-state apply")
    if bool(committed.get("ok", false)):
        var finalized: Dictionary = scoped.call("finalize", scoped_id)
        _expect(bool(finalized.get("ok", false)), "scoped neighbor transaction finalizes after real collider commit")
        var replacement_body: StaticBody3D = manager.call("get_transition_body", changed_edge_key) as StaticBody3D
        _expect(is_instance_valid(replacement_body) and replacement_body != old_body and replacement_body.collision_layer == 1 and replacement_body.collision_mask == 0, "collider manager publishes the replacement body with valid collision invariants")
        _expect(manager.call("get_transition_body", west_edge_key) == west_body, "partial collider commit preserves the same Patch opposite-side body by exact Node identity")
        _expect(manager.call("get_transition_body", unrelated_edge_key) == unrelated_body, "partial collider commit preserves the distant exact body Node")
        _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b_replacement"], "successful cross-participant commit publishes the replacement neighbor Node")
        _expect(fixture["b"].call("get_bound_neighbor_patch", "west") == null, "successful cross-participant commit retires the old reciprocal neighbor")
        _expect(bool(fixture["a"].call("is_shared_transition_active", "east")), "successful collider commit activates the new first Patch side")
        _expect(bool(fixture["b_replacement"].call("is_shared_transition_active", "west")), "successful collider commit activates the new reciprocal Patch side")
        _expect(bool(fixture["a"].call("is_shared_transition_active", "west")), "successful partial commit preserves the unaffected opposite-side transition flag")
    else:
        scoped.call("rollback", scoped_id)
    await _release_fixture(fixture)


func _test_partial_collider_failure_rolls_back_scoped_neighbor_apply() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    var manager = ManagerScript.new()
    fixture["holder"].add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call(
        "sync_transitions",
        fixture["old_report"].get("descriptors", {}),
        fixture["old_patches_by_stable_id"]
    )
    _expect(bool(initial.get("ok", false)) and int(initial.get("active_count", -1)) == 3, "failure fixture commits all three initial transition edges")
    if not bool(initial.get("ok", false)):
        await _release_fixture(fixture)
        return

    var old_scoped: Dictionary = _filter_descriptors(fixture["old_report"].get("descriptors", {}), ["patch/b"])
    var candidate_scoped: Dictionary = _filter_descriptors(fixture["candidate_report"].get("descriptors", {}), ["patch/b"])
    var changed_keys: Array[String] = _union_keys(old_scoped, candidate_scoped)
    var changed_edge_key: String = changed_keys[0]
    var west_edge_key: String = ""
    var unrelated_edge_key: String = ""
    for key_value in fixture["old_report"].get("descriptors", {}).keys():
        var key: String = str(key_value)
        if key == changed_edge_key:
            continue
        var descriptor: Dictionary = fixture["old_report"].get("descriptors", {}).get(key, {})
        if str(descriptor.get("first_stable_id", "")) == "patch/a" and str(descriptor.get("second_stable_id", "")) == "patch/e":
            west_edge_key = key
        else:
            unrelated_edge_key = key
    var old_body: StaticBody3D = manager.call("get_transition_body", changed_edge_key) as StaticBody3D
    var west_body: StaticBody3D = manager.call("get_transition_body", west_edge_key) as StaticBody3D
    var unrelated_body: StaticBody3D = manager.call("get_transition_body", unrelated_edge_key) as StaticBody3D

    var collider_prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        fixture["candidate_report"].get("descriptors", {}),
        fixture["candidate_patches_by_stable_id"],
        changed_keys
    )
    _expect(bool(collider_prepared.get("ok", false)), "failure fixture partial collider transaction prepares: " + str(collider_prepared))
    if not bool(collider_prepared.get("ok", false)):
        await _release_fixture(fixture)
        return

    var pending: Dictionary = manager.get("_pending_sync_transaction")
    var staged_edges: Dictionary = pending.get("staged_edges", {})
    var staged_record: Dictionary = staged_edges.get(changed_edge_key, {})
    var staged_body: StaticBody3D = staged_record.get("body") as StaticBody3D
    var staged_ref: WeakRef = weakref(staged_body)

    var scoped = ScopedTransactionScript.new()
    var scoped_prepared: Dictionary = scoped.call(
        "prepare",
        old_scoped,
        candidate_scoped,
        fixture["old_patches_by_stable_id"],
        fixture["candidate_patches_by_stable_id"],
        changed_keys
    )
    _expect(bool(scoped_prepared.get("ok", false)), "failure fixture scoped neighbor transaction prepares")
    if not bool(scoped_prepared.get("ok", false)):
        manager.call("abort_sync_transitions", int(collider_prepared.get("transaction_id", -1)))
        await _release_fixture(fixture)
        return
    var scoped_id: int = int(scoped_prepared.get("transaction_id", -1))
    var scoped_applied: Dictionary = scoped.call("apply", scoped_id)
    _expect(bool(scoped_applied.get("ok", false)), "failure fixture applies candidate neighbor bindings")
    if not bool(scoped_applied.get("ok", false)):
        manager.call("abort_sync_transitions", int(collider_prepared.get("transaction_id", -1)))
        await _release_fixture(fixture)
        return
    var accepted: Dictionary = manager.call(
        "accept_scoped_neighbor_state_apply",
        int(collider_prepared.get("transaction_id", -1)),
        scoped_applied.get("endpoint_expectations", [])
    )
    _expect(bool(accepted.get("ok", false)), "collider manager accepts the exact scoped endpoint expectations before injected failure")

    if is_instance_valid(staged_body):
        staged_body.collision_mask = 1
    var rejected: Dictionary = manager.call("commit_sync_transitions", int(collider_prepared.get("transaction_id", -1)))
    _expect(not bool(rejected.get("ok", true)), "real collider manager rejects a staged body with an invalid collision mask")
    _expect(str(rejected.get("error", "")) == "staged_edge_invalid_before_commit", "downstream collider failure is the expected staged-body preflight error")
    var rolled_back: Dictionary = scoped.call("rollback", scoped_id)
    _expect(bool(rolled_back.get("ok", false)), "scoped neighbor transaction rolls back after downstream collider failure")
    await process_frame
    await process_frame
    _expect(staged_ref.get_ref() == null, "failed staged collider body is released")
    _expect(manager.call("get_transition_body", changed_edge_key) == old_body and is_instance_valid(old_body) and old_body.collision_layer == 1 and old_body.collision_mask == 0, "downstream failure preserves the exact old committed collider body")
    _expect(manager.call("get_transition_body", west_edge_key) == west_body, "downstream failure preserves the same Patch opposite-side collider body")
    _expect(manager.call("get_transition_body", unrelated_edge_key) == unrelated_body, "downstream failure preserves the distant exact collider body")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "downstream failure restores the exact old neighbor Node")
    _expect(fixture["b"].call("get_bound_neighbor_patch", "west") == fixture["a"], "downstream failure restores the reciprocal old neighbor Node")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == null, "downstream failure clears the replacement neighbor binding")
    _expect(bool(fixture["a"].call("is_shared_transition_active", "east")), "downstream failure restores the old first Patch transition flag")
    _expect(bool(fixture["b"].call("is_shared_transition_active", "west")), "downstream failure restores the old reciprocal Patch transition flag")
    _expect(not bool(fixture["b_replacement"].call("is_shared_transition_active", "west")), "downstream failure clears the replacement Patch transition flag")
    _expect(bool(fixture["a"].call("is_shared_transition_active", "west")), "downstream failure preserves the unaffected opposite-side transition flag")
    await _release_fixture(fixture)


func _test_stale_old_snapshot_is_rejected_before_mutation() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    var transaction = ScopedTransactionScript.new()
    var prepared: Dictionary = _prepare_replacement(transaction, fixture, ["patch/b"])
    _expect(bool(prepared.get("ok", false)), "old-snapshot fixture prepares")
    if not bool(prepared.get("ok", false)):
        await _release_fixture(fixture)
        return
    fixture["a"].call("apply_world_object_state", {
        "height_level": 2,
        "surface_type": "soil",
        "revision": 3
    })
    var rejected: Dictionary = transaction.apply(int(prepared.get("transaction_id", -1)))
    _expect(not bool(rejected.get("ok", true)), "apply rejects an old Patch changed after Prepare")
    _expect(str(rejected.get("error", "")) == "stale_patch_snapshot", "old Patch mutation reports stale snapshot")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "stale old-snapshot rejection preserves the old neighbor Node")
    _expect(fixture["b"].call("get_bound_neighbor_patch", "west") == fixture["a"], "stale old-snapshot rejection preserves reciprocal binding")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == null, "stale old-snapshot rejection leaves replacement unbound")
    _expect(not transaction.has_pending_transaction(), "stale old-snapshot rejection releases pending transaction state")
    await _release_fixture(fixture)


func _test_stale_candidate_snapshot_is_rejected_before_mutation() -> void:
    var fixture: Dictionary = await _make_fixture(false)
    if fixture.is_empty():
        return
    var transaction = ScopedTransactionScript.new()
    var prepared: Dictionary = _prepare_replacement(transaction, fixture, ["patch/b"])
    _expect(bool(prepared.get("ok", false)), "candidate-snapshot fixture prepares")
    if not bool(prepared.get("ok", false)):
        await _release_fixture(fixture)
        return
    fixture["b_replacement"].call("apply_world_object_state", {
        "height_level": 1,
        "surface_type": "soil",
        "revision": 2
    })
    var rejected: Dictionary = transaction.apply(int(prepared.get("transaction_id", -1)))
    _expect(not bool(rejected.get("ok", true)), "apply rejects a replacement Patch changed after Prepare")
    _expect(str(rejected.get("error", "")) == "stale_patch_snapshot", "candidate Patch mutation reports stale snapshot")
    _expect(fixture["a"].call("get_bound_neighbor_patch", "east") == fixture["b"], "stale candidate-snapshot rejection preserves the old neighbor Node")
    _expect(fixture["b_replacement"].call("get_bound_neighbor_patch", "west") == null, "stale candidate-snapshot rejection leaves replacement unbound")
    _expect(not transaction.has_pending_transaction(), "stale candidate-snapshot rejection releases pending transaction state")
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
    _expect(str(rejected.get("error", "")) == "descriptor_outside_changed_edge_set", "under-seeded projection identifies the omitted old/new descriptor key")
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
    var e: Node3D = _new_patch(holder, "E", Vector3(-patch_size, 0.0, 0.0), 0)
    await process_frame
    await physics_frame

    var old_patches: Array[Node3D] = [a, b, c, d, e]
    var old_instance_ids: Dictionary = {
        a.get_instance_id(): "patch/a",
        b.get_instance_id(): "patch/b",
        c.get_instance_id(): "patch/c",
        d.get_instance_id(): "patch/d",
        e.get_instance_id(): "patch/e"
    }
    var old_report: Dictionary = BinderScript.build_candidate_descriptors(old_patches, old_instance_ids)
    _expect(bool(old_report.get("ok", false)), "old production Patch set produces candidate descriptors")
    var old_bind: Dictionary = BinderScript.bind_patches(old_patches, old_instance_ids)
    _expect(bool(old_bind.get("ok", false)), "old production Patch set binds reciprocal neighbor state")

    var b_replacement: Node3D = _new_patch(holder, "BReplacement", Vector3(patch_size, 0.0, 0.0), 0)
    var d_replacement: Node3D = _new_patch(holder, "DReplacement", Vector3(20.0 + patch_size, 0.0, 0.0), 0)
    await process_frame
    await physics_frame

    var candidate_patches: Array[Node3D] = [a, b_replacement, c, d, e]
    if replace_two_pairs:
        candidate_patches = [a, b_replacement, c, d_replacement, e]
    var d_candidate: Node3D = d_replacement if replace_two_pairs else d
    var candidate_instance_ids: Dictionary = {
        a.get_instance_id(): "patch/a",
        b_replacement.get_instance_id(): "patch/b",
        c.get_instance_id(): "patch/c",
        d_candidate.get_instance_id(): "patch/d",
        e.get_instance_id(): "patch/e"
    }
    var candidate_report: Dictionary = BinderScript.build_candidate_descriptors(candidate_patches, candidate_instance_ids)
    _expect(bool(candidate_report.get("ok", false)), "candidate production Patch set produces descriptors")

    for patch in [a, b, c, d, e, b_replacement, d_replacement]:
        patch.call("set_collision_segmentation_refresh_counter_enabled", true)
        patch.call("set_collision_segmentation_refresh_counter_enabled", false)
        patch.call("set_collision_segmentation_refresh_counter_enabled", true)

    var old_map: Dictionary = {
        "patch/a": a,
        "patch/b": b,
        "patch/c": c,
        "patch/d": d,
        "patch/e": e
    }
    var candidate_map: Dictionary = {
        "patch/a": a,
        "patch/b": b_replacement,
        "patch/c": c,
        "patch/d": d_replacement if replace_two_pairs else d,
        "patch/e": e
    }
    return {
        "holder": holder,
        "a": a,
        "b": b,
        "c": c,
        "d": d,
        "e": e,
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
    for patch in [fixture["a"], fixture["b"], fixture["c"], fixture["d"], fixture["e"], fixture["b_replacement"], fixture["d_replacement"]]:
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
