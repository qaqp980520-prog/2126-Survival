extends RefCounted
class_name SurfaceTerrainAdjacencyCoordinator

## Coordinates the Index generation, scoped Patch neighbor state, and partial Collider
## resource transaction. Chunk roots must remain alive until execute_delta returns finalized=true.
const IndexScript = preload("res://systems/SurfaceTerrainAdjacencyIndex.gd")
const ScopedTransactionScript = preload("res://systems/SurfaceTerrainAdjacencyScopedTransaction.gd")

var _index: RefCounted
var _scoped_transaction: RefCounted
var _collider_manager: Node
var _pending: Dictionary = {}


func bind_participants(index: RefCounted, scoped_transaction: RefCounted, collider_manager: Node) -> bool:
	if not is_instance_valid(index) or not is_instance_valid(scoped_transaction) or not is_instance_valid(collider_manager):
		return false
	for method_name in [
		"plan_delta",
		"reserve_delta",
		"publish_delta",
		"finalize_delta",
		"rollback_published_delta",
		"abort_delta",
		"get_patches_by_stable_id",
		"get_plan_patches_by_stable_id",
		"get_plan_edge_descriptors",
		"has_pending_plan",
		"get_reserved_plan_id"
	]:
		if not index.has_method(method_name):
			return false
	for method_name in ["prepare", "apply", "finalize", "rollback", "abort", "has_pending_transaction"]:
		if not scoped_transaction.has_method(method_name):
			return false
	for method_name in [
		"prepare_partial_sync_transitions",
		"accept_scoped_neighbor_state_apply",
		"commit_sync_transitions",
		"abort_sync_transitions"
	]:
		if not collider_manager.has_method(method_name):
			return false
	_index = index
	_scoped_transaction = scoped_transaction
	_collider_manager = collider_manager
	return true


func has_pending_transaction() -> bool:
	return not _pending.is_empty()


