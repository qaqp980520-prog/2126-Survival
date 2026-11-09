extends Node3D
class_name SurfaceTerrainTransitionColliderManager

## Owns shared edge ramps and eligible four-patch corner caps.
## Every edge/cap is staged with collision disabled; patch segmentation is committed only after preflight succeeds.
const COLLISION_LAYER: int = 1
const COLLISION_THICKNESS: float = 0.04
const EDGE_RUN_PER_PATCH: float = 0.75
const PATCH_SIZE: float = 2.0
const POSITION_TOLERANCE: float = 0.01
const VALID_SIDES: Array[String] = ["east", "west", "north", "south"]
const CORNER_NAMES: Array[String] = ["north_east", "south_east", "south_west", "north_west"]
const CornerResolverScript = preload("res://systems/SurfaceTerrainCornerConflictResolver.gd")

var _managed_edges: Dictionary = {}
var _managed_corner_caps: Dictionary = {}
var _last_blocked_corner_reports: Array[Dictionary] = []
var _next_sync_transaction_id: int = 1
var _pending_sync_transaction: Dictionary = {}

func sync_transitions(descriptors: Dictionary, patches_by_stable_id: Dictionary, profile_enabled: bool = false) -> Dictionary:
    var prepared: Dictionary = prepare_sync_transitions(descriptors, patches_by_stable_id, profile_enabled)
    if not bool(prepared.get("ok", false)):
        return prepared
    return commit_sync_transitions(int(prepared.get("transaction_id", -1)))


