extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const FileStoreScript = preload("res://systems/WorldEnvelopeFileStore.gd")
const SAVE_PATH: String = "user://run240_surface_world_envelope.json"
const BACKROOMS_SAVE_PATH: String = "user://run240_backrooms_world_envelope.json"
const FAIL_CLOSED_PATH: String = "user://run240_fail_closed_fallback.json"

class IncompleteRollbackProbe extends RefCounted:
	var restore_calls: Array[Dictionary] = []
	var last_report: Dictionary = {}

	func restore(payload: Dictionary, _now_unix: int = -1) -> bool:
		restore_calls.append(payload.duplicate(true))
		last_report = {"phase": "surface_restore", "rollback_complete": false}
		return false

	func get_last_report() -> Dictionary:
		return last_report.duplicate(true)

var failures: Array[String] = []
var source_world: Node3D
var restored_world: Node3D
var watchdog: Timer


func _initialize() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 120.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	call_deferred("_run")


func _run() -> void:
	_cleanup_save_paths()
	source_world = WorldScene.instantiate() as Node3D
	_expect(source_world != null, "production SurfaceWorld scene instantiates")
	if source_world == null:
		_finish(1)
		return
	root.add_child(source_world)
	await process_frame

	var player: CharacterBody3D = source_world.get("player") as CharacterBody3D
	var bridge: Node = source_world.get("inventory_bridge") as Node
	_expect(player != null and bridge != null, "production player and inventory bridge are available")
	if player == null or bridge == null:
		_finish(1)
		return

	var now: int = int(Time.get_unix_time_from_system())
	_expect(bool(source_world.call("debug_move_player_to", Vector3(2.0, 2.0, 3.0), now)), "move the production player to the first save position")
	_expect(bool(bridge.call("collect_world_item", "berries", 2)), "collect the first inventory snapshot")
	_expect(bool(source_world.call("save_game", SAVE_PATH)), "production SurfaceWorld writes its combined envelope to a real user:// file")
	var first_primary: Dictionary = _read_dictionary(SAVE_PATH)
	_expect(str(first_primary.get("active_location", "")) == "surface", "file contains the canonical surface location")
	_expect(not FileAccess.file_exists(SAVE_PATH + ".bak"), "first save does not invent a backup before a previous primary exists")

	_expect(bool(source_world.call("debug_move_player_to", Vector3(12.0, 2.0, 13.0), now + 1)), "move the player before the second save")
	_expect(bool(bridge.call("collect_world_item", "berries", 3)), "mutate inventory before the second save")
	_expect(bool(source_world.call("save_game", SAVE_PATH)), "second save replaces the primary atomically")
	var second_primary: Dictionary = _read_dictionary(SAVE_PATH)
	var first_backup: Dictionary = _read_dictionary(SAVE_PATH + ".bak")
	_expect(first_backup == first_primary, "second save retains the exact previous primary as .bak")
	_expect(second_primary != first_primary, "second save installs a distinct current primary")

	# Corrupt JSON must recover from the retained backup without losing the bad bytes.
	var corrupt_bytes: String = "{broken-primary-json"
	_expect(_write_text(SAVE_PATH, corrupt_bytes), "write a malformed primary fixture")
	_expect(bool(source_world.call("debug_move_player_to", Vector3(22.0, 2.0, 23.0), now + 2)), "mutate player position before corrupt-primary recovery")
	_expect(bool(bridge.call("collect_world_item", "berries", 4)), "mutate inventory before corrupt-primary recovery")
	_expect(bool(source_world.call("load_game", SAVE_PATH)), "load_game falls back to the valid backup after malformed primary JSON")
	_expect(player.global_position.is_equal_approx(Vector3(2.0, 2.0, 3.0)), "corrupt-primary fallback restores the backup player position")
	_expect(int(bridge.call("get_item_count", "berries")) == 2, "corrupt-primary fallback restores the backup inventory")
	_expect(FileAccess.file_exists(SAVE_PATH + ".corrupt"), "malformed primary is preserved under a diagnostic suffix")
	_expect(FileAccess.get_file_as_string(SAVE_PATH + ".corrupt") == corrupt_bytes, "diagnostic file preserves the exact malformed primary bytes")
	_expect(_read_dictionary(SAVE_PATH) == first_primary, "backup recovery repairs the primary with the validated backup")
	_expect(_read_dictionary(SAVE_PATH + ".bak") == first_primary, "last-known-good backup remains available after recovery")

	# A syntactically valid but unsupported envelope must also fall back.
	_expect(bool(source_world.call("debug_move_player_to", Vector3(32.0, 2.0, 33.0), now + 3)), "move the player before semantic-invalid recovery")
	_expect(bool(bridge.call("collect_world_item", "berries", 1)), "mutate inventory before semantic-invalid recovery")
	_expect(bool(source_world.call("save_game", SAVE_PATH)), "write a new primary while retaining the previous good save")
	var semantic_invalid: Dictionary = _read_dictionary(SAVE_PATH)
	semantic_invalid["schema_version"] = 999
	var semantic_invalid_text: String = JSON.stringify(semantic_invalid, "", true, true)
	_expect(_write_text(SAVE_PATH, semantic_invalid_text), "write a valid JSON dictionary with an unsupported envelope schema")
	_expect(bool(source_world.call("debug_move_player_to", Vector3(42.0, 2.0, 43.0), now + 4)), "mutate player position before semantic-invalid fallback")
	_expect(bool(source_world.call("load_game", SAVE_PATH)), "load_game falls back when primary JSON is valid but envelope validation fails")
	_expect(player.global_position.is_equal_approx(Vector3(2.0, 2.0, 3.0)), "semantic-invalid fallback restores the previous good position")
	_expect(int(bridge.call("get_item_count", "berries")) == 2, "semantic-invalid fallback restores the previous good inventory")
	_expect(FileAccess.file_exists(SAVE_PATH + ".corrupt.1"), "second invalid primary is preserved without overwriting the first diagnostic")
	_expect(FileAccess.get_file_as_string(SAVE_PATH + ".corrupt.1") == semantic_invalid_text, "second diagnostic preserves the exact semantic-invalid JSON")
	_expect(_read_dictionary(SAVE_PATH) == first_primary, "semantic-invalid fallback repairs the primary file")

	# Missing-primary recovery must keep the backup until the new primary is verified.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_expect(not FileAccess.file_exists(SAVE_PATH), "remove the primary to simulate an interrupted save")
	_expect(bool(source_world.call("debug_move_player_to", Vector3(52.0, 2.0, 53.0), now + 5)), "mutate the world before missing-primary recovery")
	_expect(bool(source_world.call("load_game", SAVE_PATH)), "load_game restores from a valid backup when the primary is missing")
	_expect(_read_dictionary(SAVE_PATH) == first_primary, "missing-primary recovery promotes the backup to a verified primary")
	_expect(_read_dictionary(SAVE_PATH + ".bak") == first_primary, "missing-primary recovery retains the backup until a later successful save")

	# A failed restore with an incomplete rollback must not even attempt the backup.
	_expect(_write_text(FAIL_CLOSED_PATH, JSON.stringify({"schema_version": 1, "marker": "primary"})), "write the primary fixture for fail-closed fallback")
	_expect(_write_text(FAIL_CLOSED_PATH + ".bak", JSON.stringify({"schema_version": 1, "marker": "backup"})), "write a valid-looking backup fixture for fail-closed fallback")
	var incomplete_probe := IncompleteRollbackProbe.new()
	var file_store: RefCounted = FileStoreScript.new()
	var fail_closed_loaded: bool = bool(file_store.call(
		"load_with_backup",
		FAIL_CLOSED_PATH,
		Callable(incomplete_probe, "restore"),
		Callable(incomplete_probe, "get_last_report"),
		now + 6
	))
	_expect(not fail_closed_loaded, "file store rejects primary restore when rollback is incomplete")
	_expect(incomplete_probe.restore_calls.size() == 1, "incomplete rollback blocks any attempt to apply the backup")
	_expect(incomplete_probe.restore_calls.size() == 1 and str(incomplete_probe.restore_calls[0].get("marker", "")) == "primary", "only the primary payload reaches the failing restore callback")

	# A temporary-path obstruction must never modify the current primary bytes.
	var primary_before_obstruction: String = FileAccess.get_file_as_string(SAVE_PATH)
	var temporary_path: String = SAVE_PATH + ".tmp"
	var temporary_absolute: String = ProjectSettings.globalize_path(temporary_path)
	var make_directory_error: Error = DirAccess.make_dir_absolute(temporary_absolute)
	_expect(make_directory_error == OK or DirAccess.dir_exists_absolute(temporary_absolute), "create a directory obstruction at the temporary save path")
	_expect(bool(source_world.call("debug_move_player_to", Vector3(62.0, 2.0, 63.0), now + 6)), "mutate the live world before testing atomic-write obstruction")
	_expect(not bool(source_world.call("save_game", SAVE_PATH)), "atomic writer rejects a directory obstructing the temporary path")
	_expect(FileAccess.get_file_as_string(SAVE_PATH) == primary_before_obstruction, "failed atomic write preserves the existing primary bytes")
	if DirAccess.dir_exists_absolute(temporary_absolute):
		DirAccess.remove_absolute(temporary_absolute)

	# The production file API must also persist and restore an active Backrooms visit.
	var director: RefCounted = source_world.get("backrooms_portal_director") as RefCounted
	_expect(director != null, "production portal director is available for the Backrooms file round-trip")
	if director == null:
		_finish(1)
		return
	director.set("next_spawn_in", 0.01)
	source_world.call("_process", 0.02)
	var portal_data: Variant = director.get("active_portal")
	_expect(portal_data is Dictionary and not portal_data.is_empty(), "production portal director spawns a portal for the file round-trip")
	if not (portal_data is Dictionary) or portal_data.is_empty():
		_finish(1)
		return
	var portal_position_value: Variant = portal_data.get("position", null)
	_expect(portal_position_value is Vector2, "spawned portal exposes a valid world position")
	if not (portal_position_value is Vector2):
		_finish(1)
		return
	var portal_position: Vector2 = portal_position_value
	_expect(bool(source_world.call("debug_move_player_to", Vector3(portal_position.x, 2.0, portal_position.y + 2.0), now + 7)), "stream the production player to the portal's owning surface window")
	await process_frame
	var portal: Area3D = source_world.get("backrooms_portal_visual") as Area3D
	_expect(portal != null and bool(portal.call("interact", player)), "production portal accepts the nearby player")
	if portal == null:
		_finish(1)
		return
	var entry: Dictionary = source_world.call("enter_backrooms_from_portal", int(portal.get("portal_id")))
	_expect(bool(entry.get("ok", false)), "production SurfaceWorld completes a real Backrooms entry before saving")
	if not bool(entry.get("ok", false)):
		_finish(1)
		return
	player.global_position += Vector3(8.0, 0.0, 0.0)
	_expect(bool(source_world.call("save_game", BACKROOMS_SAVE_PATH)), "F5-equivalent production API writes an active Backrooms envelope to disk")
	var backrooms_payload: Dictionary = _read_dictionary(BACKROOMS_SAVE_PATH)
	_expect(str(backrooms_payload.get("active_location", "")) == "backrooms", "Backrooms file records the active Backrooms location")
	_expect(not backrooms_payload.get("backrooms_runtime", {}).is_empty(), "Backrooms file contains the live maze runtime stream payload")

	restored_world = WorldScene.instantiate() as Node3D
	_expect(restored_world != null, "fresh production SurfaceWorld instance is available for file loading")
	if restored_world == null:
		_finish(1)
		return
	root.add_child(restored_world)
	await process_frame
	var backrooms_file_loaded: bool = bool(restored_world.call("load_game", BACKROOMS_SAVE_PATH))
	_expect(backrooms_file_loaded, "F9-equivalent production API restores the active Backrooms file into a fresh world")
	if not backrooms_file_loaded:
		_finish(1)
		return
	_expect(bool(restored_world.get("_is_in_backrooms")), "file load activates Backrooms only after the runtime is reconstructed")
	var restored_player: CharacterBody3D = restored_world.get("player") as CharacterBody3D
	var restored_manager: RefCounted = restored_world.get("backrooms_transition_manager") as RefCounted
	var restored_runtime: Node3D = restored_world.get("backrooms_maze_runtime") as Node3D
	_expect(restored_player != null and restored_manager != null and restored_runtime != null, "restored world exposes its player, transition manager and maze runtime")
	if restored_player == null or restored_manager == null or restored_runtime == null:
		_finish(1)
		return
	var saved_position: Array = backrooms_payload.get("backrooms_player", {}).get("position", [])
	if saved_position.size() == 3 and restored_player != null:
		var expected_backrooms_position := Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
		_expect(restored_player.global_position.is_equal_approx(expected_backrooms_position), "file round-trip restores the exact Backrooms player position")
	_expect(restored_manager.call("get_session_save_dict") == backrooms_payload.get("backrooms_session", {}), "file round-trip restores the exact active LocationSession")
	_expect(restored_runtime.call("to_save_dict") == backrooms_payload.get("backrooms_runtime", {}), "file round-trip restores the exact maze runtime stream state")
	var return_result: Dictionary = restored_world.call("return_from_backrooms")
	_expect(bool(return_result.get("ok", false)), "file-restored Backrooms Session can return to SurfaceWorld")
	var saved_session: Dictionary = backrooms_payload.get("backrooms_session", {})
	var saved_return: Array = saved_session.get("surface_return_position", [])
	if saved_return.size() == 3 and restored_player != null:
		var expected_surface_position := Vector3(float(saved_return[0]), float(saved_return[1]), float(saved_return[2]))
		_expect(restored_player.global_position.is_equal_approx(expected_surface_position), "return after file load reaches the exact saved SurfaceWorld position")

	_finish(0 if failures.is_empty() else 1)


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (parser.data is Dictionary):
		return {}
	return parser.data.duplicate(true)


func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK


func _cleanup_save_paths() -> void:
	for base_path in [SAVE_PATH, BACKROOMS_SAVE_PATH, FAIL_CLOSED_PATH]:
		for suffix in ["", ".tmp", ".bak", ".corrupt", ".corrupt.1", ".corrupt.2"]:
			var path: String = base_path + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			elif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _on_timeout() -> void:
	push_error("SurfaceWorld file persistence integration test timed out.")
	_finish(2)


func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	if is_instance_valid(restored_world):
		restored_world.queue_free()
	if is_instance_valid(source_world):
		source_world.queue_free()
	await process_frame
	_cleanup_save_paths()
	if exit_code == 0 and failures.is_empty():
		print("SurfaceWorld file persistence integration tests passed.")
		quit(0)
	else:
		push_error("SurfaceWorld file persistence failures: %d" % failures.size())
		quit(1)
