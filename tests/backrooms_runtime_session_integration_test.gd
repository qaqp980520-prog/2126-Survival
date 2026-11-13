extends SceneTree

const DirectorScript = preload("res://systems/BackroomsPortalDirector.gd")
const ManagerScript = preload("res://systems/BackroomsTransitionManager.gd")
const SessionScript = preload("res://systems/BackroomsLocationSession.gd")
const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")

class MutatingRejectRuntimeSession extends RefCounted:
	var active: bool = false
	var level_id: String = ""
	var entry_portal_id: int = 0
	var surface_return_position: Vector3 = Vector3.ZERO
	var backrooms_position: Vector3 = Vector3.ZERO
	var surface_world_seed: int = 0
	var backrooms_seed: int = 0
	var maze_stream_state: Dictionary = {}
	var mutation_marker: String = "original"

	func is_active() -> bool:
		return active

	func derive_backrooms_seed(source_seed: int, portal_id: int) -> int:
		var mixed: int = source_seed * 1103515245 + portal_id * 12345 + 1013904223
		return posmod(mixed, 2147483648)

	func can_begin_from_portal_result(
		_portal_result: Dictionary,
		_return_position: Vector3,
		_source_world_seed: int,
		_entry_position: Vector3 = Vector3.ZERO,
		_maze_stream_payload: Dictionary = {}
	) -> bool:
		return not active

	func begin_from_portal_result(
		portal_result: Dictionary,
		return_position: Vector3,
		source_world_seed: int,
		entry_position: Vector3 = Vector3.ZERO,
		maze_stream_payload: Dictionary = {}
	) -> bool:
		active = true
		level_id = str(portal_result.get("destination_level", ""))
		entry_portal_id = int(portal_result.get("portal_id", 0))
		surface_return_position = return_position
		backrooms_position = entry_position
		surface_world_seed = source_world_seed
		backrooms_seed = derive_backrooms_seed(source_world_seed, entry_portal_id)
		maze_stream_state = maze_stream_payload.duplicate(true)
		mutation_marker = "mutated_then_rejected"
		return false

	func to_save_dict() -> Dictionary:
		return {
			"schema_version": 1,
			"active": active,
			"level_id": level_id,
			"entry_portal_id": entry_portal_id,
			"surface_return_position": [surface_return_position.x, surface_return_position.y, surface_return_position.z],
			"backrooms_position": [backrooms_position.x, backrooms_position.y, backrooms_position.z],
			"surface_world_seed": surface_world_seed,
			"backrooms_seed": backrooms_seed,
			"maze_stream_state": maze_stream_state.duplicate(true),
			"mutation_marker": mutation_marker
		}

	func load_save_dict(payload: Dictionary) -> bool:
		if int(payload.get("schema_version", 0)) != 1:
			return false
		var surface_value: Variant = payload.get("surface_return_position", null)
		var backrooms_value: Variant = payload.get("backrooms_position", null)
		var maze_value: Variant = payload.get("maze_stream_state", {})
		if not (surface_value is Array) or surface_value.size() != 3:
			return false
		if not (backrooms_value is Array) or backrooms_value.size() != 3 or not (maze_value is Dictionary):
			return false
		active = bool(payload.get("active", false))
		level_id = str(payload.get("level_id", ""))
		entry_portal_id = int(payload.get("entry_portal_id", 0))
		surface_return_position = Vector3(float(surface_value[0]), float(surface_value[1]), float(surface_value[2]))
		backrooms_position = Vector3(float(backrooms_value[0]), float(backrooms_value[1]), float(backrooms_value[2]))
		surface_world_seed = int(payload.get("surface_world_seed", 0))
		backrooms_seed = int(payload.get("backrooms_seed", 0))
		maze_stream_state = maze_value.duplicate(true)
		mutation_marker = str(payload.get("mutation_marker", ""))
		return true

var restore_result: bool = false
var restore_calls: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_runtime_entry_sync_save_and_return()
	_test_runtime_staging_failure_preserves_portal()
	_test_session_mutation_failure_restores_director_session_and_runtime()
	_test_stale_runtime_snapshot_cannot_consume_portal()
	_test_committed_entry_abort_restores_portal_session_and_runtime()
	if root.get_child_count() > 0:
		for child in root.get_children():
			child.queue_free()
	await process_frame
	print("Backrooms runtime session integration tests passed.")
	quit(0)

