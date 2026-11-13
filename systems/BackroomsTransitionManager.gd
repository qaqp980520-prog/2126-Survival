extends RefCounted
class_name BackroomsTransitionManager

## Coordinates the validated two-phase portal handoff and failure-safe return.
## Scene construction/activation remains owned by the production world controller.
const SessionScript = preload("res://systems/BackroomsLocationSession.gd")

enum TransitionState {
	IDLE,
	ENTRY_PREPARED,
	IN_BACKROOMS
}

var session: RefCounted
var state: int = TransitionState.IDLE
var last_error: String = ""

var _pending_director_instance_id: int = 0
var _pending_portal_id: int = 0
var _pending_preview: Dictionary = {}
var _pending_return_position: Vector3 = Vector3.ZERO
var _pending_entry_position: Vector3 = Vector3.ZERO
var _pending_world_seed: int = -1
var _pending_runtime: Object = null
var _pending_runtime_instance_id: int = 0
var _pending_runtime_payload: Dictionary = {}
var _active_runtime: Object = null
var _active_runtime_instance_id: int = 0
var _commit_runtime_authorized: bool = false

func _init(session_instance: RefCounted = null) -> void:
	session = session_instance if session_instance != null else SessionScript.new()
	if bool(session.call("is_active")):
		state = TransitionState.IN_BACKROOMS

## Prepare without consuming the portal or advancing its RNG.
## The caller may build a hidden destination runtime after receiving this result.
func prepare_portal_entry(
	director: RefCounted,
	portal_id: int,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO
) -> Dictionary:
	last_error = ""
	if state != TransitionState.IDLE or bool(session.call("is_active")):
		return _failure("transition_busy")
	if director == null or not is_instance_valid(director) or not director.has_method("preview_portal_entry"):
		return _failure("portal_director_unavailable")
	var preview: Variant = director.call("preview_portal_entry", portal_id)
	if not (preview is Dictionary) or not bool(preview.get("ok", false)) or str(preview.get("event", "")) != "prepared":
		return _failure(str(preview.get("reason", "portal_preview_rejected")) if preview is Dictionary else "portal_preview_invalid")
	if not bool(session.call("can_begin_from_portal_result", preview, return_position, source_world_seed, entry_position)):
		return _failure("session_preflight_rejected")
	_pending_director_instance_id = director.get_instance_id()
	_pending_portal_id = portal_id
	_pending_preview = preview.duplicate(true)
	_pending_return_position = return_position
	_pending_entry_position = entry_position
	_pending_world_seed = source_world_seed
	state = TransitionState.ENTRY_PREPARED
	return {
		"ok": true,
		"event": "prepared",
		"portal_id": portal_id,
		"destination_level": str(preview["destination_level"]),
		"position": preview["position"]
	}

## Prepare the hidden maze runtime before consuming the one-use portal.
## Existing prepared runtimes are rejected rather than silently overwritten.
func prepare_portal_entry_with_runtime(
	director: RefCounted,
	runtime: Object,
	portal_id: int,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO,
	cell_size: float = 8.0,
	stream_radius: int = 1
) -> Dictionary:
	var prepared: Dictionary = prepare_portal_entry(director, portal_id, return_position, source_world_seed, entry_position)
	if not bool(prepared.get("ok", false)):
		return prepared
	if runtime == null or not is_instance_valid(runtime):
		cancel_prepared_entry()
		return _failure("maze_runtime_unavailable")
	for method_name in ["prepare_destination", "to_save_dict", "is_prepared", "is_active", "deactivate_destination", "get_loaded_cell_count"]:
		if not runtime.has_method(method_name):
			cancel_prepared_entry()
			return _failure("maze_runtime_contract_unavailable")
	if bool(runtime.call("is_prepared")) or bool(runtime.call("is_active")):
		cancel_prepared_entry()
		return _failure("maze_runtime_not_empty")
	var derived_seed: int = int(session.call("derive_backrooms_seed", source_world_seed, portal_id))
	if derived_seed < 0:
		cancel_prepared_entry()
		return _failure("maze_runtime_seed_invalid")
	var build_value: Variant = runtime.call("prepare_destination", str(prepared["destination_level"]), derived_seed, entry_position, cell_size, stream_radius)
	if not (build_value is Dictionary) or not bool(build_value.get("ok", false)):
		if bool(runtime.call("is_prepared")):
			runtime.call("deactivate_destination")
		cancel_prepared_entry()
		return _failure(str(build_value.get("reason", "maze_runtime_prepare_failed")) if build_value is Dictionary else "maze_runtime_prepare_invalid")
	var payload_value: Variant = runtime.call("to_save_dict")
	if not bool(runtime.call("is_prepared")) or bool(runtime.call("is_active")) or not (payload_value is Dictionary) or payload_value.is_empty():
		runtime.call("deactivate_destination")
		cancel_prepared_entry()
		return _failure("maze_runtime_prepare_incomplete")
	var payload: Dictionary = payload_value.duplicate(true)
	if not bool(session.call("can_begin_from_portal_result", _pending_preview, return_position, source_world_seed, entry_position, payload)):
		runtime.call("deactivate_destination")
		cancel_prepared_entry()
		return _failure("maze_runtime_session_preflight_rejected")
	_pending_runtime = runtime
	_pending_runtime_instance_id = runtime.get_instance_id()
	_pending_runtime_payload = payload
	var result: Dictionary = prepared.duplicate(true)
	result["runtime_prepared"] = true
	result["loaded_cell_count"] = int(build_value.get("loaded_cell_count", 0))
	return result

