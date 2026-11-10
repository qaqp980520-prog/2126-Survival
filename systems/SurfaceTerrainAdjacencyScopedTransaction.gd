extends RefCounted
class_name SurfaceTerrainAdjacencyScopedTransaction

## Coordinates a reversible, patch-local neighbor-state update with the collider manager.
## The caller prepares the collider transaction first, then prepares/applies this transaction,
## commits the collider transaction, and finally calls finalize(). If collider commit fails,
## rollback() restores the exact previously committed neighbor links and transition flags.
const VALID_SIDES: Array[String] = ["east", "west", "north", "south"]

var _next_transaction_id: int = 1
var _pending: Dictionary = {}


## old_descriptors and candidate_descriptors must be the scoped projections from one
## SurfaceTerrainAdjacencyIndex.plan_delta() summary, not the complete world maps.
## changed_edge_keys must equal the union of their keys (including unchanged descriptors
## whose Stable ID now resolves to a replacement Node instance).
func prepare(
    old_descriptors: Dictionary,
    candidate_descriptors: Dictionary,
    old_patches_by_stable_id: Dictionary,
    candidate_patches_by_stable_id: Dictionary,
    changed_edge_keys: Array
) -> Dictionary:
    if not _pending.is_empty():
        return {"ok": false, "error": "transaction_in_progress"}

    var changed_set: Dictionary = {}
    for edge_key_value in changed_edge_keys:
        if not (edge_key_value is String) or str(edge_key_value).is_empty():
            return {"ok": false, "error": "invalid_changed_edge_key"}
        var edge_key: String = edge_key_value
        if changed_set.has(edge_key):
            return {"ok": false, "error": "duplicate_changed_edge_key", "key": edge_key}
        changed_set[edge_key] = true

    var expected_set: Dictionary = {}
    for descriptor_source in [old_descriptors, candidate_descriptors]:
        for edge_key_value in descriptor_source.keys():
            if not (edge_key_value is String) or str(edge_key_value).is_empty():
                return {"ok": false, "error": "invalid_scoped_descriptor_key"}
            var edge_key: String = edge_key_value
            expected_set[edge_key] = true
            if not changed_set.has(edge_key):
                return {"ok": false, "error": "descriptor_outside_changed_edge_set", "key": edge_key}

    if expected_set.size() != changed_set.size():
        return {"ok": false, "error": "changed_edge_key_mismatch"}
    if expected_set.is_empty():
        return {"ok": true, "noop": true, "transaction_id": 0}

    var old_result: Dictionary = _build_pairs(old_descriptors, old_patches_by_stable_id, "old")
    if not bool(old_result.get("ok", false)):
        return old_result
    var candidate_result: Dictionary = _build_pairs(candidate_descriptors, candidate_patches_by_stable_id, "candidate")
    if not bool(candidate_result.get("ok", false)):
        return candidate_result

    var endpoint_keys: Dictionary = {}
    for endpoint_key in old_result.get("endpoint_records", {}).keys():
        endpoint_keys[str(endpoint_key)] = true
    for endpoint_key in candidate_result.get("endpoint_records", {}).keys():
        endpoint_keys[str(endpoint_key)] = true

    var snapshots: Array[Dictionary] = []
    var snapshot_keys: Dictionary = {}
    var scope_patches: Array[Node3D] = []
    var scope_patch_ids: Dictionary = {}
    _append_unique_patches(old_result.get("patches", []), scope_patches, scope_patch_ids)
    _append_unique_patches(candidate_result.get("patches", []), scope_patches, scope_patch_ids)

    for endpoint_key_value in endpoint_keys.keys():
        var endpoint_key: String = str(endpoint_key_value)
        var endpoint_record: Dictionary = old_result.get("endpoint_records", {}).get(
            endpoint_key,
            candidate_result.get("endpoint_records", {}).get(endpoint_key, {})
        )
        var stable_id: String = str(endpoint_record.get("stable_id", ""))
        var side: String = str(endpoint_record.get("side", ""))
        var old_patch: Node3D = old_patches_by_stable_id.get(stable_id) as Node3D
        var candidate_patch: Node3D = candidate_patches_by_stable_id.get(stable_id) as Node3D
        var expected_old_neighbor_id: String = str(old_result.get("endpoint_neighbors", {}).get(endpoint_key, ""))

        if is_instance_valid(old_patch):
            var old_patch_check: Dictionary = _validate_patch(old_patch)
            if not bool(old_patch_check.get("ok", false)):
                return old_patch_check
            var actual_old_neighbor: Node3D = old_patch.call("get_bound_neighbor_patch", side) as Node3D
            if expected_old_neighbor_id.is_empty():
                if is_instance_valid(actual_old_neighbor):
                    return {"ok": false, "error": "old_live_neighbor_outside_scoped_descriptor", "stable_id": stable_id, "side": side}
                if bool(old_patch.call("is_shared_transition_active", side)):
                    return {"ok": false, "error": "old_shared_transition_without_neighbor", "stable_id": stable_id, "side": side}
            else:
                var expected_old_neighbor: Node3D = old_patches_by_stable_id.get(expected_old_neighbor_id) as Node3D
                if not is_instance_valid(expected_old_neighbor) or actual_old_neighbor != expected_old_neighbor:
                    return {"ok": false, "error": "old_neighbor_snapshot_mismatch", "stable_id": stable_id, "side": side}
                var reciprocal_side: String = _opposite_side(side)
                if expected_old_neighbor.call("get_bound_neighbor_patch", reciprocal_side) != old_patch:
                    return {"ok": false, "error": "old_neighbor_not_reciprocal", "stable_id": stable_id, "side": side}

            var snapshot_key: String = "%d:%s" % [old_patch.get_instance_id(), side]
            if not snapshot_keys.has(snapshot_key):
                snapshot_keys[snapshot_key] = true
                snapshots.append({
                    "patch": old_patch,
                    "side": side,
                    "neighbor": actual_old_neighbor,
                    "shared_active": bool(old_patch.call("is_shared_transition_active", side))
                })
        elif old_result.get("endpoint_records", {}).has(endpoint_key):
            return {"ok": false, "error": "missing_old_endpoint_patch", "stable_id": stable_id}

        if is_instance_valid(candidate_patch):
            var candidate_patch_check: Dictionary = _validate_patch(candidate_patch)
            if not bool(candidate_patch_check.get("ok", false)):
                return candidate_patch_check
            if candidate_patch != old_patch:
                var candidate_neighbor: Node3D = candidate_patch.call("get_bound_neighbor_patch", side) as Node3D
                if is_instance_valid(candidate_neighbor) or bool(candidate_patch.call("is_shared_transition_active", side)):
                    return {"ok": false, "error": "replacement_candidate_endpoint_not_clean", "stable_id": stable_id, "side": side}
        elif candidate_result.get("endpoint_records", {}).has(endpoint_key):
            return {"ok": false, "error": "missing_candidate_endpoint_patch", "stable_id": stable_id}

    var transaction_id: int = _next_transaction_id
    _next_transaction_id += 1
    _pending = {
        "transaction_id": transaction_id,
        "old_pairs": old_result.get("pairs", []),
        "candidate_pairs": candidate_result.get("pairs", []),
        "snapshots": snapshots,
        "scope_patches": scope_patches,
        "batch_patches": [],
        "applied": false
    }
    return {
        "ok": true,
        "noop": false,
        "transaction_id": transaction_id,
        "changed_edge_count": changed_set.size(),
        "old_pair_count": old_result.get("pairs", []).size(),
        "candidate_pair_count": candidate_result.get("pairs", []).size(),
        "affected_patch_count": scope_patches.size()
    }