func _test_runtime_entry_sync_save_and_return() -> void:
	var director = DirectorScript.new(42, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var director_before: Dictionary = director.to_save_dict()
	var manager = ManagerScript.new()
	var runtime = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	var return_position := Vector3(12.5, 2.0, -8.25)
	var entry_position := Vector3.ZERO

	var prepared: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, return_position, 20261113, entry_position, 8.0, 1
	)
	assert(bool(prepared.get("ok", false)))
	assert(bool(prepared.get("runtime_prepared", false)))
	assert(int(prepared.get("loaded_cell_count", 0)) == 9)
	assert(director.to_save_dict() == director_before, "Runtime preparation must not consume the portal or advance RNG.")
	assert(bool(runtime.call("is_prepared")) and not bool(runtime.call("is_active")) and not runtime.visible)
	assert(not bool(manager.get_session().call("is_active")))

	var entered: Dictionary = manager.commit_portal_entry_with_runtime(
		director, runtime, portal_id, return_position, 20261113, entry_position
	)
	assert(bool(entered.get("ok", false)))
	assert(str(entered.get("event", "")) == "entered")
	assert(director.active_portal.is_empty())
	assert(bool(manager.get_session().call("is_active")))
	assert(manager.get_session().call("get_maze_stream_state") == runtime.call("to_save_dict"))
	assert(not bool(runtime.call("is_active")) and not runtime.visible, "Commit retains the runtime hidden until the world handoff completes.")
	var position_drift_before: Dictionary = manager.get_session_save_dict()
	assert(not bool(manager.get_session().call("set_backrooms_position", Vector3(8.0, 0.0, 0.0))), "Session cannot move into another cell without a matching runtime window update.")
	assert(manager.get_session_save_dict() == position_drift_before)

	assert(bool(manager.call("activate_prepared_runtime_after_handoff", runtime)))
	var bypass_return: Dictionary = manager.call("return_to_surface", Callable(self, "_restore_surface"))
	assert(not bool(bypass_return.get("ok", false)))
	assert(str(bypass_return.get("reason", "")) == "runtime_aware_return_required")
	assert(bool(runtime.call("is_active")) and runtime.visible)

	var shifted: Dictionary = manager.call("sync_backrooms_runtime", runtime, Vector3(8.0, 0.0, 0.0))
	assert(bool(shifted.get("ok", false)))
	assert(int(shifted.get("runtime", {}).get("load_count", -1)) == 3)
	assert(manager.get_session().call("get_maze_stream_state") == runtime.call("to_save_dict"))
	assert(manager.get_session().call("to_save_dict").get("backrooms_position", []) == [8.0, 0.0, 0.0])

	var saved_session: Dictionary = manager.get_session_save_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved_session))
	assert(parsed is Dictionary)
	var restored_session = SessionScript.new()
	assert(bool(restored_session.call("load_save_dict", parsed)))
	var restored_save_dict: Dictionary = restored_session.call("to_save_dict")
	if restored_save_dict != saved_session:
		for key in saved_session.keys():
			if restored_save_dict.get(key) != saved_session.get(key):
				print("DEBUG session JSON round-trip mismatch: key=", key, " saved=", saved_session.get(key), " restored=", restored_save_dict.get(key))
	assert(restored_save_dict == saved_session, "Session JSON round-trip must preserve the canonical save dictionary.")

	var legacy_payload: Dictionary = saved_session.duplicate(true)
	legacy_payload.erase("maze_stream_state")
	var legacy_session = SessionScript.new()
	assert(bool(legacy_session.call("load_save_dict", legacy_payload)), "Legacy schema-v1 active sessions without a maze payload remain loadable.")
	assert(legacy_session.call("get_maze_stream_state").is_empty())

	var tampered_payload: Dictionary = saved_session.duplicate(true)
	tampered_payload["maze_stream_state"]["world_seed"] = int(tampered_payload["maze_stream_state"]["world_seed"]) + 1
	var before_tampered_load: Dictionary = restored_session.call("to_save_dict")
	assert(not bool(restored_session.call("load_save_dict", tampered_payload)), "A nested maze seed mismatch is rejected.")
	assert(restored_session.call("to_save_dict") == before_tampered_load, "A rejected nested payload must leave the active Session unchanged.")

	var restored_manager = ManagerScript.new(restored_session)
	var restored_runtime = RuntimeScript.new()
	restored_runtime.force_metadata_only = true
	root.add_child(restored_runtime)
	var return_without_runtime: Dictionary = restored_manager.call("return_to_surface", Callable(self, "_restore_surface"))
	assert(not bool(return_without_runtime.get("ok", false)))
	assert(str(return_without_runtime.get("reason", "")) == "runtime_restore_required_before_return")
	assert(bool(restored_manager.call("restore_runtime_from_session", restored_runtime)))
	assert(bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")))
	assert(restored_runtime.call("to_save_dict") == restored_session.call("get_maze_stream_state"))
	assert(bool(restored_manager.call("activate_prepared_runtime_after_handoff", restored_runtime)), "Restored hidden runtime should activate after the world handoff.")

	restore_result = false
	restore_calls = 0
	var before_failed_return: Dictionary = restored_manager.get_session_save_dict()
	var failed_return: Dictionary = restored_manager.call(
		"return_to_surface_with_runtime",
		restored_runtime,
		Callable(self, "_restore_surface")
	)
	assert(not bool(failed_return.get("ok", false)))
	assert(bool(failed_return.get("rollback_complete", false)))
	assert(bool(failed_return.get("session_retained", false)))
	assert(restored_manager.get_state_name() == "IN_BACKROOMS")
	assert(restored_manager.get_session_save_dict() == before_failed_return)
	assert(bool(restored_runtime.call("is_active")))
	assert(restored_runtime.call("to_save_dict") == before_failed_return["maze_stream_state"])

	restore_result = true
	var returned: Dictionary = restored_manager.call(
		"return_to_surface_with_runtime",
		restored_runtime,
		Callable(self, "_restore_surface")
	)
	assert(bool(returned.get("ok", false)))
	assert(str(returned.get("event", "")) == "returned")
	assert(bool(returned.get("runtime_deactivated", false)))
	assert(restored_manager.get_state_name() == "IDLE")
	assert(not bool(restored_manager.get_session().call("is_active")))
	assert(not bool(restored_runtime.call("is_prepared")))
	assert(int(restored_runtime.call("get_loaded_cell_count")) == 0)
	assert(restore_calls == 2)

func _test_runtime_staging_failure_preserves_portal() -> void:
	var director = DirectorScript.new(51, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var director_before: Dictionary = director.to_save_dict()
	var manager = ManagerScript.new()
	var runtime = RuntimeScript.new()
	runtime.force_metadata_only = true
	runtime.set_cell_builder_for_testing(Callable(self, "_fail_cell_builder"))
	root.add_child(runtime)
	var prepared: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, Vector3(1.0, 2.0, 3.0), 51, Vector3.ZERO, 8.0, 1
	)
	assert(not bool(prepared.get("ok", false)))
	assert(manager.get_state_name() == "IDLE")
	assert(director.to_save_dict() == director_before, "Failed runtime staging must not consume the one-use portal.")
	assert(not bool(manager.get_session().call("is_active")))
	assert(not bool(runtime.call("is_prepared")) and int(runtime.call("get_loaded_cell_count")) == 0)

func _test_session_mutation_failure_restores_director_session_and_runtime() -> void:
	var director = DirectorScript.new(71, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var director_before: Dictionary = director.to_save_dict()
	var session = MutatingRejectRuntimeSession.new()
	var session_before: Dictionary = session.to_save_dict()
	var manager = ManagerScript.new(session)
	var runtime = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	var prepared: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, Vector3(9.0, 2.0, -4.0), 71, Vector3.ZERO, 8.0, 1
	)
	assert(bool(prepared.get("ok", false)))
	assert(bool(runtime.call("is_prepared")) and not bool(runtime.call("is_active")))
	var rejected: Dictionary = manager.commit_portal_entry_with_runtime(
		director, runtime, portal_id, Vector3(9.0, 2.0, -4.0), 71, Vector3.ZERO
	)
	assert(not bool(rejected.get("ok", false)))
	assert(str(rejected.get("reason", "")) == "session_commit_rejected_after_portal_consumption")
	assert(bool(rejected.get("director_state_restored", false)))
	assert(bool(rejected.get("session_state_restored", false)))
	assert(bool(rejected.get("runtime_state_restored", false)))
	assert(bool(rejected.get("rollback_complete", false)))
	assert(director.to_save_dict() == director_before)
	assert(session.to_save_dict() == session_before)
	assert(not session.is_active())
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(runtime.call("is_prepared")) and int(runtime.call("get_loaded_cell_count")) == 0)

