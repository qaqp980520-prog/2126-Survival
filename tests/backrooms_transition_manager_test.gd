extends SceneTree

const DirectorScript = preload("res://systems/BackroomsPortalDirector.gd")
const ManagerScript = preload("res://systems/BackroomsTransitionManager.gd")

class RejectingCommitSession extends RefCounted:
	func is_active() -> bool:
		return false

	func can_begin_from_portal_result(
		_portal_result: Dictionary,
		_return_position: Vector3,
		_source_world_seed: int,
		_entry_position: Vector3 = Vector3.ZERO
	) -> bool:
		return true

	func begin_from_portal_result(
		_portal_result: Dictionary,
		_return_position: Vector3,
		_source_world_seed: int,
		_entry_position: Vector3 = Vector3.ZERO
	) -> bool:
		return false

var _restore_result: bool = false
var _restore_calls: int = 0

func _initialize() -> void:
	_test_prepare_is_pure_and_return_is_retryable()
	_test_context_mismatch_and_cancel_preserve_portal()
	_test_external_session_change_prevents_portal_consumption()
	_test_stale_portal_is_not_consumed_by_manager()
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

func _test_session_commit_rejection_restores_consumed_portal() -> void:
	var director = DirectorScript.new(123, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var manager = ManagerScript.new(RejectingCommitSession.new())
	var return_position := Vector3(9.0, 2.0, -4.0)
	var director_before: Dictionary = director.to_save_dict()

	var prepared: Dictionary = manager.prepare_portal_entry(director, portal_id, return_position, 123)
	assert(bool(prepared.get("ok", false)))
	var rejected: Dictionary = manager.commit_portal_entry(director, portal_id, return_position, 123)

	assert(not bool(rejected.get("ok", false)))
	assert(str(rejected.get("reason", "")) == "session_commit_rejected_after_portal_consumption")
	assert(bool(rejected.get("director_state_restored", false)), "The consumed portal must be restored when the session rejects commit.")
	assert(director.to_save_dict() == director_before, "Rollback must restore the exact RNG, spawn timer, serial and active portal.")
	assert(not director.active_portal.is_empty(), "The one-use portal must remain available after failed session commit.")
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(manager.get_session().call("is_active")))

func _restore_surface(context: Dictionary) -> bool:
	_restore_calls += 1
	assert(context.has("surface_return_position"))
	assert(context.has("surface_world_seed"))
	assert(context.has("entry_portal_id"))
	return _restore_result