func prepare_sync_transitions(descriptors: Dictionary, patches_by_stable_id: Dictionary, profile_enabled: bool = false) -> Dictionary:
    if not _pending_sync_transaction.is_empty():
        return {"ok": false, "error": "transaction_in_progress", "active_count": _managed_edges.size()}
    var total_started_usec: int = Time.get_ticks_usec() if profile_enabled else 0
    var candidate_started_usec: int = Time.get_ticks_usec() if profile_enabled else 0
    var candidates: Dictionary = {}
    for edge_key_value in descriptors.keys():
        if not (edge_key_value is String) or str(edge_key_value).is_empty():
            return {"ok": false, "error": "invalid_edge_key", "active_count": _managed_edges.size()}
        var edge_key: String = edge_key_value
        var descriptor_value: Variant = descriptors[edge_key_value]
        if not (descriptor_value is Dictionary):
            return {"ok": false, "error": "invalid_edge_descriptor", "active_count": _managed_edges.size()}
        var descriptor: Dictionary = descriptor_value
        if not bool(descriptor.get("transition_required", false)):
            continue
        var first_id_value: Variant = descriptor.get("first_stable_id", null)
        var second_id_value: Variant = descriptor.get("second_stable_id", null)
        if not (first_id_value is String) or not (second_id_value is String):
            return {"ok": false, "error": "invalid_stable_ids", "active_count": _managed_edges.size()}
        var first_id: String = first_id_value
        var second_id: String = second_id_value
        var first_side_value: Variant = descriptor.get("first_side", null)
        var second_side_value: Variant = descriptor.get("second_side", null)
        if not (first_side_value is String) or not (second_side_value is String):
            return {"ok": false, "error": "invalid_edge_sides", "active_count": _managed_edges.size()}
        var first_side: String = first_side_value
        var second_side: String = second_side_value
        var descriptor_edge_key: Variant = descriptor.get("edge_key", null)
        var owner_stable_id: Variant = descriptor.get("owner_stable_id", null)
        if not (descriptor_edge_key is String) or not (owner_stable_id is String):
            return {"ok": false, "error": "invalid_edge_owner", "active_count": _managed_edges.size()}
        var first_patch: Node3D = patches_by_stable_id.get(first_id) as Node3D
        var second_patch: Node3D = patches_by_stable_id.get(second_id) as Node3D
        if first_id.is_empty() or second_id.is_empty() or first_id == second_id or first_id > second_id:
            return {"ok": false, "error": "invalid_stable_ids", "active_count": _managed_edges.size()}
        if str(descriptor.get("edge_key", "")) != edge_key or str(descriptor.get("owner_stable_id", "")) != first_id:
            return {"ok": false, "error": "invalid_edge_owner", "active_count": _managed_edges.size()}
        if not VALID_SIDES.has(first_side) or not VALID_SIDES.has(second_side) or _opposite_side(first_side) != second_side:
            return {"ok": false, "error": "invalid_edge_sides", "active_count": _managed_edges.size()}
        if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
            return {"ok": false, "error": "missing_live_patch", "active_count": _managed_edges.size()}
        if not first_patch.has_method("set_shared_transition_active") or not second_patch.has_method("set_shared_transition_active"):
            return {"ok": false, "error": "patch_missing_transition_api", "active_count": _managed_edges.size()}
        var geometry: Dictionary = _build_geometry(first_patch, second_patch, descriptor)
        if not bool(geometry.get("ok", false)):
            return {"ok": false, "error": str(geometry.get("error", "invalid_geometry")), "active_count": _managed_edges.size()}
        candidates[edge_key] = {
            "first_id": first_id,
            "second_id": second_id,
            "first_side": first_side,
            "second_side": second_side,
            "first_patch": first_patch,
            "second_patch": second_patch,
            "geometry": geometry
        }

    var candidate_geometry_usec: int = Time.get_ticks_usec() - candidate_started_usec if profile_enabled else 0
    var corner_started_usec: int = Time.get_ticks_usec() if profile_enabled else 0
    var corner_resolution: Dictionary = CornerResolverScript.resolve(candidates)
    if not bool(corner_resolution.get("ok", false)):
        return {"ok": false, "error": str(corner_resolution.get("error", "corner_resolution_failed")), "active_count": _managed_edges.size()}
    var blocked_edges: Dictionary = corner_resolution.get("blocked_edges", {}).duplicate(true)
    var blocked_corner_reports: Array = corner_resolution.get("reports", []).duplicate(true)
    var cap_resolution: Dictionary = _build_corner_cap_specs(candidates, blocked_corner_reports)
    if not bool(cap_resolution.get("ok", false)):
        return {"ok": false, "error": str(cap_resolution.get("error", "corner_cap_resolution_failed")), "active_count": _managed_edges.size()}
    var cap_specs: Array = cap_resolution.get("specs", [])
    var edge_junctions: Dictionary = cap_resolution.get("edge_junctions", {})
    var report_policies: Dictionary = cap_resolution.get("report_policies", {})
    for edge_key in edge_junctions.keys():
        blocked_edges.erase(str(edge_key))
    for report_value in blocked_corner_reports:
        if not (report_value is Dictionary):
            continue
        var report: Dictionary = report_value
        var token: String = _report_token(str(report.get("stable_id", "")), str(report.get("corner", "")))
        if report_policies.has(token):
            var policy: Dictionary = report_policies[token]
            report["policy"] = "shared_corner_cap"
            report["junction_key"] = str(policy.get("junction_key", ""))
            report["midpoint_height"] = float(policy.get("midpoint_height", 0.0))

    var corner_resolution_usec: int = Time.get_ticks_usec() - corner_started_usec if profile_enabled else 0
    var staging_started_usec: int = Time.get_ticks_usec() if profile_enabled else 0
    var staged_caps: Dictionary = {}
    var reused_cap_keys: Dictionary = {}
    var staged_cap_count: int = 0
    for cap_spec_value in cap_specs:
        if not (cap_spec_value is Dictionary):
            _free_staged_caps(staged_caps, reused_cap_keys)
            return {"ok": false, "error": "invalid_corner_cap_spec", "active_count": _managed_edges.size()}
        var cap_spec: Dictionary = cap_spec_value
        for corner_value in cap_spec.get("corners", []):
            if not (corner_value is Dictionary):
                _free_staged_caps(staged_caps, reused_cap_keys)
                return {"ok": false, "error": "invalid_corner_cap_entry", "active_count": _managed_edges.size()}
            var corner_entry: Dictionary = corner_value
            var stable_id: String = str(corner_entry.get("stable_id", ""))
            var corner: String = str(corner_entry.get("corner", ""))
            var cap_key: String = _report_token(stable_id, corner)
            var cap_signature: Array = _corner_cap_reuse_signature(cap_spec, corner_entry)
            var old_cap: Dictionary = _managed_corner_caps.get(cap_key, {})
            var old_cap_body: StaticBody3D = old_cap.get("body") as StaticBody3D
            if not cap_signature.is_empty() and _signatures_match(old_cap.get("reuse_signature", []), cap_signature) and _is_reusable_managed_body(old_cap_body):
                staged_caps[cap_key] = old_cap
                reused_cap_keys[cap_key] = true
                continue
            var staged_cap: Dictionary = _stage_corner_cap(cap_key, cap_spec, corner_entry, cap_signature)
            if staged_cap.is_empty():
                _free_staged_caps(staged_caps, reused_cap_keys)
                return {"ok": false, "error": "corner_cap_staging_failed", "active_count": _managed_edges.size()}
            staged_caps[cap_key] = staged_cap
            staged_cap_count += 1

    var staged: Dictionary = {}
    var reused_edge_keys: Dictionary = {}
    var reactivated_edge_keys: Dictionary = {}
    var staged_edge_count: int = 0
    for edge_key in candidates.keys():
        if blocked_edges.has(edge_key):
            continue
        var edge: Dictionary = candidates[edge_key]
        var junction_positions: Array = edge_junctions.get(str(edge_key), [])
        var edge_signature: Array = _edge_reuse_signature(str(edge_key), edge, junction_positions)
        var old_edge: Dictionary = _managed_edges.get(str(edge_key), {})
        var old_edge_body: StaticBody3D = old_edge.get("body") as StaticBody3D
        if not edge_signature.is_empty() and _signatures_match(old_edge.get("reuse_signature", []), edge_signature) and _is_reusable_managed_body(old_edge_body):
            staged[str(edge_key)] = old_edge
            reused_edge_keys[str(edge_key)] = true
            if not _edge_patch_states_are_active(old_edge):
                reactivated_edge_keys[str(edge_key)] = true
            continue
        var staged_edge: Dictionary = _stage_edge(str(edge_key), edge, junction_positions, edge_signature)
        if staged_edge.is_empty():
            _free_staged(staged, reused_edge_keys)
            _free_staged_caps(staged_caps, reused_cap_keys)
            return {"ok": false, "error": "edge_staging_failed", "active_count": _managed_edges.size()}
        staged[str(edge_key)] = staged_edge
        staged_edge_count += 1

    var resource_staging_usec: int = Time.get_ticks_usec() - staging_started_usec if profile_enabled else 0
    var patch_snapshot_result: Dictionary = _capture_patch_snapshots(candidates)
    if not bool(patch_snapshot_result.get("ok", false)):
        _free_staged(staged, reused_edge_keys)
        _free_staged_caps(staged_caps, reused_cap_keys)
        return {"ok": false, "error": str(patch_snapshot_result.get("error", "patch_snapshot_failed")), "active_count": _managed_edges.size()}

    var transaction_id: int = _next_sync_transaction_id
    _next_sync_transaction_id += 1
    _pending_sync_transaction = {
        "transaction_id": transaction_id,
        "staged_edges": staged,
        "staged_caps": staged_caps,
        "reused_edge_keys": reused_edge_keys,
        "reused_cap_keys": reused_cap_keys,
        "reactivated_edge_keys": reactivated_edge_keys,
        "blocked_edges": blocked_edges,
        "blocked_corner_reports": blocked_corner_reports,
        "patch_snapshots": patch_snapshot_result.get("snapshots", {}),
        "old_edges_snapshot": _managed_edges.duplicate(),
        "old_caps_snapshot": _managed_corner_caps.duplicate(),
        "candidate_geometry_usec": candidate_geometry_usec,
        "corner_resolution_usec": corner_resolution_usec,
        "resource_staging_usec": resource_staging_usec,
        "total_started_usec": total_started_usec,
        "profile_enabled": profile_enabled,
        "staged_edge_count": staged_edge_count,
        "staged_cap_count": staged_cap_count
    }
    return {
        "ok": true,
        "transaction_id": transaction_id,
        "active_count": _managed_edges.size(),
        "pending_staged_edge_count": staged_edge_count,
        "pending_reused_edge_count": reused_edge_keys.size(),
        "pending_staged_corner_cap_count": staged_cap_count,
        "pending_reused_corner_cap_count": reused_cap_keys.size(),
        "blocked_count": blocked_edges.size()
    }


