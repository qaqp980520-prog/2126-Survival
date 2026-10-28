extends SceneTree

const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const SAVE_PATH: String = "user://backrooms_playground_save.json"
const RELATED_PATHS: Array[String] = [
	"user://backrooms_playground_save.json",
	"user://backrooms_playground_save.json.tmp",
	"user://backrooms_playground_save.json.bak",
	"user://backrooms_playground_save.json.corrupt"
]

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
	_cleanup_save_files()
	world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var bridge: Node = world.get("bridge")
	var player := world.get_node("Player") as Node3D
	_expect(bridge != null, "active world creates the shared inventory bridge")
	if bridge == null:
		_finish(1)
		return

	var vein := MiningNode.new() as Node3D
	vein.name = "LifecycleTestIronVein"
	vein.set("mineral_id", "iron_ore")
	vein.set("remaining_units", 5)
	vein.set("max_units", 5)
	vein.set("units_per_hit", 2)
	vein.set("regen_interval_seconds", 86400)
	vein.set("last_regen_unix", int(Time.get_unix_time_from_system()))
	vein.set("inventory_bridge_path", NodePath("../SurvivalWorldBridge"))
	world.add_child(vein)
	await process_frame

	var starting_weight := float(bridge.call("get_weight_kg"))
	var accepted := int(vein.call("mine_hit"))
	_expect(accepted == 2, "real MineralMiningNode transfers two ore through the active world's bridge")
	_expect(int(vein.get("remaining_units")) == 3, "vein stock decreases only by accepted ore")
	_expect(int(world.call("get_inventory_count", "iron_ore")) == 2, "mined ore appears in the shared inventory")
	var mined_weight := float(bridge.call("get_weight_kg"))
	_expect(is_equal_approx(mined_weight, starting_weight + 6.0), "two iron ore immediately add six kilograms")

	player.global_position = Vector3(2.0, 0.0, 3.0)
	_expect(bool(world.call("save_game")), "active world saves mined inventory to a real user:// file")
	_expect(FileAccess.file_exists(SAVE_PATH), "world save file exists after save_game")

	_expect(bool(bridge.call("drop_item", "iron_ore", 1)), "shared bridge accepts an ore drop after mining")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), mined_weight - 3.0), "dropping ore immediately recalculates carry weight")
	player.global_position = Vector3(8.0, 0.0, 9.0)
	_expect(bool(bridge.call("collect_world_item", "berries", 2)), "post-save mutation succeeds before reload")
	_expect(bool(world.call("load_game")), "active world reloads the saved mining inventory")
	_expect(int(world.call("get_inventory_count", "iron_ore")) == 2, "reload restores the mined ore count")
	_expect(int(world.call("get_inventory_count", "berries")) == 0, "reload discards inventory mutations made after saving")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), mined_weight), "reload restores the saved inventory weight")
	_expect(player.global_position.is_equal_approx(Vector3(2.0, 0.0, 3.0)), "reload restores the saved player position")

	_expect(bool(bridge.call("drop_item", "iron_ore", 1)), "restored ore can be dropped after reload")
	_expect(is_equal_approx(float(bridge.call("get_weight_kg")), starting_weight + 3.0), "post-reload drop updates weight immediately")

	_cleanup_save_files()
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if failures.is_empty():
		print("World inventory mining lifecycle integration test passed.")
		_finish(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		_finish(1)

func _cleanup_save_files() -> void:
	for path in RELATED_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _on_timeout() -> void:
	failures.append("world inventory mining lifecycle watchdog timed out")
	_cleanup_save_files()
	_finish(1)

func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	quit(exit_code)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