## Commit only the exact prepared context. A stale/replaced portal is rejected
## before consumption. The director's own preview/consume parity remains the
## final destination guard.
func commit_portal_entry(
	director: RefCounted,
	portal_id: int,
	return_position: Vector3,
	source_world_seed: int,
	entry_position: Vector3 = Vector3.ZERO
) -> Dictionary:
	last_error = ""
	if state != TransitionState.ENTRY_PREPARED:
		return _failure("entry_not_prepared")
	if director == null or not is_instance_valid(director) or director.get_instance_id() != _pending_director_instance_id:
		return _failure("portal_director_changed", true)
	if bool(session.call("is_active")):
		return _failure("session_changed_after_prepare", true)
	if portal_id != _pending_portal_id or return_position != _pending_return_position or source_world_seed != _pending_world_seed or entry_position != _pending_entry_position:
		return _failure("prepared_entry_context_mismatch", true)
	var current_preview: Variant = director.call("preview_portal_entry", portal_id)
	if not (current_preview is Dictionary) or not _preview_matches(current_preview):
		return _failure("prepared_portal_is_stale", true)
	if not bool(session.call("can_begin_from_portal_result", current_preview, return_position, source_world_seed, entry_position)):
		return _failure("session_preflight_changed", true)
	# Snapshot the complete director contract before the only mutating operation.
	# If the session rejects the committed result, restore RNG, active portal,
	# serial and spawn countdown so a failed entry never loses its one-use portal.
	if not director.has_method("to_save_dict") or not director.has_method("load_save_dict"):
		return _failure("portal_director_rollback_contract_unavailable", true)
	var director_snapshot_value: Variant = director.call("to_save_dict")
	if not (director_snapshot_value is Dictionary) or director_snapshot_value.is_empty():
		return _failure("portal_director_snapshot_unavailable", true)
	var director_snapshot: Dictionary = director_snapshot_value.duplicate(true)
	# The Session is part of the same transaction as the one-use Director.
	# Require a complete save/restore contract before consuming the portal so a
	# partially mutating Session implementation can also be rolled back exactly.
	if session == null or not is_instance_valid(session) or not session.has_method("to_save_dict") or not session.has_method("load_save_dict"):
		return _failure("session_rollback_contract_unavailable", true)
	var session_snapshot_value: Variant = session.call("to_save_dict")
	if not (session_snapshot_value is Dictionary) or session_snapshot_value.is_empty():
		return _failure("session_snapshot_unavailable", true)
	var session_snapshot: Dictionary = session_snapshot_value.duplicate(true)
	var consumed: Variant = director.call("consume_portal", portal_id)
	if not (consumed is Dictionary) or not bool(consumed.get("ok", false)) or str(consumed.get("event", "")) != "entered":
		var consume_reason: String = str(consumed.get("reason", "portal_consumption_rejected")) if consumed is Dictionary else "portal_consumption_invalid"
		var consume_rollback_complete: bool = _restore_director_snapshot(director, director_snapshot)
		_clear_pending()
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = consume_reason
		return {
			"ok": false,
			"reason": last_error,
			"director_state_restored": consume_rollback_complete
		}
	if not bool(session.call("begin_from_portal_result", consumed, return_position, source_world_seed, entry_position)):
		var director_restored: bool = _restore_director_snapshot(director, director_snapshot)
		var session_restored: bool = _restore_session_snapshot(session_snapshot)
		_clear_pending()
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = "session_commit_rejected_after_portal_consumption"
		return {
			"ok": false,
			"reason": last_error,
			"director_state_restored": director_restored,
			"session_state_restored": session_restored,
			"rollback_complete": director_restored and session_restored
		}
	state = TransitionState.IN_BACKROOMS
	_clear_pending()
	var result: Dictionary = consumed.duplicate(true)
	result["session"] = session.call("to_save_dict")
	return result

func cancel_prepared_entry() -> bool:
	if state != TransitionState.ENTRY_PREPARED:
		return false
	_clear_pending()
	state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
	last_error = ""
	return true

