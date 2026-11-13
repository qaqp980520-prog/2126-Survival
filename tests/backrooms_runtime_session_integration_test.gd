extends SceneTree

const DirectorScript = preload("res://systems/BackroomsPortalDirector.gd")
const ManagerScript = preload("res://systems/BackroomsTransitionManager.gd")
const SessionScript = preload("res://systems/BackroomsLocationSession.gd")
const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")

var restore_result: bool = false
var restore_calls: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_runtime_entry_sync_save_and_return()
	_test_runtime_staging_failure_preserves_portal()
	_test_stale_runtime_snapshot_cannot_consume_portal()
	if get_root().get_child_count() > 0:
		for child in get_root().get_children():
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
	get_root().add_child(runtime)
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

	assert(bool(manager.call("activate_prepared_runtime_after_handoff", runtime)))
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
	assert(restored_session.call("to_save_dict") == saved_session)
	var restored_manager = ManagerScript.new(restored_session)
	var restored_runtime = RuntimeScript.new()
	restored_runtime.force_metadata_only = true
	get_root().add_child(restored_runtime)
	assert(bool(restored_manager.call("restore_runtime_from_session", restored_runtime)))
	assert(bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")))
	assert(restored_runtime.call("to_save_dict") == restored_session.call("get_maze_stream_state"))
	assert(bool(restored_manager.call("activate_prepared_runtime_after_handoff", restored_runtime)))

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
	get_root().add_child(runtime)
	var prepared: Dictionary = manager.prepare_portal_entry_with_runtime(
		director, runtime, portal_id, Vector3(1.0, 2.0, 3.0), 51, Vector3.ZERO, 8.0, 1
	)
	assert(not bool(prepared.get("ok", false)))
	assert(manager.get_state_name() == "IDLE")
	assert(director.to_save_dict() == director_before, "Failed runtime staging must not consume the one-use portal.")
	assert(not bool(manager.get_session().call("is_active")))
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
	get_root().add_child(runtime)
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
	assert(str(rejected.get("reason", "")) == "prepared_runtime_changed")
	assert(bool(rejected.get("rollback_complete", false)))
	assert(director.to_save_dict() == director_before, "A stale runtime snapshot must be rejected before portal consumption.")
	assert(manager.get_state_name() == "IDLE")
	assert(not bool(manager.get_session().call("is_active")))
	assert(not bool(runtime.call("is_prepared")) and int(runtime.call("get_loaded_cell_count")) == 0)

func _fail_cell_builder(_descriptor: Dictionary, _metadata_only: bool) -> Node3D:
	return null

func _restore_surface(context: Dictionary) -> bool:
	restore_calls += 1
	assert(context.has("surface_return_position"))
	assert(context.has("surface_world_seed"))
	assert(context.has("entry_portal_id"))
	return restore_result
