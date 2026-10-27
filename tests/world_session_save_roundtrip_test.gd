extends SceneTree

const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const SAVE_PATH: String = "user://backrooms_playground_save.json"

var failures: Array[String] = []
var watchdog: Timer
var world: Node

func _initialize() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 35.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run")

func _start_watchdog() -> void:
	if is_instance_valid(watchdog) and watchdog.is_inside_tree():
		watchdog.start()

func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	_test_atomic_write(world)
	_expect(str(world.call("get_current_level")) == "Surface", "active world controller starts on Surface")
	_expect(bool(world.call("debug_collect_berries", 4)), "collect items through the active world's bridge")
	var player: Node3D = world.get_node("Player")
	player.global_position = Vector3(2.0, 0.0, 3.0)
	_expect(bool(world.call("save_game")), "active world controller writes a real user:// save file")
	_expect(bool(world.call("debug_collect_berries", 2)), "mutate inventory after save")
	player.global_position = Vector3(5.0, 0.0, 6.0)
	_expect(bool(world.call("load_game")), "active world controller reads and restores the saved envelope")
	_expect(int(world.call("get_inventory_count", "berries")) == 4, "file roundtrip restores the saved inventory count")
	_expect(player.global_position.is_equal_approx(Vector3(2.0, 0.0, 3.0)), "file roundtrip restores player position")

	var before_count: int = int(world.call("get_inventory_count", "berries"))
	var before_position: Vector3 = player.global_position
	var invalid_inventory: Dictionary = world.call("serialize_world_state")
	invalid_inventory["inventory"] = {"not_registered": 1}
	_expect(not bool(world.call("load_world_state_from_dictionary", invalid_inventory)), "reject unknown item in active world save")
	_expect(int(world.call("get_inventory_count", "berries")) == before_count, "invalid inventory restore leaves live inventory unchanged")
	_expect(player.global_position.is_equal_approx(before_position), "invalid inventory restore leaves player position unchanged")

	var invalid_position: Dictionary = world.call("serialize_world_state")
	invalid_position["player_position"] = [INF, 0.0, 0.0]
	_expect(not bool(world.call("load_world_state_from_dictionary", invalid_position)), "reject non-finite player position")
	_expect(int(world.call("get_inventory_count", "berries")) == before_count, "invalid position restore leaves live inventory unchanged")
	_expect(player.global_position.is_equal_approx(before_position), "invalid position restore leaves player position unchanged")

	var recovery_snapshot: Dictionary = world.call("serialize_world_state")
	var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_path := SAVE_PATH + ".bak"
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var corrupt_path := SAVE_PATH + ".corrupt"
	var corrupt_absolute := ProjectSettings.globalize_path(corrupt_path)
	var saved_position_data: Array = recovery_snapshot.get("player_position", [])
	var saved_position := Vector3(float(saved_position_data[0]), float(saved_position_data[1]), float(saved_position_data[2]))

	# Corrupt JSON in the primary file must fall back to the valid backup.
	for path in [SAVE_PATH, backup_path, corrupt_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var backup_file := FileAccess.open(backup_path, FileAccess.WRITE)
	_expect(backup_file != null, "prepare valid backup for corrupt-primary recovery")
	if backup_file != null:
		backup_file.store_string(JSON.stringify(recovery_snapshot))
		backup_file.close()
	var corrupt_primary := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_expect(corrupt_primary != null, "prepare corrupt primary save")
	if corrupt_primary != null:
		corrupt_primary.store_string("{not-json")
		corrupt_primary.close()
	_expect(bool(world.call("debug_collect_berries", 2)), "mutate live inventory before corrupt-primary fallback")
	player.global_position = Vector3(5.0, 0.0, 6.0)
	_expect(bool(world.call("load_game")), "load_game falls back when primary JSON is corrupt")
	_expect(int(world.call("get_inventory_count", "berries")) == 4, "corrupt-primary fallback restores backup inventory")
	_expect(player.global_position.is_equal_approx(saved_position), "corrupt-primary fallback restores backup player position")
	_expect(FileAccess.file_exists(corrupt_path), "corrupt primary is preserved under the diagnostic suffix")
	_expect(FileAccess.get_file_as_string(corrupt_path) == "{not-json", "diagnostic file preserves the original corrupt bytes")
	_expect(FileAccess.file_exists(SAVE_PATH), "valid backup is promoted to a repaired primary save")
	_expect(not FileAccess.file_exists(backup_path), "successful primary repair clears the now-redundant backup")
	var repaired_primary: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_expect(repaired_primary is Dictionary and repaired_primary.get("inventory", {}).get("berries", -1) == 4, "repaired primary contains the recovered payload")

	# A valid JSON dictionary with an invalid world envelope must also fall back.
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(corrupt_absolute)
	var semantic_backup := FileAccess.open(backup_path, FileAccess.WRITE)
	_expect(semantic_backup != null, "prepare backup for invalid-envelope recovery")
	if semantic_backup != null:
		semantic_backup.store_string(JSON.stringify(recovery_snapshot))
		semantic_backup.close()
	var semantically_invalid: Dictionary = recovery_snapshot.duplicate(true)
	semantically_invalid["inventory"] = {"not_registered": 1}
	var invalid_primary_text := JSON.stringify(semantically_invalid)
	var invalid_primary_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_expect(invalid_primary_file != null, "prepare semantically invalid primary save")
	if invalid_primary_file != null:
		invalid_primary_file.store_string(invalid_primary_text)
		invalid_primary_file.close()
	_expect(bool(world.call("debug_collect_berries", 3)), "mutate inventory before invalid-envelope fallback")
	player.global_position = Vector3(6.0, 0.0, 7.0)
	_expect(bool(world.call("load_game")), "load_game falls back when primary envelope validation fails")
	_expect(int(world.call("get_inventory_count", "berries")) == 4, "invalid-envelope fallback restores backup inventory")
	_expect(player.global_position.is_equal_approx(saved_position), "invalid-envelope fallback restores backup position")
	_expect(FileAccess.get_file_as_string(corrupt_path) == invalid_primary_text, "invalid primary envelope is preserved for diagnosis")
	_expect(FileAccess.file_exists(SAVE_PATH), "invalid-envelope fallback repairs the primary save")
	_expect(not FileAccess.file_exists(backup_path), "successful invalid-envelope recovery clears the redundant backup")

	# Preserve the existing interrupted-write case where the primary is absent.
	for path in [SAVE_PATH, backup_path, corrupt_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
	_expect(backup_file != null, "prepare interrupted-save backup fixture")
	if backup_file != null:
		backup_file.store_string(JSON.stringify(recovery_snapshot))
		backup_file.close()
	_expect(not FileAccess.file_exists(SAVE_PATH), "simulate interruption after old save moved to backup")
	_expect(bool(world.call("load_game")), "load_game recovers a valid backup when primary save is missing")
	_expect(FileAccess.file_exists(SAVE_PATH), "backup is promoted back to the primary save path")
	_expect(not FileAccess.file_exists(backup_path), "successful missing-primary recovery clears the redundant backup")

	if failures.is_empty():
		print("Active world save roundtrip integration tests passed.")
		_finish(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		_finish(1)

func _test_atomic_write(world: Node) -> void:
	var probe_path := "user://run21_atomic_save_probe.json"
	var temporary_path := probe_path + ".tmp"
	var backup_path := probe_path + ".bak"
	var probe_absolute := ProjectSettings.globalize_path(probe_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	for path in [probe_path, temporary_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.dir_exists_absolute(temporary_absolute):
		DirAccess.remove_absolute(temporary_absolute)

	_expect(bool(world.call("_write_save_atomically", probe_path, {"version": 2, "marker": "original"})), "atomic helper writes initial save")
	var original_text := FileAccess.get_file_as_string(probe_path)
	var mkdir_error := DirAccess.make_dir_absolute(temporary_absolute)
	_expect(mkdir_error == OK or DirAccess.dir_exists_absolute(temporary_absolute), "prepare temporary-path obstruction fixture")
	if DirAccess.dir_exists_absolute(temporary_absolute):
		_expect(not bool(world.call("_write_save_atomically", probe_path, {"version": 2, "marker": "replacement"})), "atomic helper rejects obstructed temporary path")
		_expect(FileAccess.get_file_as_string(probe_path) == original_text, "failed atomic write preserves previous save bytes")
		DirAccess.remove_absolute(temporary_absolute)
	else:
		_expect(false, "temporary-path obstruction fixture exists")
	_expect(bool(world.call("_write_save_atomically", probe_path, {"version": 2, "marker": "replacement"})), "atomic helper replaces a save after validating temporary JSON")
	var replaced: Variant = JSON.parse_string(FileAccess.get_file_as_string(probe_path))
	_expect(replaced is Dictionary and str(replaced.get("marker", "")) == "replacement", "atomic replacement contains the complete new payload")
	for path in [probe_path, temporary_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

func _on_timeout() -> void:
	push_error("Active world save roundtrip integration test timed out.")
	_finish(2)

func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".corrupt"))
	await process_frame
	quit(exit_code)