## The callback must restore the actual SurfaceWorld and return a bool.
## A false result retains the complete Backrooms return context for retry.
func return_to_surface(restore_surface: Callable) -> Dictionary:
	last_error = ""
	if state != TransitionState.IN_BACKROOMS or not bool(session.call("is_active")):
		return _failure("backrooms_session_not_active")
	if not restore_surface.is_valid():
		return _failure("surface_restore_callback_invalid")
	if session == null or not is_instance_valid(session) or not session.has_method("to_save_dict") or not session.has_method("load_save_dict"):
		return _failure("session_rollback_contract_unavailable")
	var session_snapshot_value: Variant = session.call("to_save_dict")
	if not (session_snapshot_value is Dictionary) or session_snapshot_value.is_empty():
		return _failure("session_snapshot_unavailable")
	var session_snapshot: Dictionary = session_snapshot_value.duplicate(true)
	var return_context: Dictionary = session.call("get_return_context")
	if return_context.is_empty():
		return _failure("surface_return_context_missing")
	var restored: Variant = restore_surface.call(return_context.duplicate(true))
	if not (restored is bool) or not bool(restored):
		var callback_session_restored: bool = _restore_session_snapshot(session_snapshot)
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = "surface_restore_failed"
		return {
			"ok": false,
			"reason": last_error,
			"session_retained": bool(session.call("is_active")),
			"session_state_restored": callback_session_restored,
			"rollback_complete": callback_session_restored
		}
	var current_return_context: Variant = session.call("get_return_context")
	if not bool(session.call("is_active")) or current_return_context != return_context:
		var changed_session_restored: bool = _restore_session_snapshot(session_snapshot)
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = "session_changed_during_surface_restore"
		return {
			"ok": false,
			"reason": last_error,
			"surface_restored": true,
			"session_retained": bool(session.call("is_active")),
			"session_state_restored": changed_session_restored,
			"rollback_complete": changed_session_restored
		}
	var completed_value: Variant = session.call("complete_return")
	var completed: Dictionary = completed_value if completed_value is Dictionary else {}
	var expected_inactive_session: Dictionary = SessionScript.new().to_save_dict()
	var final_session_payload: Variant = session.call("to_save_dict")
	var final_return_context: Variant = session.call("get_return_context")
	var session_cleared: bool = (
		not bool(session.call("is_active"))
		and final_return_context is Dictionary
		and final_return_context.is_empty()
		and final_session_payload is Dictionary
		and final_session_payload == expected_inactive_session
	)
	if not bool(completed.get("ok", false)) or not session_cleared:
		var completed_session_restored: bool = _restore_session_snapshot(session_snapshot)
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = "session_return_commit_failed_after_surface_restore" if not bool(completed.get("ok", false)) else "session_return_commit_incomplete_after_surface_restore"
		return {
			"ok": false,
			"reason": last_error,
			"surface_restored": true,
			"session_retained": bool(session.call("is_active")),
			"session_state_restored": completed_session_restored,
			"rollback_complete": completed_session_restored
		}
	state = TransitionState.IDLE
	return {"ok": true, "event": "returned", "context": completed}

func get_state() -> int:
	return state

func get_state_name() -> String:
	match state:
		TransitionState.ENTRY_PREPARED:
			return "ENTRY_PREPARED"
		TransitionState.IN_BACKROOMS:
			return "IN_BACKROOMS"
		_:
			return "IDLE"

func get_session() -> RefCounted:
	return session

func get_session_save_dict() -> Dictionary:
	return session.call("to_save_dict")

func get_last_error() -> String:
	return last_error

func _restore_director_snapshot(director: RefCounted, snapshot: Dictionary) -> bool:
	if director == null or not is_instance_valid(director) or not director.has_method("load_save_dict"):
		return false
	var restored: Variant = director.call("load_save_dict", snapshot.duplicate(true))
	if not (restored is bool) or not bool(restored):
		return false
	var verified_snapshot: Variant = director.call("to_save_dict")
	return verified_snapshot is Dictionary and verified_snapshot == snapshot

func _restore_session_snapshot(snapshot: Dictionary) -> bool:
	if session == null or not is_instance_valid(session) or not session.has_method("load_save_dict") or not session.has_method("to_save_dict"):
		return false
	var restored: Variant = session.call("load_save_dict", snapshot.duplicate(true))
	if not (restored is bool) or not bool(restored):
		return false
	var verified_snapshot: Variant = session.call("to_save_dict")
	return verified_snapshot is Dictionary and verified_snapshot == snapshot

func _preview_matches(candidate: Dictionary) -> bool:
	if not bool(candidate.get("ok", false)) or str(candidate.get("event", "")) != "prepared":
		return false
	if int(candidate.get("portal_id", -1)) != _pending_portal_id:
		return false
	if str(candidate.get("destination_level", "")) != str(_pending_preview.get("destination_level", "")):
		return false
	if not candidate.has("position") or not _pending_preview.has("position"):
		return false
	return candidate["position"] == _pending_preview["position"]

func _clear_pending() -> void:
	_pending_director_instance_id = 0
	_pending_portal_id = 0
	_pending_preview.clear()
	_pending_return_position = Vector3.ZERO
	_pending_entry_position = Vector3.ZERO
	_pending_world_seed = -1

func _failure(reason: String, clear_pending: bool = false) -> Dictionary:
	last_error = reason
	if clear_pending:
		_clear_pending()
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
	return {"ok": false, "reason": reason}