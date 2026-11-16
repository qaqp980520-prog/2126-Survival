extends SceneTree

const DirectorScript = preload("res://systems/BackroomsPortalDirector.gd")
const ManagerScript = preload("res://systems/BackroomsTransitionManager.gd")

class RejectingCommitSession extends RefCounted:
	var active: bool = false
	var level_id: String = ""
	var entry_portal_id: int = 0
	var surface_return_position: Vector3 = Vector3.ZERO
	var mutation_marker: String = "original"

	func is_active() -> bool:
		return active

	func can_begin_from_portal_result(
		_portal_result: Dictionary,
		_return_position: Vector3,
		_source_world_seed: int,
		_entry_position: Vector3 = Vector3.ZERO
	) -> bool:
		return true

	func begin_from_portal_result(
		portal_result: Dictionary,
		return_position: Vector3,
		_source_world_seed: int,
		_entry_position: Vector3 = Vector3.ZERO
	) -> bool:
		# Simulate a future Session implementation that mutates several fields
		# before discovering a late commit failure.
		active = true
		level_id = str(portal_result.get("destination_level", ""))
		entry_portal_id = int(portal_result.get("portal_id", 0))
		surface_return_position = return_position
		mutation_marker = "mutated_then_rejected"
		return false

	func to_save_dict() -> Dictionary:
		return {
			"schema_version": 1,
			"active": active,
			"level_id": level_id,
			"entry_portal_id": entry_portal_id,
			"surface_return_position": [
				surface_return_position.x,
				surface_return_position.y,
				surface_return_position.z
			],
			"mutation_marker": mutation_marker
		}

	func load_save_dict(payload: Dictionary) -> bool:
		if int(payload.get("schema_version", 0)) != 1:
			return false
		var position_value: Variant = payload.get("surface_return_position", null)
		if not (position_value is Array) or position_value.size() != 3:
			return false
		active = bool(payload.get("active", false))
		level_id = str(payload.get("level_id", ""))
		entry_portal_id = int(payload.get("entry_portal_id", 0))
		surface_return_position = Vector3(
			float(position_value[0]),
			float(position_value[1]),
			float(position_value[2])
		)
		mutation_marker = str(payload.get("mutation_marker", ""))
		return true

class NonRollbackSession extends RefCounted:
	func is_active() -> bool:
		return false

	func can_begin_from_portal_result(
		_portal_result: Dictionary,
		_return_position: Vector3,
		_source_world_seed: int,
		_entry_position: Vector3 = Vector3.ZERO
	) -> bool:
		return true

class MutatingRejectingDirector extends RefCounted:
	var state: Dictionary = {
		"rng_state": "before",
		"portal_serial": 7,
		"next_spawn_in": 52.5,
		"active_portal": {"id": 7, "position": [12.0, 0.0]}
	}

	func preview_portal_entry(portal_id: int) -> Dictionary:
		if int(state["active_portal"].get("id", -1)) != portal_id:
			return {"ok": false, "reason": "portal_not_active"}
		return {
			"ok": true,
			"event": "prepared",
			"portal_id": portal_id,
			"position": Vector2(12.0, 0.0),
			"destination_level": "Level 2"
		}

	func consume_portal(_portal_id: int) -> Dictionary:
		state["rng_state"] = "mutated"
		state["portal_serial"] = 8
		state["next_spawn_in"] = 5.0
		state["active_portal"] = {}
		return {"ok": false, "reason": "injected_consume_failure"}

	func to_save_dict() -> Dictionary:
		return state.duplicate(true)

	func load_save_dict(payload: Dictionary) -> bool:
		state = payload.duplicate(true)
		return true

var _restore_result: bool = false
var _restore_calls: int = 0

func _initialize() -> void:
	_test_prepare_is_pure_and_return_is_retryable()
	_test_context_mismatch_and_cancel_preserve_portal()
	_test_external_session_change_prevents_portal_consumption()
	_test_stale_portal_is_not_consumed_by_manager()
	_test_rejected_consume_restores_director_snapshot()
	_test_session_rollback_contract_is_required_before_consumption()
	_test_session_commit_rejection_restores_consumed_portal()
	print("Backrooms transition manager tests passed.")
	quit(0)