## Applies only the prepared edge endpoints and leaves segmentation batches open so the
## caller can commit the collider manager before publishing the final patch segmentation.
func apply(transaction_id: int) -> Dictionary:
    if _pending.is_empty():
        return {"ok": false, "error": "no_pending_transaction"}
    if int(_pending.get("transaction_id", -1)) != transaction_id:
        return {"ok": false, "error": "invalid_transaction_id"}
    if bool(_pending.get("applied", false)):
        return {"ok": false, "error": "transaction_already_applied"}

    var batch_patches: Array[Node3D] = _pending.get("scope_patches", [])
    for patch in batch_patches:
        if not is_instance_valid(patch):
            return _discard_unapplied("invalid_patch_before_batch")
        patch.call("begin_collision_segmentation_batch")
    _pending["batch_patches"] = batch_patches
    _pending["applied"] = true

    for pair_value in _pending.get("old_pairs", []):
        var pair: Dictionary = pair_value
        var first_patch: Node3D = pair.get("first_patch") as Node3D
        if not is_instance_valid(first_patch) or not bool(first_patch.call("clear_neighbor_edge_state", str(pair.get("first_side", "")))):
            return _restore_and_discard("old_edge_clear_failed")
    for pair_value in _pending.get("candidate_pairs", []):
        var pair: Dictionary = pair_value
        var first_patch: Node3D = pair.get("first_patch") as Node3D
        var second_patch: Node3D = pair.get("second_patch") as Node3D
        var first_side: String = str(pair.get("first_side", ""))
        var second_side: String = str(pair.get("second_side", ""))
        if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
            return _restore_and_discard("candidate_patch_invalid_during_apply")
        if not bool(first_patch.call("bind_neighbor_patch", first_side, second_patch)):
            return _restore_and_discard("candidate_first_bind_failed")
        if not bool(second_patch.call("bind_neighbor_patch", second_side, first_patch)):
            return _restore_and_discard("candidate_reciprocal_bind_failed")

    return {
        "ok": true,
        "applied": true,
        "transaction_id": transaction_id,
        "changed_edge_count": _pending.get("old_pairs", []).size() + _pending.get("candidate_pairs", []).size()
    }


