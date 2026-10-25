extends SceneTree

const PlaygroundScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const TARGET_LEVELS: Array[String] = ["Level 0", "Level 1", "Level 2", "Level 3"]

var failures: Array[String] = []

func _initialize() -> void:
    var watchdog := Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 25.0
    root.add_child(watchdog)
    watchdog.timeout.connect(_on_timeout)
    watchdog.start()
    call_deferred("_run_integration_test")

func _run_integration_test() -> void:
    var world = PlaygroundScene.instantiate()
    root.add_child(world)
    await process_frame
    _expect(world.get_current_level() == "Surface", "starts in surface world")
    _expect(world.debug_collect_berries(2), "collects items through shared world bridge")
    _expect(world.debug_spawn_portal(), "test shortcut spawns portal through director")
    await process_frame
    _expect(world.has_active_portal(), "portal director and visual stay synchronized")
    _expect(world.debug_enter_active_portal(), "entering portal changes world")
    await process_frame
    var entered_level: String = world.get_current_level()
    _expect(TARGET_LEVELS.has(entered_level), "destination belongs to supported Level 0-3 list")

    var saved: Dictionary = world.serialize_world_state()
    _expect(not saved.is_empty(), "serializes world envelope with portal state")
    _expect(world.debug_collect_berries(3), "collects another stack after entering")
    _expect(world.get_inventory_count("berries") == 5, "inventory reflects bridge changes")
    _expect(world.load_world_state_from_dictionary(saved), "restores valid world envelope")
    _expect(world.get_inventory_count("berries") == 2, "load restores prior inventory count")
    _expect(world.get_current_level() == entered_level, "load restores current Backrooms level")

    var before_count: int = world.get_inventory_count("berries")
    var before_level: String = world.get_current_level()
    var invalid_save: Dictionary = saved.duplicate(true)
    invalid_save["backrooms_portal_state"]["schema_version"] = 99
    _expect(not world.load_world_state_from_dictionary(invalid_save), "rejects invalid portal schema")
    _expect(world.get_inventory_count("berries") == before_count, "invalid restore leaves inventory unchanged")
    _expect(world.get_current_level() == before_level, "invalid restore leaves current level unchanged")

    if failures.is_empty():
        print("Backrooms portal playground integration test passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

func _on_timeout() -> void:
    push_error("Backrooms portal playground integration test timed out.")
    quit(2)