func _test_prepare_is_pure_and_return_is_retryable() -> void:
	var director = DirectorScript.new(42, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var manager = ManagerScript.new()
	var return_position := Vector3(12.5, 2.0, -8.25)
	var entry_position := Vector3(3.0, 0.0, 5.0)
	var before_prepare: Dictionary = director.to_save_dict()

	var prepared: Dictionary = manager.prepare_portal_entry(director, portal_id, return_position, 20261112, entry_position)
	assert(bool(prepared.get("ok", false)))
	assert(str(prepared.get("event", "")) == "prepared")
	assert(manager.get_state_name() == "ENTRY_PREPARED")
	assert(director.to_save_dict() == before_prepare, "Preparing an entry must not consume the portal or advance RNG.")
	assert(not bool(manager.prepare_portal_entry(director, portal_id, return_position, 20261112, entry_position).get("ok", false)))

	var entered: Dictionary = manager.commit_portal_entry(director, portal_id, return_position, 20261112, entry_position)
	assert(bool(entered.get("ok", false)))
	assert(str(entered.get("event", "")) == "entered")
	assert(str(entered.get("destination_level", "")) == str(prepared["destination_level"]))
	assert(manager.get_state_name() == "IN_BACKROOMS")
	assert(bool(manager.get_session().call("is_active")))
	assert(director.active_portal.is_empty(), "Commit consumes the one-use portal exactly once.")
	assert(entered.get("session", {}) == manager.get_session_save_dict())

	var session_snapshot: Dictionary = manager.get_session_save_dict()
	_restore_result = false
	_restore_calls = 0
	var failed_return: Dictionary = manager.return_to_surface(Callable(self, "_restore_surface"))
	assert(not bool(failed_return.get("ok", false)))
	assert(bool(failed_return.get("session_retained", false)))
	assert(manager.get_state_name() == "IN_BACKROOMS")
	assert(manager.get_session_save_dict() == session_snapshot, "Failed surface restoration must retain the exact return context.")

	_restore_result = true
	var successful_return: Dictionary = manager.return_to_surface(Callable(self, "_restore_surface"))
	assert(bool(successful_return.get("ok", false)))
	assert(str(successful_return.get("event", "")) == "returned")
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(manager.get_session().call("is_active")))
	assert(_restore_calls == 2, "Return callback is retried without losing the session.")