func commit_sync_transitions(transaction_id: int) -> Dictionary:
    if _pending_sync_transaction.is_empty():
        return {"ok": false, "error": "no_pending_transaction", "active_count": _managed_edges.size()}
    if int(_pending_sync_transaction.get("transaction_id", -1)) != transaction_id:
        return {"ok": false, "error": "invalid_transaction_id", "active_count": _managed_edges.size()}

    var pending: Dictionary = _pending_sync_transaction
    var staged: Dictionary = pending.get("staged_edges", {})
    var staged_caps: Dictionary = pending.get("staged_caps", {})
    var reused_edge_keys: Dictionary = pending.get("reused_edge_keys", {})
    var reused_cap_keys: Dictionary = pending.get("reused_cap_keys", {})
    var reactivated_edge_keys: Dictionary = pending.get("reactivated_edge_keys", {})
    var patch_snapshots: Dictionary = pending.get("patch_snapshots", {})
    if (
        not _managed_map_matches_snapshot(_managed_edges, pending.get("old_edges_snapshot", {}), "edge")
        or not _managed_map_matches_snapshot(_managed_corner_caps, pending.get("old_caps_snapshot", {}), "corner_cap")
        or not _patch_snapshots_match(patch_snapshots)
    ):
        _abort_pending_transaction()
        return {"ok": false, "error": "stale_transaction_snapshot", "active_count": _managed_edges.size()}

    var commit_started_usec: int = Time.get_ticks_usec()
    for edge_key in staged.keys():
        if reused_edge_keys.has(str(edge_key)) and not reactivated_edge_keys.has(str(edge_key)):
            continue
        var edge: Dictionary = staged[edge_key]
        var first_patch: Node3D = edge.get("first_patch") as Node3D
        var second_patch: Node3D = edge.get("second_patch") as Node3D
        var first_side: String = str(edge.get("first_side", ""))
        var second_side: String = str(edge.get("second_side", ""))
        if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
            var rollback_after_missing_patch: bool = _restore_patch_snapshots(patch_snapshots)
            _abort_pending_transaction()
            return {
                "ok": false,
                "error": "missing_patch_during_commit",
                "rollback_ok": rollback_after_missing_patch,
                "active_count": _managed_edges.size()
            }
        var first_activated: bool = bool(first_patch.call("set_shared_transition_active", first_side, true))
        if not first_activated:
            var rollback_first: bool = _restore_patch_snapshots(patch_snapshots)
            _abort_pending_transaction()
            return {
                "ok": false,
                "error": "first_patch_activation_failed",
                "rollback_ok": rollback_first,
                "active_count": _managed_edges.size()
            }
        var second_activated: bool = bool(second_patch.call("set_shared_transition_active", second_side, true))
        if not second_activated:
            var rollback_second: bool = _restore_patch_snapshots(patch_snapshots)
            _abort_pending_transaction()
            return {
                "ok": false,
                "error": "second_patch_activation_failed",
                "rollback_ok": rollback_second,
                "active_count": _managed_edges.size()
            }

    # Publish new collision bodies before retiring the old set. All replacements
    # were staged with collision disabled, so abort never exposes partial geometry.
    for edge in staged.values():
        var body: StaticBody3D = edge.get("body") as StaticBody3D
        if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != self:
            var rollback_staged_edge: bool = _restore_patch_snapshots(patch_snapshots)
            _abort_pending_transaction()
            return {
                "ok": false,
                "error": "staged_edge_invalid_during_commit",
                "rollback_ok": rollback_staged_edge,
                "active_count": _managed_edges.size()
            }
        body.collision_layer = COLLISION_LAYER
    for cap in staged_caps.values():
        var cap_body: StaticBody3D = cap.get("body") as StaticBody3D
        if not is_instance_valid(cap_body) or cap_body.is_queued_for_deletion() or cap_body.get_parent() != self:
            var rollback_staged_cap: bool = _restore_patch_snapshots(patch_snapshots)
            _abort_pending_transaction()
            return {
                "ok": false,
                "error": "staged_corner_cap_invalid_during_commit",
                "rollback_ok": rollback_staged_cap,
                "active_count": _managed_edges.size()
            }
        cap_body.collision_layer = COLLISION_LAYER

    var retired_edge_count: int = 0
    for old_key in _managed_edges.keys():
        var old_edge: Dictionary = _managed_edges[old_key]
        var replacement_edge: Dictionary = staged.get(str(old_key), {})
        if replacement_edge.get("body") == old_edge.get("body"):
            continue
        retired_edge_count += 1
        _retire_old_edge(old_edge, replacement_edge)

    var retired_corner_cap_count: int = 0
    for old_cap_key in _managed_corner_caps.keys():
        var old_cap: Dictionary = _managed_corner_caps[old_cap_key]
        var replacement_cap: Dictionary = staged_caps.get(str(old_cap_key), {})
        if replacement_cap.get("body") == old_cap.get("body"):
            continue
        retired_corner_cap_count += 1
        _retire_old_cap(old_cap)

    _managed_edges = staged
    _managed_corner_caps = staged_caps
    _last_blocked_corner_reports.clear()
    for report_value in pending.get("blocked_corner_reports", []):
        if report_value is Dictionary:
            _last_blocked_corner_reports.append(report_value.duplicate(true))

    var profile_usec: Dictionary = {}
    if bool(pending.get("profile_enabled", false)):
        profile_usec = {
            "candidate_geometry_usec": int(pending.get("candidate_geometry_usec", 0)),
            "corner_resolution_usec": int(pending.get("corner_resolution_usec", 0)),
            "resource_staging_usec": int(pending.get("resource_staging_usec", 0)),
            "activation_commit_usec": Time.get_ticks_usec() - commit_started_usec,
            "reused_edge_count": reused_edge_keys.size(),
            "reactivated_edge_count": reactivated_edge_keys.size(),
            "staged_edge_count": int(pending.get("staged_edge_count", 0)),
            "retired_edge_count": retired_edge_count,
            "reused_corner_cap_count": reused_cap_keys.size(),
            "staged_corner_cap_count": int(pending.get("staged_cap_count", 0)),
            "retired_corner_cap_count": retired_corner_cap_count,
            "total_usec": Time.get_ticks_usec() - int(pending.get("total_started_usec", commit_started_usec))
        }

    var blocked_edges: Dictionary = pending.get("blocked_edges", {})
    var result: Dictionary = {
        "ok": true,
        "transaction_id": transaction_id,
        "active_count": _managed_edges.size(),
        "blocked_count": blocked_edges.size(),
        "blocked_edge_keys": _sorted_keys(blocked_edges),
        "blocked_corner_reports": _last_blocked_corner_reports.duplicate(true),
        "corner_cap_count": _managed_corner_caps.size(),
        "reused_edge_count": reused_edge_keys.size(),
        "reactivated_edge_count": reactivated_edge_keys.size(),
        "staged_edge_count": int(pending.get("staged_edge_count", 0)),
        "retired_edge_count": retired_edge_count,
        "reused_corner_cap_count": reused_cap_keys.size(),
        "staged_corner_cap_count": int(pending.get("staged_cap_count", 0)),
        "retired_corner_cap_count": retired_corner_cap_count,
        "profile_usec": profile_usec
    }
    _pending_sync_transaction.clear()
    return result


func abort_sync_transitions(transaction_id: int) -> Dictionary:
    if _pending_sync_transaction.is_empty():
        return {"ok": false, "error": "no_pending_transaction", "active_count": _managed_edges.size()}
    if int(_pending_sync_transaction.get("transaction_id", -1)) != transaction_id:
        return {"ok": false, "error": "invalid_transaction_id", "active_count": _managed_edges.size()}
    _abort_pending_transaction()
    return {"ok": true, "aborted": true, "active_count": _managed_edges.size()}


