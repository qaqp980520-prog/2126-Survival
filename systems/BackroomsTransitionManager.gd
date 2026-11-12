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
		var session_commit_rollback_complete: bool = _restore_director_snapshot(director, director_snapshot)
		_clear_pending()
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = "session_commit_rejected_after_portal_consumption"
		return {
			"ok": false,
			"reason": last_error,
			"director_state_restored": session_commit_rollback_complete
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
	var return_context: Dictionary = session.call("get_return_context")
	if return_context.is_empty():
		return _failure("surface_return_context_missing")
	var restored: Variant = restore_surface.call(return_context.duplicate(true))
	if not (restored is bool) or not bool(restored):
		last_error = "surface_restore_failed"
		return {"ok": false, "reason": last_error, "session_retained": true}
	if not bool(session.call("is_active")) or session.call("get_return_context") != return_context:
		state = TransitionState.IN_BACKROOMS if bool(session.call("is_active")) else TransitionState.IDLE
		last_error = "session_changed_during_surface_restore"
		return {"ok": false, "reason": last_error, "session_retained": bool(session.call("is_active"))}
	var completed: Dictionary = session.call("complete_return")
	if not bool(completed.get("ok", false)):
		last_error = "session_return_commit_failed_after_surface_restore"
		return {"ok": false, "reason": last_error, "surface_restored": true, "session_retained": true}
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
	return restored is bool and bool(restored)

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