func _test_context_mismatch_and_cancel_preserve_portal() -> void:
	var director = DirectorScript.new(77, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var manager = ManagerScript.new()
	var return_position := Vector3(1.0, 2.0, 3.0)
	var entry_position := Vector3.ZERO
	var before: Dictionary = director.to_save_dict()
	assert(bool(manager.prepare_portal_entry(director, portal_id, return_position, 77, entry_position).get("ok", false)))
	var mismatched: Dictionary = manager.commit_portal_entry(director, portal_id, return_position + Vector3(1.0, 0.0, 0.0), 77, entry_position)
	assert(not bool(mismatched.get("ok", false)))
	assert(str(mismatched.get("reason", "")) == "prepared_entry_context_mismatch")
	assert(manager.get_state_name() == "IDLE")
	assert(director.to_save_dict() == before, "A mismatched commit must leave the portal and RNG untouched.")

	assert(bool(manager.prepare_portal_entry(director, portal_id, return_position, 77, entry_position).get("ok", false)))
	assert(manager.cancel_prepared_entry())
	assert(manager.get_state_name() == "IDLE")
	assert(director.to_save_dict() == before, "Cancelling a prepared entry must not mutate the director.")

func _test_external_session_change_prevents_portal_consumption() -> void:
	var director = DirectorScript.new(99, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var manager = ManagerScript.new()
	var return_position := Vector3(4.0, 2.0, 6.0)
	assert(bool(manager.prepare_portal_entry(director, portal_id, return_position, 99).get("ok", false)))
	assert(bool(manager.get_session().call("begin_transition", "Level 2", 91, Vector3(7.0, 1.0, 8.0), 99)))
	var before_commit: Dictionary = director.to_save_dict()
	var commit: Dictionary = manager.commit_portal_entry(director, portal_id, return_position, 99)
	assert(not bool(commit.get("ok", false)))
	assert(str(commit.get("reason", "")) == "session_changed_after_prepare")
	assert(manager.get_state_name() == "IN_BACKROOMS")
	assert(director.to_save_dict() == before_commit, "A session changed after prepare must prevent one-use portal consumption.")

func _test_stale_portal_is_not_consumed_by_manager() -> void:
	var director = DirectorScript.new(88, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var manager = ManagerScript.new()
	assert(bool(manager.prepare_portal_entry(director, portal_id, Vector3(1.0, 2.0, 3.0), 88).get("ok", false)))
	assert(bool(director.consume_portal(portal_id).get("ok", false)), "Simulate another owner consuming the portal after prepare.")
	var after_external_consume: Dictionary = director.to_save_dict()
	var commit: Dictionary = manager.commit_portal_entry(director, portal_id, Vector3(1.0, 2.0, 3.0), 88)
	assert(not bool(commit.get("ok", false)))
	assert(str(commit.get("reason", "")) == "prepared_portal_is_stale")
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(manager.get_session().call("is_active")))
	assert(director.to_save_dict() == after_external_consume, "Stale manager commit must not mutate director state.")

func _test_rejected_consume_restores_director_snapshot() -> void:
	var director = MutatingRejectingDirector.new()
	var manager = ManagerScript.new()
	var portal_id: int = 7
	var return_position := Vector3(2.0, 1.0, 4.0)
	var director_before: Dictionary = director.to_save_dict()

	var prepared: Dictionary = manager.prepare_portal_entry(director, portal_id, return_position, 20261112)
	assert(bool(prepared.get("ok", false)))
	var rejected: Dictionary = manager.commit_portal_entry(director, portal_id, return_position, 20261112)

	assert(not bool(rejected.get("ok", false)))
	assert(str(rejected.get("reason", "")) == "injected_consume_failure")
	assert(bool(rejected.get("director_state_restored", false)), "A rejected consume must restore the Director snapshot.")
	assert(director.to_save_dict() == director_before, "A mutating rejected consume must restore RNG, serial, countdown and active portal.")
	assert(manager.get_state_name() == "IDLE")


func _test_session_rollback_contract_is_required_before_consumption() -> void:
	var director = DirectorScript.new(122, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var manager = ManagerScript.new(NonRollbackSession.new())
	var before: Dictionary = director.to_save_dict()
	assert(bool(manager.prepare_portal_entry(director, portal_id, Vector3(8.0, 2.0, -3.0), 122).get("ok", false)))
	var rejected: Dictionary = manager.commit_portal_entry(director, portal_id, Vector3(8.0, 2.0, -3.0), 122)
	assert(not bool(rejected.get("ok", false)))
	assert(str(rejected.get("reason", "")) == "session_rollback_contract_unavailable")
	assert(director.to_save_dict() == before, "A session without snapshot support must be rejected before portal consumption.")
	assert(not director.active_portal.is_empty())
	assert(manager.get_state_name() == "IDLE")


func _test_session_commit_rejection_restores_consumed_portal() -> void:
	var director = DirectorScript.new(123, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var rejecting_session = RejectingCommitSession.new()
	var session_before: Dictionary = rejecting_session.to_save_dict()
	var manager = ManagerScript.new(rejecting_session)
	var return_position := Vector3(9.0, 2.0, -4.0)
	var director_before: Dictionary = director.to_save_dict()

	var prepared: Dictionary = manager.prepare_portal_entry(director, portal_id, return_position, 123)
	assert(bool(prepared.get("ok", false)))
	var rejected: Dictionary = manager.commit_portal_entry(director, portal_id, return_position, 123)

	assert(not bool(rejected.get("ok", false)))
	assert(str(rejected.get("reason", "")) == "session_commit_rejected_after_portal_consumption")
	assert(bool(rejected.get("director_state_restored", false)), "The consumed portal must be restored when the session rejects commit.")
	assert(bool(rejected.get("session_state_restored", false)), "The partially mutated session must be restored.")
	assert(bool(rejected.get("rollback_complete", false)), "Both transaction participants must be restored and verified.")
	assert(director.to_save_dict() == director_before, "Rollback must restore the exact RNG, spawn timer, serial and active portal.")
	assert(not director.active_portal.is_empty(), "The one-use portal must remain available after failed session commit.")
	assert(manager.get_session().call("to_save_dict") == session_before, "Rollback must restore every Session field to the pre-commit snapshot.")
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(manager.get_session().call("is_active")))

func _restore_surface(context: Dictionary) -> bool:
	_restore_calls += 1
	assert(context.has("surface_return_position"))
	assert(context.has("surface_world_seed"))
	assert(context.has("entry_portal_id"))
	return _restore_result