func _abort_pending_transaction() -> void:
    if _pending_sync_transaction.is_empty():
        return
    var staged_edges: Dictionary = _pending_sync_transaction.get("staged_edges", {})
    var staged_caps: Dictionary = _pending_sync_transaction.get("staged_caps", {})
    var reused_edge_keys: Dictionary = _pending_sync_transaction.get("reused_edge_keys", {})
    var reused_cap_keys: Dictionary = _pending_sync_transaction.get("reused_cap_keys", {})
    _free_staged(staged_edges, reused_edge_keys)
    _free_staged_caps(staged_caps, reused_cap_keys)
    _pending_sync_transaction.clear()


func _capture_patch_snapshots(candidates: Dictionary) -> Dictionary:
    var snapshots: Dictionary = {}
    for edge_value in candidates.values():
        if not (edge_value is Dictionary):
            continue
        var edge: Dictionary = edge_value
        var endpoints: Array[Dictionary] = [
            {"patch": edge.get("first_patch"), "side": str(edge.get("first_side", ""))},
            {"patch": edge.get("second_patch"), "side": str(edge.get("second_side", ""))}
        ]
        for endpoint in endpoints:
            var patch: Node3D = endpoint.get("patch") as Node3D
            var side: String = str(endpoint.get("side", ""))
            if not is_instance_valid(patch) or patch.is_queued_for_deletion() or side.is_empty():
                return {"ok": false, "error": "invalid_patch_snapshot_endpoint"}
            var instance_id: int = patch.get_instance_id()
            if not snapshots.has(instance_id):
                var has_world_state: bool = patch.has_method("get_world_object_state")
                var world_state: Dictionary = {}
                if has_world_state:
                    var state_value: Variant = patch.call("get_world_object_state")
                    if not (state_value is Dictionary):
                        return {"ok": false, "error": "invalid_patch_world_state_snapshot"}
                    world_state = state_value.duplicate(true)
                snapshots[instance_id] = {
                    "patch": patch,
                    "global_transform": patch.global_transform,
                    "has_world_state": has_world_state,
                    "world_state": world_state,
                    "sides": {}
                }
            var snapshot: Dictionary = snapshots[instance_id]
            var side_states: Dictionary = snapshot.get("sides", {})
            if not side_states.has(side):
                var has_active_query: bool = patch.has_method("is_shared_transition_active")
                side_states[side] = {
                    "has_active_query": has_active_query,
                    "active": bool(patch.call("is_shared_transition_active", side)) if has_active_query else false
                }
                snapshot["sides"] = side_states
                snapshots[instance_id] = snapshot
    return {"ok": true, "snapshots": snapshots}


func _patch_snapshots_match(snapshots: Dictionary) -> bool:
    for snapshot_value in snapshots.values():
        if not (snapshot_value is Dictionary):
            return false
        var snapshot: Dictionary = snapshot_value
        var patch: Node3D = snapshot.get("patch") as Node3D
        if not is_instance_valid(patch) or patch.is_queued_for_deletion():
            return false
        if patch.global_transform != snapshot.get("global_transform", Transform3D.IDENTITY):
            return false
        if bool(snapshot.get("has_world_state", false)):
            if not patch.has_method("get_world_object_state"):
                return false
            var state_value: Variant = patch.call("get_world_object_state")
            if not (state_value is Dictionary) or state_value != snapshot.get("world_state", {}):
                return false
        var side_states: Dictionary = snapshot.get("sides", {})
        for side_value in side_states.keys():
            var side: String = str(side_value)
            var side_snapshot: Dictionary = side_states[side_value]
            var has_active_query: bool = bool(side_snapshot.get("has_active_query", false))
            if patch.has_method("is_shared_transition_active") != has_active_query:
                return false
            var current_active: bool = bool(patch.call("is_shared_transition_active", side)) if has_active_query else false
            if current_active != bool(side_snapshot.get("active", false)):
                return false
    return true


func _restore_patch_snapshots(snapshots: Dictionary) -> bool:
    var restored: bool = true
    for snapshot_value in snapshots.values():
        if not (snapshot_value is Dictionary):
            restored = false
            continue
        var snapshot: Dictionary = snapshot_value
        var patch: Node3D = snapshot.get("patch") as Node3D
        if not is_instance_valid(patch) or patch.is_queued_for_deletion():
            restored = false
            continue
        var side_states: Dictionary = snapshot.get("sides", {})
        for side_value in side_states.keys():
            var side: String = str(side_value)
            var side_snapshot: Dictionary = side_states[side_value]
            var target_active: bool = bool(side_snapshot.get("active", false))
            var current_active: bool = bool(patch.call("is_shared_transition_active", side)) if patch.has_method("is_shared_transition_active") else false
            if current_active == target_active:
                continue
            if not patch.has_method("set_shared_transition_active") or not bool(patch.call("set_shared_transition_active", side, target_active)):
                restored = false
    return restored


func _managed_map_matches_snapshot(current: Dictionary, snapshot: Dictionary, resource_kind: String) -> bool:
    if current.size() != snapshot.size():
        return false
    for key_value in snapshot.keys():
        if not current.has(key_value):
            return false
        var current_record_value: Variant = current[key_value]
        var snapshot_record_value: Variant = snapshot[key_value]
        if not (current_record_value is Dictionary) or not (snapshot_record_value is Dictionary):
            return false
        var current_record: Dictionary = current_record_value
        var snapshot_record: Dictionary = snapshot_record_value
        if current_record.get("body") != snapshot_record.get("body"):
            return false
        if current_record.get("reuse_signature", []) != snapshot_record.get("reuse_signature", []):
            return false
        if resource_kind == "edge":
            for field in ["first_patch", "second_patch", "first_side", "second_side"]:
                if current_record.get(field) != snapshot_record.get(field):
                    return false
        elif resource_kind == "corner_cap":
            for field in ["stable_id", "corner", "junction_key"]:
                if current_record.get(field) != snapshot_record.get(field):
                    return false
    return true



func clear_all() -> void:
    _abort_pending_transaction()
    for edge in _managed_edges.values():
        _retire_old_edge(edge, {})
    for cap in _managed_corner_caps.values():
        _retire_old_cap(cap)
    _managed_edges.clear()
    _managed_corner_caps.clear()
    _last_blocked_corner_reports.clear()

func get_blocked_corner_reports() -> Array[Dictionary]:
    return _last_blocked_corner_reports.duplicate(true)

func get_transition_count() -> int:
    return _managed_edges.size()

func get_corner_cap_count() -> int:
    return _managed_corner_caps.size()

func get_corner_cap_body(stable_id: String, corner: String) -> StaticBody3D:
    var cap: Dictionary = _managed_corner_caps.get(_report_token(stable_id, corner), {})
    var body: StaticBody3D = cap.get("body") as StaticBody3D
    return body if is_instance_valid(body) else null

