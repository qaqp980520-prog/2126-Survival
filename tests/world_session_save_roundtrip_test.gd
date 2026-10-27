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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(save_absolute)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	var backup_file := FileAccess.open(backup_path, FileAccess.WRITE)
	_expect(backup_file != null, "prepare interrupted-save backup fixture")
	if backup_file != null:
		backup_file.store_string(JSON.stringify(recovery_snapshot))
		backup_file.close()
	_expect(not FileAccess.file_exists(SAVE_PATH), "simulate interruption after old save moved to backup")
	_expect(bool(world.call("load_game")), "load_game recovers a valid backup when primary save is missing")
	_expect(FileAccess.file_exists(SAVE_PATH), "backup is promoted back to the primary save path")

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
	await process_frame
	quit(exit_code)