## Finalizes after the collider manager has committed. This flushes each affected Patch's
## deferred segmentation at most once and releases the temporary strong Node references.
func finalize(transaction_id: int) -> Dictionary:
    if _pending.is_empty():
        return {"ok": false, "error": "no_pending_transaction"}
    if int(_pending.get("transaction_id", -1)) != transaction_id:
        return {"ok": false, "error": "invalid_transaction_id"}
    if not bool(_pending.get("applied", false)):
        return {"ok": false, "error": "transaction_not_applied"}
    var ended: bool = _end_batches(_pending.get("batch_patches", []))
    if not ended:
        return {"ok": false, "error": "segmentation_batch_end_failed"}
    _pending.clear()
    return {"ok": true, "finalized": true, "transaction_id": transaction_id}


## Restores the exact old neighbor pairs and shared-transition flags after a downstream
## collider commit failure. The transaction remains fail-closed if restoration itself fails.
func rollback(transaction_id: int) -> Dictionary:
    if _pending.is_empty():
        return {"ok": false, "error": "no_pending_transaction"}
    if int(_pending.get("transaction_id", -1)) != transaction_id:
        return {"ok": false, "error": "invalid_transaction_id"}
    if not bool(_pending.get("applied", false)):
        _pending.clear()
        return {"ok": true, "rolled_back": true, "transaction_id": transaction_id, "noop": true}
    var restored: bool = _restore_old_state()
    var ended: bool = _end_batches(_pending.get("batch_patches", []))
    if not restored or not ended:
        return {"ok": false, "error": "rollback_failed", "restored": restored, "batches_ended": ended}
    _pending.clear()
    return {"ok": true, "rolled_back": true, "transaction_id": transaction_id}


func abort(transaction_id: int) -> Dictionary:
    if _pending.is_empty():
        return {"ok": false, "error": "no_pending_transaction"}
    if int(_pending.get("transaction_id", -1)) != transaction_id:
        return {"ok": false, "error": "invalid_transaction_id"}
    if bool(_pending.get("applied", false)):
        return rollback(transaction_id)
    _pending.clear()
    return {"ok": true, "aborted": true, "transaction_id": transaction_id}