func get_transition_body(edge_key: String) -> StaticBody3D:
    var edge: Dictionary = _managed_edges.get(edge_key, {})
    var body: StaticBody3D = edge.get("body") as StaticBody3D
    return body if is_instance_valid(body) else null

func _build_corner_cap_specs(candidates: Dictionary, reports: Array) -> Dictionary:
    var patch_by_id: Dictionary = {}
    for edge_value in candidates.values():
        if not (edge_value is Dictionary):
            continue
        var edge: Dictionary = edge_value
        patch_by_id[str(edge.get("first_id", ""))] = edge.get("first_patch")
        patch_by_id[str(edge.get("second_id", ""))] = edge.get("second_patch")

    var groups: Dictionary = {}
    for report_value in reports:
        if not (report_value is Dictionary):
            continue
        var report: Dictionary = report_value
        var stable_id: String = str(report.get("stable_id", ""))
        var corner: String = str(report.get("corner", ""))
        var patch: Node3D = patch_by_id.get(stable_id) as Node3D
        var offset: Vector3 = _corner_offset(corner)
        if not is_instance_valid(patch) or offset == Vector3.ZERO:
            continue
        var junction_position: Vector3 = patch.global_position + offset
        var junction_key: String = _corner_key(junction_position)
        var entries: Array = groups.get(junction_key, [])
        entries.append({
            "stable_id": stable_id,
            "corner": corner,
            "patch": patch,
            "edge_keys": report.get("edge_keys", []).duplicate(),
            "junction_position": junction_position
        })
        groups[junction_key] = entries

    var group_keys: Array = groups.keys()
    group_keys.sort()

    # Track every junction report, including ineligible ones, per edge. If one
    # endpoint of a shared edge must fall back, a compatible cap at the other
    # endpoint must not re-enable that edge and create a one-sided ramp overlap.
    var edge_groups: Dictionary = {}
    for junction_key_value in group_keys:
        var junction_key: String = str(junction_key_value)
        var edge_set: Dictionary = {}
        for entry_value in groups[junction_key]:
            if not (entry_value is Dictionary):
                continue
            var entry: Dictionary = entry_value
            var entry_edges_value: Variant = entry.get("edge_keys", [])
            if not (entry_edges_value is Array):
                continue
            var entry_edges: Array = entry_edges_value
            for edge_key_value in entry_edges:
                if not (edge_key_value is String) or str(edge_key_value).is_empty():
                    continue
                edge_set[str(edge_key_value)] = true
        var junction_edge_keys: Array[String] = []
        for edge_key_value in edge_set.keys():
            junction_edge_keys.append(str(edge_key_value))
        junction_edge_keys.sort()
        for edge_key in junction_edge_keys:
            var junctions: Array = edge_groups.get(edge_key, [])
            if not junctions.has(junction_key):
                junctions.append(junction_key)
            junctions.sort()
            edge_groups[edge_key] = junctions

    var specs: Array[Dictionary] = []
    for junction_key_value in group_keys:
        var junction_key: String = str(junction_key_value)
        var entries: Array = groups[junction_key]
        if entries.size() != 4:
            continue
        var patch_ids: Dictionary = {}
        var corners_seen: Dictionary = {}
        var edges_seen: Dictionary = {}
        var midpoint_heights: Array[float] = []
        var corner_entries: Array[Dictionary] = []
        var valid_group: bool = true
        for entry_value in entries:
            if not (entry_value is Dictionary):
                valid_group = false
                break
            var entry: Dictionary = entry_value
            var stable_id: String = str(entry.get("stable_id", ""))
            var corner: String = str(entry.get("corner", ""))
            var patch: Node3D = entry.get("patch") as Node3D
            if stable_id.is_empty() or not CORNER_NAMES.has(corner) or not is_instance_valid(patch) or patch_ids.has(stable_id) or corners_seen.has(corner):
                valid_group = false
                break
            if not patch.has_method("get_top_height"):
                valid_group = false
                break
            patch_ids[stable_id] = true
            corners_seen[corner] = true
            var top_height: float = float(patch.call("get_top_height"))
            if is_nan(top_height) or is_inf(top_height):
                valid_group = false
                break
            var entry_edges: Array = entry.get("edge_keys", [])
            if entry_edges.size() != 2:
                valid_group = false
                break
            for edge_key_value in entry_edges:
                if not (edge_key_value is String):
                    valid_group = false
                    break
                var edge_key: String = edge_key_value
                var candidate_value: Variant = candidates.get(edge_key, null)
                if not (candidate_value is Dictionary):
                    valid_group = false
                    break
                var candidate: Dictionary = candidate_value
                var geometry: Dictionary = candidate.get("geometry", {})
                if not geometry.has("low_top") or not geometry.has("high_top") or absf(float(geometry.get("patch_size", 0.0)) - PATCH_SIZE) > POSITION_TOLERANCE:
                    valid_group = false
                    break
                midpoint_heights.append((float(geometry["low_top"]) + float(geometry["high_top"])) * 0.5)
                edges_seen[edge_key] = true
            if not valid_group:
                break
            corner_entries.append({
                "stable_id": stable_id,
                "corner": corner,
                "patch": patch,
                "top_height": top_height
            })
        if not valid_group or patch_ids.size() != 4 or corners_seen.size() != 4 or edges_seen.size() != 4 or midpoint_heights.size() != 8:
            continue
        var common_midpoint: float = midpoint_heights[0]
        for midpoint_value in midpoint_heights:
            if absf(midpoint_value - common_midpoint) > POSITION_TOLERANCE:
                valid_group = false
                break
        if not valid_group:
            continue
        var junction_position: Vector3 = entries[0]["junction_position"]
        var edge_keys: Array[String] = []
        for edge_key_value in edges_seen.keys():
            edge_keys.append(str(edge_key_value))
        edge_keys.sort()
        specs.append({
            "junction_key": junction_key,
            "position": junction_position,
            "midpoint_height": common_midpoint,
            "corners": corner_entries,
            "edge_keys": edge_keys
        })

    # A cap group is eligible only when every junction sharing each of its
    # edges is also eligible. Propagate fallback across connected junctions
    # until no compatible group can bridge into an incompatible endpoint.
    var eligible_junctions: Dictionary = {}
    for spec in specs:
        eligible_junctions[str(spec["junction_key"])] = true
    var eligibility_changed: bool = true
    while eligibility_changed:
        eligibility_changed = false
        var shared_edge_keys: Array = edge_groups.keys()
        shared_edge_keys.sort()
        for edge_key_value in shared_edge_keys:
            var junctions: Array = edge_groups[str(edge_key_value)]
            if junctions.size() < 2:
                continue
            var has_ineligible_junction: bool = false
            for junction_key_value in junctions:
                if not eligible_junctions.has(str(junction_key_value)):
                    has_ineligible_junction = true
                    break
            if not has_ineligible_junction:
                continue
            for junction_key_value in junctions:
                var junction_key: String = str(junction_key_value)
                if eligible_junctions.has(junction_key):
                    eligible_junctions.erase(junction_key)
                    eligibility_changed = true

    var safe_specs: Array[Dictionary] = []
    var edge_junctions: Dictionary = {}
    var report_policies: Dictionary = {}
    for spec in specs:
        var junction_key: String = str(spec["junction_key"])
        if not eligible_junctions.has(junction_key):
            continue
        safe_specs.append(spec)
        var junction_position: Vector3 = spec["position"]
        var spec_edges: Array = spec["edge_keys"]
        for edge_key_value in spec_edges:
            var edge_key: String = str(edge_key_value)
            var positions: Array = edge_junctions.get(edge_key, [])
            positions.append(junction_position)
            edge_junctions[edge_key] = positions
        var spec_corners: Array = spec["corners"]
        for corner_entry in spec_corners:
            report_policies[_report_token(str(corner_entry["stable_id"]), str(corner_entry["corner"]))] = {
                "junction_key": junction_key,
                "midpoint_height": float(spec["midpoint_height"])
            }
    return {"ok": true, "specs": safe_specs, "edge_junctions": edge_junctions, "report_policies": report_policies}