func _test_stale_runtime_snapshot_cannot_consume_portal() -> void:
	var director = DirectorScript.new(61, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var director_before: Dictionary = director.to_save_dict()
	var manager = ManagerScript.new()
	var runtime = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	var prepared: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, Vector3(4.0, 2.0, 6.0), 61, Vector3.ZERO, 8.0, 1
	)
	assert(bool(prepared.get("ok", false)))
	var changed: Dictionary = runtime.call("sync_to_world_position", Vector3(8.0, 0.0, 0.0))
	assert(bool(changed.get("ok", false)))
	var rejected: Dictionary = manager.commit_portal_entry_with_runtime(
		director, runtime, portal_id, Vector3(4.0, 2.0, 6.0), 61, Vector3.ZERO
	)
	assert(not bool(rejected.get("ok", false)))
	assert(str(rejected.get("reason", "")) == "prepared_runtime_state_changed")
	assert(bool(rejected.get("rollback_complete", false)))
	assert(director.to_save_dict() == director_before, "A stale runtime snapshot must be rejected before portal consumption.")
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(manager.get_session().call("is_active")))
	assert(not bool(runtime.call("is_prepared")) and int(runtime.call("get_loaded_cell_count")) == 0)

func _test_committed_entry_abort_restores_portal_session_and_runtime() -> void:
	var director = DirectorScript.new(81, Rect2(0.0, 0.0, 1000.0, 1000.0), 40.0)
	var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
	assert(str(spawned.get("event", "")) == "spawned")
	var portal_id: int = int(spawned["portal"]["id"])
	var director_before: Dictionary = director.to_save_dict()
	var manager = ManagerScript.new()
	var runtime = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	var return_position := Vector3(18.0, 2.0, -7.0)
	var entry_position := Vector3(0.0, 1002.0, 0.0)
	var prepared: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, return_position, 81, entry_position, 8.0, 1
	)
	assert(bool(prepared.get("ok", false)))
	var committed: Dictionary = manager.commit_portal_entry_with_runtime(
		director, runtime, portal_id, return_position, 81, entry_position
	)
	assert(bool(committed.get("ok", false)))
	assert(manager.get_state_name() == "IN_BACKROOMS")
	assert(bool(manager.get_session().call("is_active")))
	assert(director.active_portal.is_empty())
	assert(bool(runtime.call("is_prepared")) and not bool(runtime.call("is_active")))
	var aborted: Dictionary = manager.call("abort_committed_entry", director, runtime)
	assert(bool(aborted.get("ok", false)))
	assert(bool(aborted.get("rollback_complete", false)))
	assert(director.to_save_dict() == director_before, "Aborting a committed but unhanded entry restores the exact one-use portal and RNG state.")
	assert(not bool(manager.get_session().call("is_active")))
	assert(manager.get_session_save_dict() == SessionScript.new().to_save_dict())
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(runtime.call("is_prepared")) and not bool(runtime.call("is_active")))
	assert(int(runtime.call("get_loaded_cell_count")) == 0)
	assert(runtime.call("to_save_dict").is_empty())
	var retry: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, return_position, 81, entry_position, 8.0, 1
	)
	assert(bool(retry.get("ok", false)), "The restored one-use portal can be prepared again after an aborted handoff.")
	assert(bool(manager.call("cancel_prepared_entry")))
	assert(director.to_save_dict() == director_before)
	assert(int(runtime.call("get_loaded_cell_count")) == 0)
	await process_frame
	if runtime.get_parent() == root:
		root.remove_child(runtime)
	runtime.free()

func _fail_cell_builder(_descriptor: Dictionary, _metadata_only: bool) -> Node3D:
	return null

func _restore_surface(context: Dictionary) -> bool:
	restore_calls += 1
	assert(context.has("surface_return_position"))
	assert(context.has("surface_world_seed"))
	assert(context.has("entry_portal_id"))
	return restore_result