## Executes one prepared Index delta across all three participants. The caller must keep
## removed Chunk roots alive until this method returns finalized=true.
func execute_delta(
	remove_stable_ids: Array,
	additions: Array,
	profile_enabled: bool = false,
	old_patches_snapshot: Dictionary = {},
	old_patches_snapshot_generation: int = -1
) -> Dictionary:
	var coordinator_started_usec: int = Time.get_ticks_usec() if profile_enabled else 0
	var phase_profile: Dictionary = {}
	var phase_started_usec: int = coordinator_started_usec
	if has_pending_transaction():
		return {"ok": false, "error": "coordinator_transaction_in_progress", "pending": _pending.get("stage", "")}
	if not _participants_valid():
		return {"ok": false, "error": "coordinator_participants_unavailable"}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var plan_result: Dictionary
	if profile_enabled:
		plan_result = _index.call("plan_delta", remove_stable_ids, additions, true)
	else:
		plan_result = _index.call("plan_delta", remove_stable_ids, additions)
	if profile_enabled:
		phase_profile["plan_delta_usec"] = Time.get_ticks_usec() - phase_started_usec
		var plan_subphases: Dictionary = plan_result.get("plan_delta_profile_usec", {})
		phase_profile["plan_delta_subphases_usec"] = plan_subphases.duplicate(true)
	if not bool(plan_result.get("ok", false)):
		return plan_result
	if bool(plan_result.get("noop", false)):
		return {"ok": true, "noop": true, "generation": int(plan_result.get("generation", -1))}

	var summary: Dictionary = plan_result.get("summary", {})
	var plan_id: String = str(summary.get("plan_id", ""))
	if plan_id.is_empty():
		return {"ok": false, "error": "index_plan_id_missing"}
	var use_batch_snapshot: bool = old_patches_snapshot_generation >= 0
	if use_batch_snapshot and int(summary.get("base_generation", -1)) != old_patches_snapshot_generation:
		var stale_snapshot_cleanup: Dictionary = _abort_index_or_retain(plan_id, "batch_index_snapshot_generation_mismatch")
		if not bool(stale_snapshot_cleanup.get("ok", false)):
			return stale_snapshot_cleanup
		return {
			"ok": false,
			"error": "batch_index_snapshot_generation_mismatch",
			"snapshot_generation": old_patches_snapshot_generation,
			"plan_generation": int(summary.get("base_generation", -1))
		}
	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var reservation: Dictionary = _index.call("reserve_delta", plan_id)
	if profile_enabled:
		phase_profile["index_reservation_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(reservation.get("ok", false)):
		var reservation_cleanup: Dictionary = _abort_index_or_retain(plan_id, "index_generation_reservation_failed")
		if not bool(reservation_cleanup.get("ok", false)):
			return reservation_cleanup
		return {"ok": false, "error": "index_generation_reservation_failed:" + str(reservation.get("error", "unknown"))}

	var old_patch_result: Dictionary = {}
	if not use_batch_snapshot:
		old_patch_result = _index.call("get_patches_by_stable_id")
	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var candidate_patch_result: Dictionary = _index.call("get_plan_patches_by_stable_id", plan_id)
	if profile_enabled:
		phase_profile["candidate_patch_map_usec"] = Time.get_ticks_usec() - phase_started_usec
	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var candidate_descriptor_result: Dictionary = _index.call("get_plan_edge_descriptors", plan_id)
	if profile_enabled:
		phase_profile["candidate_descriptor_snapshot_usec"] = Time.get_ticks_usec() - phase_started_usec
	if (
		(not use_batch_snapshot and not bool(old_patch_result.get("ok", false)))
		or not bool(candidate_patch_result.get("ok", false))
		or not bool(candidate_descriptor_result.get("ok", false))
	):
		var snapshot_cleanup: Dictionary = _abort_index_or_retain(plan_id, "index_candidate_snapshot_unavailable")
		if not bool(snapshot_cleanup.get("ok", false)):
			return snapshot_cleanup
		return {"ok": false, "error": "index_candidate_snapshot_unavailable"}

	# Controller batches pass the exact immutable pre-delta map used to classify
	# additions/removals. Direct Coordinator callers retain the safe Index read path.
	var old_patches: Dictionary = old_patches_snapshot if use_batch_snapshot else old_patch_result.get("patches_by_stable_id", {})
	var candidate_patches: Dictionary = candidate_patch_result.get("patches_by_stable_id", {})
	var candidate_descriptors: Dictionary = candidate_descriptor_result.get("descriptors", {})
	var old_closure_descriptors: Dictionary = summary.get("old_closure_descriptors", {})
	var new_closure_descriptors: Dictionary = summary.get("new_closure_descriptors", {})
	var changed_seed_edge_keys: Array = summary.get("affected_edge_keys", [])
	var scoped_changed_edge_keys: Array[String] = _union_dictionary_keys(
		old_closure_descriptors,
		new_closure_descriptors
	)

	# A patch addition/removal with no adjacent Edge changes is an Index-only transaction.
	if changed_seed_edge_keys.is_empty():
		return _publish_and_finalize_index_only(plan_id, summary)

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var collider_prepare: Dictionary = _collider_manager.call(
		"prepare_partial_sync_transitions",
		candidate_descriptors,
		candidate_patches,
		changed_seed_edge_keys,
		profile_enabled
	)
	if profile_enabled:
		phase_profile["collider_prepare_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(collider_prepare.get("ok", false)):
		var prepare_cleanup: Dictionary = _abort_index_or_retain(plan_id, "collider_prepare_failed")
		if not bool(prepare_cleanup.get("ok", false)):
			return prepare_cleanup
		return {"ok": false, "error": "collider_prepare_failed:" + str(collider_prepare.get("error", "unknown"))}
	var collider_transaction_id: int = int(collider_prepare.get("transaction_id", -1))
	if collider_transaction_id <= 0:
		_store_pending("manual_recovery", plan_id, collider_transaction_id, -1, false, true, "collider_transaction_id_invalid")
		return {"ok": false, "error": "collider_transaction_id_invalid", "pending_retained": true}

	var manager_edges: Array[String] = _sorted_strings(collider_prepare.get("affected_edge_keys", []))
	var manager_junctions: Array[String] = _sorted_strings(collider_prepare.get("affected_junction_keys", []))
	var index_edges: Array[String] = _sorted_strings(summary.get("closure_edge_keys", []))
	var index_junctions: Array[String] = _sorted_strings(summary.get("closure_junction_keys", []))
	if manager_edges != index_edges or manager_junctions != index_junctions:
		var closure_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, -1, false, false, "index_collider_closure_mismatch"
		)
		if not bool(closure_cleanup.get("ok", false)):
			return closure_cleanup
		var closure_index_cleanup: Dictionary = _abort_index_or_retain(plan_id, "index_collider_closure_mismatch")
		if not bool(closure_index_cleanup.get("ok", false)):
			return closure_index_cleanup
		return {
			"ok": false,
			"error": "index_collider_closure_mismatch",
			"index_edge_keys": index_edges,
			"manager_edge_keys": manager_edges,
			"index_junction_keys": index_junctions,
			"manager_junction_keys": manager_junctions
		}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var scoped_prepare: Dictionary = _scoped_transaction.call(
		"prepare",
		old_closure_descriptors,
		new_closure_descriptors,
		old_patches,
		candidate_patches,
		scoped_changed_edge_keys
	)
	if profile_enabled:
		phase_profile["scoped_prepare_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(scoped_prepare.get("ok", false)):
		var scoped_prepare_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, -1, false, false, "scoped_prepare_failed"
		)
		if not bool(scoped_prepare_cleanup.get("ok", false)):
			return scoped_prepare_cleanup
		var scoped_index_cleanup: Dictionary = _abort_index_or_retain(plan_id, "scoped_prepare_failed")
		if not bool(scoped_index_cleanup.get("ok", false)):
			return scoped_index_cleanup
		return {"ok": false, "error": "scoped_prepare_failed:" + str(scoped_prepare.get("error", "unknown"))}
	var scoped_transaction_id: int = int(scoped_prepare.get("transaction_id", 0))
	if bool(scoped_prepare.get("noop", false)) or scoped_transaction_id <= 0:
		var noop_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, -1, false, false, "scoped_transaction_unexpected_noop"
		)
		if not bool(noop_cleanup.get("ok", false)):
			return noop_cleanup
		var noop_index_cleanup: Dictionary = _abort_index_or_retain(plan_id, "scoped_transaction_unexpected_noop")
		if not bool(noop_index_cleanup.get("ok", false)):
			return noop_index_cleanup
		return {"ok": false, "error": "scoped_transaction_unexpected_noop"}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var scoped_apply: Dictionary = _scoped_transaction.call("apply", scoped_transaction_id)
	if profile_enabled:
		phase_profile["scoped_apply_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(scoped_apply.get("ok", false)):
		if bool(_scoped_transaction.call("has_pending_transaction")):
			_store_pending(
				"rollback",
				plan_id,
				collider_transaction_id,
				scoped_transaction_id,
				false,
				true,
				str(scoped_apply.get("error", "scoped_apply_failed"))
			)
			return {"ok": false, "error": "scoped_apply_recovery_required", "pending_retained": true}
		var apply_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, -1, false, false, "scoped_apply_failed"
		)
		if not bool(apply_cleanup.get("ok", false)):
			return apply_cleanup
		var apply_index_cleanup: Dictionary = _abort_index_or_retain(plan_id, "scoped_apply_failed")
		if not bool(apply_index_cleanup.get("ok", false)):
			return apply_index_cleanup
		return {"ok": false, "error": "scoped_apply_failed:" + str(scoped_apply.get("error", "unknown"))}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var accepted: Dictionary = _collider_manager.call(
		"accept_scoped_neighbor_state_apply",
		collider_transaction_id,
		scoped_apply.get("endpoint_expectations", [])
	)
	if profile_enabled:
		phase_profile["collider_accept_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(accepted.get("ok", false)):
		var accept_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, scoped_transaction_id, false, true, "collider_accept_failed"
		)
		if not bool(accept_cleanup.get("ok", false)):
			return accept_cleanup
		var accept_rollback: Dictionary = _scoped_transaction.call("rollback", scoped_transaction_id)
		if not bool(accept_rollback.get("ok", false)):
			_store_pending("rollback", plan_id, collider_transaction_id, scoped_transaction_id, false, false, "scoped_accept_rollback_failed")
			return {"ok": false, "error": "collider_accept_failed_and_scoped_rollback_pending", "pending_retained": true}
		var accept_index_cleanup: Dictionary = _abort_index_or_retain(plan_id, "collider_accept_failed")
		if not bool(accept_index_cleanup.get("ok", false)):
			return accept_index_cleanup
		return {"ok": false, "error": "collider_accept_failed:" + str(accepted.get("error", "unknown"))}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var published: Dictionary = _index.call("publish_delta", plan_id)
	if profile_enabled:
		phase_profile["index_publish_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(published.get("ok", false)):
		var publish_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, scoped_transaction_id, false, true, "index_publish_failed"
		)
		if not bool(publish_cleanup.get("ok", false)):
			return publish_cleanup
		var publish_rollback: Dictionary = _scoped_transaction.call("rollback", scoped_transaction_id)
		if not bool(publish_rollback.get("ok", false)):
			_store_pending("rollback", plan_id, collider_transaction_id, scoped_transaction_id, false, false, "index_publish_rollback_failed")
			return {"ok": false, "error": "index_publish_failed_and_scoped_rollback_pending", "pending_retained": true}
		var publish_index_cleanup: Dictionary = _abort_index_or_retain(plan_id, "index_publish_failed")
		if not bool(publish_index_cleanup.get("ok", false)):
			return publish_index_cleanup
		return {"ok": false, "error": "index_publish_failed:" + str(published.get("error", "unknown"))}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var collider_commit: Dictionary = _collider_manager.call("commit_sync_transitions", collider_transaction_id)
	if profile_enabled:
		phase_profile["collider_commit_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(collider_commit.get("ok", false)):
		var commit_cleanup: Dictionary = _abort_collider_or_retain(
			plan_id, collider_transaction_id, scoped_transaction_id, true, true, "collider_commit_failed"
		)
		if not bool(commit_cleanup.get("ok", false)):
			return commit_cleanup
		var commit_rollback: Dictionary = _scoped_transaction.call("rollback", scoped_transaction_id)
		if not bool(commit_rollback.get("ok", false)):
			_store_pending("rollback", plan_id, collider_transaction_id, scoped_transaction_id, true, false, "collider_commit_rollback_pending")
			return {"ok": false, "error": "collider_commit_failed_and_rollback_pending", "pending_retained": true}
		var index_rollback: Dictionary = _index.call("rollback_published_delta", plan_id)
		if not bool(index_rollback.get("ok", false)):
			_store_pending("index_rollback", plan_id, collider_transaction_id, scoped_transaction_id, true, false, "index_rollback_failed")
			return {"ok": false, "error": "collider_commit_failed_and_index_rollback_pending", "pending_retained": true}
		return {"ok": false, "error": "collider_commit_failed:" + str(collider_commit.get("error", "unknown")), "index_rolled_back": true, "scoped_rolled_back": true}

	var committed_edges: Array[String] = _sorted_strings(collider_commit.get("affected_edge_keys", []))
	var committed_junctions: Array[String] = _sorted_strings(collider_commit.get("affected_junction_keys", []))
	if committed_edges != index_edges or committed_junctions != index_junctions:
		_store_pending("manual_recovery", plan_id, collider_transaction_id, scoped_transaction_id, true, false, "post_commit_closure_mismatch")
		return {
			"ok": false,
			"error": "post_commit_closure_mismatch",
			"pending_retained": true,
			"index_edge_keys": index_edges,
			"collider_edge_keys": committed_edges,
			"index_junction_keys": index_junctions,
			"collider_junction_keys": committed_junctions
		}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var scoped_finalize: Dictionary = _scoped_transaction.call("finalize", scoped_transaction_id)
	if profile_enabled:
		phase_profile["scoped_finalize_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(scoped_finalize.get("ok", false)):
		_store_pending("finalize", plan_id, collider_transaction_id, scoped_transaction_id, true, true, str(scoped_finalize.get("error", "scoped_finalize_failed")))
		return {"ok": false, "error": "scoped_finalize_pending", "pending_retained": true, "scoped": scoped_finalize, "collider": collider_commit}

	phase_started_usec = Time.get_ticks_usec() if profile_enabled else 0
	var index_finalize: Dictionary = _index.call("finalize_delta", plan_id)
	if profile_enabled:
		phase_profile["index_finalize_usec"] = Time.get_ticks_usec() - phase_started_usec
	if not bool(index_finalize.get("ok", false)):
		_store_pending("index_finalize", plan_id, collider_transaction_id, scoped_transaction_id, true, false, str(index_finalize.get("error", "index_finalize_failed")))
		return {"ok": false, "error": "index_finalize_pending", "pending_retained": true, "index": index_finalize, "collider": collider_commit}

	var success_result: Dictionary = {
		"ok": true,
		"finalized": true,
		"generation": int(index_finalize.get("generation", -1)),
		"summary": summary.duplicate(true),
		"collider": collider_commit,
		"scoped": scoped_finalize
	}
	return _attach_coordinator_profile(success_result, phase_profile, coordinator_started_usec, profile_enabled)


func _attach_coordinator_profile(result: Dictionary, phase_profile: Dictionary, started_usec: int, profile_enabled: bool) -> Dictionary:
	if not profile_enabled:
		return result
	var total_usec: int = Time.get_ticks_usec() - started_usec
	var measured_usec: int = 0
	for key in ["plan_delta_usec", "index_reservation_usec", "candidate_patch_map_usec", "candidate_descriptor_snapshot_usec", "collider_prepare_usec", "scoped_prepare_usec", "scoped_apply_usec", "collider_accept_usec", "index_publish_usec", "collider_commit_usec", "scoped_finalize_usec", "index_finalize_usec"]:
		measured_usec += int(phase_profile.get(key, 0))
	phase_profile["total_usec"] = total_usec
	phase_profile["unattributed_usec"] = total_usec - measured_usec
	result["coordinator_profile_usec"] = phase_profile.duplicate(true)
	return result


## Retries only the incomplete recovery/finalization phase. It never repeats a participant
## commit that has already succeeded.
func retry_pending() -> Dictionary:
	if _pending.is_empty():
		return {"ok": false, "error": "no_pending_coordinator_transaction"}
	var stage: String = str(_pending.get("stage", ""))
	var plan_id: String = str(_pending.get("plan_id", ""))
	var collider_transaction_id: int = int(_pending.get("collider_transaction_id", -1))
	var scoped_transaction_id: int = int(_pending.get("scoped_transaction_id", -1))
	if stage == "abort_collider":
		var collider_abort: Dictionary = _abort_collider_transaction(collider_transaction_id)
		if not bool(collider_abort.get("ok", false)):
			return {"ok": false, "error": "collider_abort_still_pending", "pending": collider_abort}
		var index_abort: Dictionary = _abort_index_plan(plan_id)
		if not bool(index_abort.get("ok", false)):
			_pending["stage"] = "index_abort"
			return {"ok": false, "error": "index_abort_still_pending", "pending": index_abort}
		_pending.clear()
		return {"ok": true, "aborted": true, "index": index_abort}
	if stage == "rollback":
		var collider_abort: Dictionary = _abort_collider_transaction(collider_transaction_id)
		if not bool(collider_abort.get("ok", false)):
			return {"ok": false, "error": "collider_abort_still_pending", "pending": collider_abort}
		var scoped_rollback: Dictionary = _scoped_transaction.call("rollback", scoped_transaction_id)
		if not bool(scoped_rollback.get("ok", false)):
			return {"ok": false, "error": "scoped_rollback_still_pending", "pending": scoped_rollback}
		var index_rollback: Dictionary
		if bool(_pending.get("index_published", false)):
			index_rollback = _index.call("rollback_published_delta", plan_id)
		else:
			index_rollback = _abort_index_plan(plan_id)
		if not bool(index_rollback.get("ok", false)):
			_pending["stage"] = "index_rollback" if bool(_pending.get("index_published", false)) else "index_abort"
			return {"ok": false, "error": "index_rollback_still_pending", "pending": index_rollback}
		_pending.clear()
		return {"ok": true, "rolled_back": true, "index": index_rollback, "scoped": scoped_rollback}
	if stage == "finalize":
		var scoped_finalize: Dictionary = _scoped_transaction.call("finalize", scoped_transaction_id)
		if not bool(scoped_finalize.get("ok", false)):
			return {"ok": false, "error": "scoped_finalize_still_pending", "pending": scoped_finalize}
		var index_finalize: Dictionary = _index.call("finalize_delta", plan_id)
		if not bool(index_finalize.get("ok", false)):
			_pending["stage"] = "index_finalize"
			return {"ok": false, "error": "index_finalize_still_pending", "pending": index_finalize}
		_pending.clear()
		return {"ok": true, "finalized": true, "generation": int(index_finalize.get("generation", -1))}
	if stage == "index_finalize":
		var retry_index_finalize: Dictionary = _index.call("finalize_delta", plan_id)
		if not bool(retry_index_finalize.get("ok", false)):
			return {"ok": false, "error": "index_finalize_still_pending", "pending": retry_index_finalize}
		_pending.clear()
		return {"ok": true, "finalized": true, "generation": int(retry_index_finalize.get("generation", -1))}
	if stage == "index_rollback":
		var retry_index_rollback: Dictionary = _index.call("rollback_published_delta", plan_id)
		if not bool(retry_index_rollback.get("ok", false)):
			return {"ok": false, "error": "index_rollback_still_pending", "pending": retry_index_rollback}
		_pending.clear()
		return {"ok": true, "rolled_back": true, "index": retry_index_rollback}
	if stage == "index_abort":
		var retry_index_abort: Dictionary = _abort_index_plan(plan_id)
		if not bool(retry_index_abort.get("ok", false)):
			return {"ok": false, "error": "index_abort_still_pending", "pending": retry_index_abort}
		_pending.clear()
		return {"ok": true, "aborted": true, "index": retry_index_abort}
	if stage == "manual_recovery":
		return {"ok": false, "error": "manual_recovery_required", "pending": _pending.duplicate(true)}
	return {"ok": false, "error": "unknown_coordinator_pending_stage", "stage": stage}


func _publish_and_finalize_index_only(plan_id: String, summary: Dictionary) -> Dictionary:
	var published: Dictionary = _index.call("publish_delta", plan_id)
	if not bool(published.get("ok", false)):
		var cleanup: Dictionary = _abort_index_or_retain(plan_id, "index_only_publish_failed")
		if not bool(cleanup.get("ok", false)):
			return cleanup
		return {"ok": false, "error": "index_only_publish_failed:" + str(published.get("error", "unknown"))}
	var finalized: Dictionary = _index.call("finalize_delta", plan_id)
	if not bool(finalized.get("ok", false)):
		_store_pending("index_finalize", plan_id, -1, -1, true, false, str(finalized.get("error", "index_finalize_failed")))
		return {"ok": false, "error": "index_only_finalize_pending", "pending_retained": true}
	return {"ok": true, "finalized": true, "index_only": true, "generation": int(finalized.get("generation", -1)), "summary": summary.duplicate(true)}


func _abort_collider_transaction(transaction_id: int) -> Dictionary:
	if not is_instance_valid(_collider_manager) or not _collider_manager.has_method("abort_sync_transitions"):
		return {"ok": false, "error": "collider_abort_participant_unavailable"}
	var result_value: Variant = _collider_manager.call("abort_sync_transitions", transaction_id)
	if not (result_value is Dictionary):
		return {"ok": false, "error": "invalid_collider_abort_result"}
	var result: Dictionary = result_value
	if bool(result.get("ok", false)):
		return result
	# Production commit failure paths may already abort and clear their staged transaction.
	# Treat an absent pending transaction as idempotent success; every other failure must
	# retain the coordinator snapshot so cleanup can be retried before another participant rolls back.
	if str(result.get("error", "")) == "no_pending_transaction":
		return {"ok": true, "already_aborted": true}
	return result


func _abort_collider_or_retain(
	plan_id: String,
	collider_transaction_id: int,
	scoped_transaction_id: int,
	index_published: bool,
	scoped_rollback_required: bool,
	error_code: String
) -> Dictionary:
	var abort_result: Dictionary = _abort_collider_transaction(collider_transaction_id)
	if bool(abort_result.get("ok", false)):
		return {"ok": true, "already_aborted": bool(abort_result.get("already_aborted", false))}
	if scoped_rollback_required:
		_store_pending("rollback", plan_id, collider_transaction_id, scoped_transaction_id, index_published, true, error_code)
	else:
		_store_pending("abort_collider", plan_id, collider_transaction_id, -1, index_published, true, error_code)
	return {"ok": false, "error": "collider_abort_pending", "pending_retained": true, "abort": abort_result}


func _abort_index_plan(plan_id: String) -> Dictionary:
	if plan_id.is_empty():
		return {"ok": false, "error": "index_plan_id_missing"}
	if bool(_index.call("has_pending_plan", plan_id)):
		var aborted: bool = bool(_index.call("abort_delta", plan_id))
		return {"ok": aborted, "aborted": aborted}
	var reserved_plan_id: String = str(_index.call("get_reserved_plan_id"))
	if reserved_plan_id.is_empty():
		return {"ok": true, "already_aborted": true}
	return {"ok": false, "error": "another_index_generation_reserved", "reserved_plan_id": reserved_plan_id}


func _abort_index_or_retain(plan_id: String, error_code: String) -> Dictionary:
	var result: Dictionary = _abort_index_plan(plan_id)
	if bool(result.get("ok", false)):
		return result
	_store_pending("index_abort", plan_id, -1, -1, false, false, error_code)
	return {"ok": false, "error": "index_abort_pending", "pending_retained": true, "index": result}


func _store_pending(
	stage: String,
	plan_id: String,
	collider_transaction_id: int,
	scoped_transaction_id: int,
	index_published: bool,
	collider_prepared: bool,
	error_code: String
) -> void:
	_pending = {
		"stage": stage,
		"plan_id": plan_id,
		"collider_transaction_id": collider_transaction_id,
		"scoped_transaction_id": scoped_transaction_id,
		"index_published": index_published,
		"collider_prepared": collider_prepared,
		"error": error_code
	}


func _participants_valid() -> bool:
	return (
		is_instance_valid(_index)
		and is_instance_valid(_scoped_transaction)
		and is_instance_valid(_collider_manager)
	)


func _union_dictionary_keys(first: Dictionary, second: Dictionary) -> Array[String]:
	var keys: Dictionary = {}
	for key_value in first.keys():
		keys[str(key_value)] = true
	for key_value in second.keys():
		keys[str(key_value)] = true
	return _sorted_strings(keys.keys())


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result