func _corner_cap_reuse_signature(spec: Dictionary, corner_entry: Dictionary) -> Array:
    var patch: Node3D = corner_entry.get("patch") as Node3D
    if not is_instance_valid(patch):
        return []
    var position_value: Variant = spec.get("position", null)
    if not (position_value is Vector3):
        return []
    if not spec.has("midpoint_height") or not corner_entry.has("top_height"):
        return []
    var midpoint_height: float = float(spec["midpoint_height"])
    var top_height: float = float(corner_entry["top_height"])
    if is_nan(midpoint_height) or is_inf(midpoint_height) or is_nan(top_height) or is_inf(top_height):
        return []
    return [
        str(corner_entry.get("stable_id", "")),
        str(corner_entry.get("corner", "")),
        patch.get_instance_id(),
        str(spec.get("junction_key", "")),
        position_value,
        midpoint_height,
        top_height
    ]

func _stage_corner_cap(cap_key: String, spec: Dictionary, corner_entry: Dictionary, reuse_signature: Array = []) -> Dictionary:
    var patch: Node3D = corner_entry.get("patch") as Node3D
    if not is_instance_valid(patch):
        return {}
    var corner: String = str(corner_entry.get("corner", ""))
    var sign_x: float = 0.0
    var sign_z: float = 0.0
    match corner:
        "north_east":
            sign_x = 1.0
            sign_z = -1.0
        "south_east":
            sign_x = 1.0
            sign_z = 1.0
        "south_west":
            sign_x = -1.0
            sign_z = 1.0
        "north_west":
            sign_x = -1.0
            sign_z = -1.0
        _:
            return {}
    var top_height: float = float(corner_entry.get("top_height", 0.0))
    var midpoint_height: float = float(spec.get("midpoint_height", 0.0))
    var far_corner := Vector3(-sign_x * EDGE_RUN_PER_PATCH, top_height, -sign_z * EDGE_RUN_PER_PATCH)
    var side_x := Vector3(0.0, midpoint_height, -sign_z * EDGE_RUN_PER_PATCH)
    var junction := Vector3(0.0, midpoint_height, 0.0)
    var side_z := Vector3(-sign_x * EDGE_RUN_PER_PATCH, midpoint_height, 0.0)
    var top_points: Array[Vector3] = [far_corner, side_x, junction, side_z]
    var bottom_points: Array[Vector3] = []
    for point in top_points:
        bottom_points.append(point - Vector3.UP * COLLISION_THICKNESS)
    var top_indices: Array[int] = [0, 1, 2, 0, 2, 3]
    if sign_x * sign_z > 0.0:
        top_indices = [0, 2, 1, 0, 3, 2]

    var body := StaticBody3D.new()
    body.name = "TerrainCornerCap_" + str(abs(hash(cap_key)))
    body.collision_layer = 0
    body.collision_mask = 0
    body.set_meta("terrain_corner_key", str(spec.get("junction_key", "")))
    body.set_meta("terrain_corner_owner", str(corner_entry.get("stable_id", "")))
    body.set_meta("terrain_corner_name", corner)
    add_child(body)
    var junction_position: Vector3 = spec.get("position", patch.global_position)
    body.global_transform = Transform3D(Basis.IDENTITY, junction_position)

    var faces := PackedVector3Array()
    var surface_tool := SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in range(0, top_indices.size(), 3):
        var a: int = top_indices[index]
        var b: int = top_indices[index + 1]
        var c: int = top_indices[index + 2]
        _append_triangle(faces, top_points[a], top_points[b], top_points[c])
        _append_triangle(faces, bottom_points[c], bottom_points[b], bottom_points[a])
        surface_tool.add_vertex(top_points[a])
        surface_tool.add_vertex(top_points[b])
        surface_tool.add_vertex(top_points[c])
    for index in range(4):
        var next_index: int = (index + 1) % 4
        _append_triangle(faces, top_points[index], bottom_points[index], bottom_points[next_index])
        _append_triangle(faces, top_points[index], bottom_points[next_index], top_points[next_index])
    if faces.size() < 36:
        body.queue_free()
        return {}
    var concave := ConcavePolygonShape3D.new()
    concave.backface_collision = true
    concave.set_faces(faces)
    var collision := CollisionShape3D.new()
    collision.name = "CornerCapCollision"
    collision.shape = concave
    body.add_child(collision)

    if DisplayServer.get_name() != "headless":
        surface_tool.generate_normals()
        var cap_mesh: ArrayMesh = surface_tool.commit()
        if cap_mesh == null:
            body.queue_free()
            return {}
        var visual := MeshInstance3D.new()
        visual.name = "CornerCapVisual"
        visual.mesh = cap_mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("#9bb7b5")
        material.roughness = 0.82
        material.metallic = 0.12
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        visual.material_override = material
        body.add_child(visual)
    return {
        "body": body,
        "stable_id": str(corner_entry.get("stable_id", "")),
        "corner": corner,
        "junction_key": str(spec.get("junction_key", "")),
        "reuse_signature": reuse_signature
    }