func has_pending_transaction() -> bool:
    return not _pending.is_empty()


func _build_pairs(descriptors: Dictionary, patches_by_stable_id: Dictionary, label: String) -> Dictionary:
    var pairs: Array[Dictionary] = []
    var endpoint_neighbors: Dictionary = {}
    var endpoint_records: Dictionary = {}
    var patches: Array[Node3D] = []
    var patch_ids: Dictionary = {}
    var edge_keys: Array[String] = []
    for edge_key_value in descriptors.keys():
        if not (edge_key_value is String) or str(edge_key_value).is_empty():
            return {"ok": false, "error": "invalid_" + label + "_edge_key"}
        edge_keys.append(str(edge_key_value))
    edge_keys.sort()

    for edge_key in edge_keys:
        var descriptor_value: Variant = descriptors[edge_key]
        if not (descriptor_value is Dictionary):
            return {"ok": false, "error": "invalid_" + label + "_descriptor", "key": edge_key}
        var descriptor: Dictionary = descriptor_value
        var first_id_value: Variant = descriptor.get("first_stable_id", null)
        var second_id_value: Variant = descriptor.get("second_stable_id", null)
        var first_side_value: Variant = descriptor.get("first_side", null)
        var second_side_value: Variant = descriptor.get("second_side", null)
        if not (first_id_value is String) or not (second_id_value is String):
            return {"ok": false, "error": "invalid_" + label + "_stable_ids", "key": edge_key}
        if not (first_side_value is String) or not (second_side_value is String):
            return {"ok": false, "error": "invalid_" + label + "_sides", "key": edge_key}
        var first_id: String = first_id_value
        var second_id: String = second_id_value
        var first_side: String = first_side_value
        var second_side: String = second_side_value
        if first_id.is_empty() or second_id.is_empty() or first_id >= second_id:
            return {"ok": false, "error": "noncanonical_" + label + "_stable_ids", "key": edge_key}
        if not VALID_SIDES.has(first_side) or _opposite_side(first_side) != second_side:
            return {"ok": false, "error": "invalid_" + label + "_sides", "key": edge_key}
        if str(descriptor.get("edge_key", "")) != edge_key:
            return {"ok": false, "error": "mismatched_" + label + "_edge_key", "key": edge_key}

        var first_patch: Node3D = patches_by_stable_id.get(first_id) as Node3D
        var second_patch: Node3D = patches_by_stable_id.get(second_id) as Node3D
        if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
            return {"ok": false, "error": "missing_" + label + "_patch", "key": edge_key}
        var first_check: Dictionary = _validate_patch(first_patch)
        var second_check: Dictionary = _validate_patch(second_patch)
        if not bool(first_check.get("ok", false)):
            return first_check
        if not bool(second_check.get("ok", false)):
            return second_check

        var first_endpoint: String = _endpoint_key(first_id, first_side)
        var second_endpoint: String = _endpoint_key(second_id, second_side)
        if endpoint_neighbors.has(first_endpoint) or endpoint_neighbors.has(second_endpoint):
            return {"ok": false, "error": "duplicate_" + label + "_endpoint", "key": edge_key}
        endpoint_neighbors[first_endpoint] = second_id
        endpoint_neighbors[second_endpoint] = first_id
        endpoint_records[first_endpoint] = {"stable_id": first_id, "side": first_side, "patch": first_patch}
        endpoint_records[second_endpoint] = {"stable_id": second_id, "side": second_side, "patch": second_patch}
        pairs.append({
            "edge_key": edge_key,
            "first_id": first_id,
            "second_id": second_id,
            "first_side": first_side,
            "second_side": second_side,
            "first_patch": first_patch,
            "second_patch": second_patch
        })
        _append_unique_patch(first_patch, patches, patch_ids)
        _append_unique_patch(second_patch, patches, patch_ids)

    return {
        "ok": true,
        "pairs": pairs,
        "endpoint_neighbors": endpoint_neighbors,
        "endpoint_records": endpoint_records,
        "patches": patches
    }


