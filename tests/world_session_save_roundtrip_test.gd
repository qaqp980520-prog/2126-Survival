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

	if failures.is_empty():
		print("Active world save roundtrip integration tests passed.")
		_finish(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		_finish(1)

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
	await process_frame
	quit(exit_code)