func _append_triangle(target: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
    target.append(a)
    target.append(b)
    target.append(c)

func _edge_reuse_signature(edge_key: String, edge: Dictionary, corner_junctions: Array) -> Array:
    var geometry: Dictionary = edge.get("geometry", {})
    if not geometry.has("basis") or not geometry.has("center") or not geometry.has("slope_length") or not geometry.has("patch_size"):
        return []
    var first_patch: Node3D = edge.get("first_patch") as Node3D
    var second_patch: Node3D = edge.get("second_patch") as Node3D
    if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
        return []
    var basis: Basis = geometry["basis"]
    var width_axis: Vector3 = basis.z.normalized()
    var patch_size: float = float(geometry["patch_size"])
    var trim_negative: float = 0.0
    var trim_positive: float = 0.0
    for junction_value in corner_junctions:
        if not (junction_value is Vector3):
            return []
        var projection: float = (junction_value - geometry["center"]).dot(width_axis)
        if absf(absf(projection) - patch_size * 0.5) > POSITION_TOLERANCE:
            return []
        if projection < 0.0:
            trim_negative = EDGE_RUN_PER_PATCH
        else:
            trim_positive = EDGE_RUN_PER_PATCH
    var width: float = patch_size - trim_negative - trim_positive
    if width <= POSITION_TOLERANCE:
        return []
    var center: Vector3 = geometry["center"] + width_axis * ((trim_negative - trim_positive) * 0.5)
    var body_origin: Vector3 = center - basis.y * (COLLISION_THICKNESS * 0.5)
    return [
        edge_key,
        str(edge.get("first_id", "")),
        str(edge.get("second_id", "")),
        first_patch.get_instance_id(),
        second_patch.get_instance_id(),
        str(edge.get("first_side", "")),
        str(edge.get("second_side", "")),
        basis,
        center,
        body_origin,
        float(geometry["slope_length"]),
        patch_size,
        width,
        trim_negative,
        trim_positive
    ]

func _stage_edge(edge_key: String, edge: Dictionary, corner_junctions: Array = [], reuse_signature: Array = []) -> Dictionary:
    var geometry: Dictionary = edge["geometry"].duplicate(true)
    var basis: Basis = geometry["basis"]
    var width_axis: Vector3 = basis.z.normalized()
    var patch_size: float = float(geometry["patch_size"])
    var trim_negative: float = 0.0
    var trim_positive: float = 0.0
    for junction_value in corner_junctions:
        if not (junction_value is Vector3):
            return {}
        var projection: float = (junction_value - geometry["center"]).dot(width_axis)
        if absf(absf(projection) - patch_size * 0.5) > POSITION_TOLERANCE:
            return {}
        if projection < 0.0:
            trim_negative = EDGE_RUN_PER_PATCH
        else:
            trim_positive = EDGE_RUN_PER_PATCH
    var width: float = patch_size - trim_negative - trim_positive
    if width <= POSITION_TOLERANCE:
        return {}
    var center: Vector3 = geometry["center"] + width_axis * ((trim_negative - trim_positive) * 0.5)
    geometry["center"] = center
    geometry["body_origin"] = center - basis.y * (COLLISION_THICKNESS * 0.5)
    geometry["width"] = width

    var body := StaticBody3D.new()
    body.name = "TerrainTransition_" + str(abs(hash(edge_key)))
    body.collision_layer = 0
    body.collision_mask = 0
    var collision := CollisionShape3D.new()
    collision.name = "SharedTransitionCollision"
    var box := BoxShape3D.new()
    box.size = Vector3(float(geometry["slope_length"]), COLLISION_THICKNESS, width)
    collision.shape = box
    body.add_child(collision)
    if DisplayServer.get_name() != "headless":
        var visual := MeshInstance3D.new()
        visual.name = "SharedTransitionVisual"
        var ramp_mesh := BoxMesh.new()
        ramp_mesh.size = Vector3(float(geometry["slope_length"]), COLLISION_THICKNESS, width)
        visual.mesh = ramp_mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("#9bb7b5")
        material.roughness = 0.82
        material.metallic = 0.12
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        visual.material_override = material
        body.add_child(visual)
    body.set_meta("terrain_edge_key", edge_key)
    body.set_meta("terrain_edge_owner", str(edge["first_id"]))
    body.set_meta("terrain_corner_trim_negative", trim_negative)
    body.set_meta("terrain_corner_trim_positive", trim_positive)
    add_child(body)
    var edge_basis: Basis = geometry["basis"]
    var body_origin: Vector3 = geometry["body_origin"]
    body.global_transform = Transform3D(edge_basis, body_origin)
    return {
        "body": body,
        "first_patch": edge["first_patch"],
        "second_patch": edge["second_patch"],
        "first_side": edge["first_side"],
        "second_side": edge["second_side"],
        "first_id": edge["first_id"],
        "second_id": edge["second_id"],
        "width": width,
        "trim_negative": trim_negative,
        "trim_positive": trim_positive,
        "reuse_signature": reuse_signature
    }

func _retire_old_edge(old_edge: Dictionary, replacement: Dictionary) -> void:
    var old_first: Node3D = old_edge.get("first_patch") as Node3D
    var old_second: Node3D = old_edge.get("second_patch") as Node3D
    var old_body: StaticBody3D = old_edge.get("body") as StaticBody3D
    if is_instance_valid(old_first):
        var replacement_first: Node3D = replacement.get("first_patch") as Node3D
        if replacement_first != old_first or str(replacement.get("first_side", "")) != str(old_edge.get("first_side", "")):
            old_first.call("set_shared_transition_active", str(old_edge["first_side"]), false)
    if is_instance_valid(old_second):
        var replacement_second: Node3D = replacement.get("second_patch") as Node3D
        if replacement_second != old_second or str(replacement.get("second_side", "")) != str(old_edge.get("second_side", "")):
            old_second.call("set_shared_transition_active", str(old_edge["second_side"]), false)
    if is_instance_valid(old_body):
        old_body.collision_layer = 0
        old_body.queue_free()

func _retire_old_cap(old_cap: Dictionary) -> void:
    var body: StaticBody3D = old_cap.get("body") as StaticBody3D
    if is_instance_valid(body):
        body.collision_layer = 0
        body.queue_free()

func _free_staged(staged: Dictionary, preserved_keys: Dictionary = {}) -> void:
    for edge_key in staged.keys():
        if preserved_keys.has(str(edge_key)):
            continue
        var edge: Dictionary = staged[edge_key]
        var body: StaticBody3D = edge.get("body") as StaticBody3D
        if is_instance_valid(body):
            body.collision_layer = 0
            body.queue_free()

func _free_staged_caps(staged: Dictionary, preserved_keys: Dictionary = {}) -> void:
    for cap_key in staged.keys():
        if preserved_keys.has(str(cap_key)):
            continue
        var cap: Dictionary = staged[cap_key]
        _retire_old_cap(cap)

func _is_reusable_managed_body(candidate: StaticBody3D) -> bool:
    return (
        is_instance_valid(candidate)
        and not candidate.is_queued_for_deletion()
        and candidate.get_parent() == self
        and candidate.collision_layer == COLLISION_LAYER
    )

func _edge_patch_states_are_active(edge: Dictionary) -> bool:
    var first_patch: Node3D = edge.get("first_patch") as Node3D
    var second_patch: Node3D = edge.get("second_patch") as Node3D
    if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
        return false
    if not first_patch.has_method("is_shared_transition_active") or not second_patch.has_method("is_shared_transition_active"):
        return false
    return (
        bool(first_patch.call("is_shared_transition_active", str(edge.get("first_side", ""))))
        and bool(second_patch.call("is_shared_transition_active", str(edge.get("second_side", ""))))
    )

func _signatures_match(previous: Variant, candidate: Array) -> bool:
    if not (previous is Array):
        return false
    var previous_values: Array = previous
    if previous_values.size() != candidate.size():
        return false
    for index in range(candidate.size()):
        if previous_values[index] != candidate[index]:
            return false
    return true

func _rollback_patch_activations(activations: Array[Dictionary]) -> void:
    for activation in activations:
        var patch: Node3D = activation.get("patch") as Node3D
        if is_instance_valid(patch):
            patch.call("set_shared_transition_active", str(activation.get("side", "")), false)

func _corner_offset(corner: String) -> Vector3:
    var half: float = PATCH_SIZE * 0.5
    match corner:
        "north_east": return Vector3(half, 0.0, -half)
        "south_east": return Vector3(half, 0.0, half)
        "south_west": return Vector3(-half, 0.0, half)
        "north_west": return Vector3(-half, 0.0, -half)
        _: return Vector3.ZERO

func _corner_key(position: Vector3) -> String:
    return "%.3f|%.3f|%.3f" % [position.x, position.y, position.z]

func _report_token(stable_id: String, corner: String) -> String:
    return stable_id + "|" + corner

func _sorted_keys(source: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for key in source.keys():
        result.append(str(key))
    result.sort()
    return result

func _build_geometry(first_patch: Node3D, second_patch: Node3D, descriptor: Dictionary) -> Dictionary:
    for key in ["first_top_height", "second_top_height", "patch_size", "height_delta"]:
        if not descriptor.has(key):
            return {"ok": false, "error": "missing_descriptor_" + key}
    var patch_size: float = float(descriptor["patch_size"])
    if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0:
        return {"ok": false, "error": "invalid_patch_size"}
    var first_position: Vector3 = first_patch.global_position
    var second_position: Vector3 = second_patch.global_position
    var horizontal_delta := Vector3(second_position.x - first_position.x, 0.0, second_position.z - first_position.z)
    if absf(first_position.y - second_position.y) > POSITION_TOLERANCE or absf(horizontal_delta.length() - patch_size) > POSITION_TOLERANCE:
        return {"ok": false, "error": "patches_not_level_cardinal_neighbors"}
    var declared_first_side: Variant = descriptor.get("first_side", null)
    if not (declared_first_side is String) or _side_between(first_position, second_position, patch_size) != str(declared_first_side):
        return {"ok": false, "error": "descriptor_side_mismatch"}
    if not first_patch.has_method("get_top_height") or not second_patch.has_method("get_top_height") or not first_patch.has_method("get_edge_ramp_profile") or not second_patch.has_method("get_edge_ramp_profile"):
        return {"ok": false, "error": "patch_missing_geometry_profile"}
    var first_profile: Dictionary = first_patch.call("get_edge_ramp_profile")
    var second_profile: Dictionary = second_patch.call("get_edge_ramp_profile")
    var run: float = float(first_profile.get("run", 0.0))
    var thickness: float = float(first_profile.get("collision_thickness", 0.0))
    if absf(run - float(second_profile.get("run", -1.0))) > POSITION_TOLERANCE or absf(thickness - float(second_profile.get("collision_thickness", -1.0))) > POSITION_TOLERANCE:
        return {"ok": false, "error": "mixed_patch_transition_profiles"}
    if absf(run - EDGE_RUN_PER_PATCH) > POSITION_TOLERANCE or absf(thickness - COLLISION_THICKNESS) > POSITION_TOLERANCE:
        return {"ok": false, "error": "unsupported_patch_transition_profile"}
    var first_top: float = float(descriptor["first_top_height"])
    var second_top: float = float(descriptor["second_top_height"])
    if absf(float(first_patch.call("get_top_height")) - first_top) > POSITION_TOLERANCE or absf(float(second_patch.call("get_top_height")) - second_top) > POSITION_TOLERANCE:
        return {"ok": false, "error": "stale_transition_descriptor"}
    var height_delta: float = absf(first_top - second_top)
    if height_delta <= POSITION_TOLERANCE or absf(height_delta - float(descriptor["height_delta"])) > POSITION_TOLERANCE:
        return {"ok": false, "error": "descriptor_height_mismatch"}
    var low_patch: Node3D = first_patch if first_top < second_top else second_patch
    var high_patch: Node3D = second_patch if first_top < second_top else first_patch
    var low_top: float = minf(first_top, second_top)
    var high_top: float = maxf(first_top, second_top)
    var horizontal_direction := high_patch.global_position - low_patch.global_position
    horizontal_direction.y = 0.0
    horizontal_direction = horizontal_direction.normalized()
    var total_run: float = run * 2.0
    var tangent := (horizontal_direction * total_run + Vector3.UP * height_delta).normalized()
    var width_axis := tangent.cross(Vector3.UP).normalized()
    var normal := width_axis.cross(tangent).normalized()
    if normal.y <= 0.0:
        return {"ok": false, "error": "invalid_transition_basis"}
    var basis := Basis(tangent, normal, width_axis)
    var seam_center := (first_position + second_position) * 0.5
    var center := Vector3(seam_center.x, (low_top + high_top) * 0.5, seam_center.z)
    var slope_length: float = sqrt(total_run * total_run + height_delta * height_delta)
    return {
        "ok": true,
        "basis": basis,
        "center": center,
        "body_origin": center - normal * (COLLISION_THICKNESS * 0.5),
        "slope_length": slope_length,
        "patch_size": patch_size,
        "low_top": low_top,
        "high_top": high_top,
        "horizontal_run": total_run
    }

func _side_between(first_position: Vector3, second_position: Vector3, patch_size: float) -> String:
    var delta: Vector3 = second_position - first_position
    if absf(delta.y) > POSITION_TOLERANCE:
        return ""
    if absf(delta.x - patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
        return "east"
    if absf(delta.x + patch_size) <= POSITION_TOLERANCE and absf(delta.z) <= POSITION_TOLERANCE:
        return "west"
    if absf(delta.z + patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
        return "north"
    if absf(delta.z - patch_size) <= POSITION_TOLERANCE and absf(delta.x) <= POSITION_TOLERANCE:
        return "south"
    return ""

func _opposite_side(side: String) -> String:
    match side:
        "east": return "west"
        "west": return "east"
        "north": return "south"
        "south": return "north"
        _: return ""