func _validate_patch(patch: Node3D) -> Dictionary:
    if not is_instance_valid(patch) or not patch.is_inside_tree() or patch.is_queued_for_deletion():
        return {"ok": false, "error": "invalid_patch"}
    for method_name in [
        "get_bound_neighbor_patch",
        "bind_neighbor_patch",
        "clear_neighbor_edge_state",
        "is_shared_transition_active",
        "set_shared_transition_active",
        "begin_collision_segmentation_batch",
        "end_collision_segmentation_batch"
    ]:
        if not patch.has_method(method_name):
            return {"ok": false, "error": "patch_missing_" + method_name}
    return {"ok": true}


func _append_unique_patches(source: Array, target: Array[Node3D], seen: Dictionary) -> void:
    for patch_value in source:
        _append_unique_patch(patch_value as Node3D, target, seen)


func _append_unique_patch(patch: Node3D, target: Array[Node3D], seen: Dictionary) -> void:
    if not is_instance_valid(patch):
        return
    var instance_id: int = patch.get_instance_id()
    if seen.has(instance_id):
        return
    seen[instance_id] = true
    target.append(patch)


func _endpoint_key(stable_id: String, side: String) -> String:
    return stable_id + "|" + side


func _opposite_side(side: String) -> String:
    match side:
        "east": return "west"
        "west": return "east"
        "north": return "south"
        "south": return "north"
        _: return ""


func _restore_old_state() -> bool:
    var all_ok: bool = true
    for pair_value in _pending.get("candidate_pairs", []):
        var pair: Dictionary = pair_value
        var first_patch: Node3D = pair.get("first_patch") as Node3D
        if is_instance_valid(first_patch):
            if not bool(first_patch.call("clear_neighbor_edge_state", str(pair.get("first_side", "")))):
                all_ok = false
    for pair_value in _pending.get("old_pairs", []):
        var pair: Dictionary = pair_value
        var first_patch: Node3D = pair.get("first_patch") as Node3D
        if is_instance_valid(first_patch):
            if not bool(first_patch.call("clear_neighbor_edge_state", str(pair.get("first_side", "")))):
                all_ok = false
    for pair_value in _pending.get("old_pairs", []):
        var pair: Dictionary = pair_value
        var first_patch: Node3D = pair.get("first_patch") as Node3D
        var second_patch: Node3D = pair.get("second_patch") as Node3D
        if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
            all_ok = false
            continue
        if not bool(first_patch.call("bind_neighbor_patch", str(pair.get("first_side", "")), second_patch)):
            all_ok = false
            continue
        if not bool(second_patch.call("bind_neighbor_patch", str(pair.get("second_side", "")), first_patch)):
            all_ok = false

    for snapshot_value in _pending.get("snapshots", []):
        var snapshot: Dictionary = snapshot_value
        var patch: Node3D = snapshot.get("patch") as Node3D
        if not is_instance_valid(patch):
            all_ok = false
            continue
        if not bool(patch.call("set_shared_transition_active", str(snapshot.get("side", "")), bool(snapshot.get("shared_active", false)))):
            all_ok = false
    return all_ok


func _restore_and_discard(error_code: String) -> Dictionary:
    var restored: bool = _restore_old_state()
    var ended: bool = _end_batches(_pending.get("batch_patches", []))
    var transaction_id: int = int(_pending.get("transaction_id", -1))
    _pending.clear()
    return {
        "ok": false,
        "error": error_code if restored and ended else "apply_failed_and_rollback_failed",
        "rollback_restored": restored,
        "batches_ended": ended,
        "transaction_id": transaction_id
    }


func _discard_unapplied(error_code: String) -> Dictionary:
    _pending.clear()
    return {"ok": false, "error": error_code}


func _end_batches(batch_patches: Array) -> bool:
    var all_ok: bool = true
    for index in range(batch_patches.size() - 1, -1, -1):
        var patch: Node3D = batch_patches[index] as Node3D
        if not is_instance_valid(patch) or not bool(patch.call("end_collision_segmentation_batch")):
            all_ok = false
    return all_ok
