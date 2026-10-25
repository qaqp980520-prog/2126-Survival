extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const InventoryScript = preload("res://systems/SurvivalInventory.gd")

var failures: Array[String] = []

func _initialize() -> void:
    var watchdog := Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 30.0
    root.add_child(watchdog)
    watchdog.timeout.connect(_on_watchdog_timeout)
    watchdog.start()
    call_deferred("_run_integration_test")

func _run_integration_test() -> void:
    var bridge = BridgeScript.new()
    bridge.set("inventory_script", InventoryScript)
    root.add_child(bridge)
    await process_frame

    var legacy_world := {
        "version": 2,
        "game_day": 4,
        "inventory": {"meat": 2, "rock": 3},
        "world_seed": 12345,
        "stamina": 75.0,
        "hotbar_slots": ["", "meat", "", "food", "", "", "", "", "", ""],
        "selected_hotbar": 2,
        "player_position": [1.5, 2.0, -3.5],
        "crops": [{"id": "crop_a", "growth": 0.5}],
        "world_state": {"harvested_world_crop_ids": ["crop_1"]}
    }
    var original_world: Dictionary = legacy_world.duplicate(true)

    var restored_ok := bool(bridge.call("restore_world_save", legacy_world))
    _expect(restored_ok, "restore valid legacy world save")
    if not restored_ok:
        _finish()
        return

    var payload: Dictionary = bridge.call("serialize_inventory")
    _expect(payload.get("game_day", -1) == 4, "restored game day")
    var counts: Dictionary = payload.get("inventory", {})
    _expect(counts.get("meat", -1) == 2 and counts.get("rock", -1) == 3, "restored item counts")
    _expect(is_equal_approx(float(bridge.call("get_weight_kg")), 9.0), "restored inventory weight")

    var collected := bool(bridge.call("collect_world_item", "berries", 3))
    _expect(collected, "collect berries through world bridge")
    var before_bad_restore: Dictionary = bridge.call("serialize_inventory").duplicate(true)
    var serialized: Dictionary = bridge.call("serialize_world_save", legacy_world)
    var export_ok := bool(serialized.get("ok", false))
    _expect(export_ok, "serialize inventory into legacy world envelope")
    if export_ok:
        var updated: Dictionary = serialized["world_save"]
        var updated_counts: Dictionary = updated.get("inventory", {})
        _expect(updated_counts.get("meat", -1) == 2, "export preserves meat count")
        _expect(updated_counts.get("rock", -1) == 3, "export preserves rock count")
        _expect(updated_counts.get("berries", -1) == 3, "export includes newly collected berries")
        _expect(updated.get("game_day", -1) == 4, "export preserves game day")
        _expect(updated.get("world_seed", -1) == 12345, "export preserves world seed")
        _expect(updated.get("stamina", -1.0) == 75.0, "export preserves stamina")
        _expect(updated.get("hotbar_slots", []) == legacy_world["hotbar_slots"], "export preserves hotbar slots")
        _expect(updated.get("selected_hotbar", -1) == 2, "export preserves selected hotbar slot")
        _expect(updated.get("player_position", []) == legacy_world["player_position"], "export preserves player position")
        _expect(updated.get("crops", []) == legacy_world["crops"], "export preserves crops")
        _expect(updated.get("world_state", {}) == legacy_world["world_state"], "export preserves world state")
    _expect(legacy_world == original_world, "export does not mutate input envelope")

    var invalid_world: Dictionary = legacy_world.duplicate(true)
    invalid_world["inventory"] = {"mystery_item": 9}
    var invalid_restore_ok := bool(bridge.call("restore_world_save", invalid_world))
    _expect(not invalid_restore_ok, "reject unknown item ID")
    _expect(bridge.call("serialize_inventory") == before_bad_restore, "invalid restore leaves live inventory unchanged")

    var unsupported_world: Dictionary = legacy_world.duplicate(true)
    unsupported_world["version"] = 3
    var unsupported_before: Dictionary = unsupported_world.duplicate(true)
    var rejected_export: Dictionary = bridge.call("serialize_world_save", unsupported_world)
    _expect(not bool(rejected_export.get("ok", false)), "reject unsupported world schema")
    _expect(unsupported_world == unsupported_before, "rejected export leaves input unchanged")

    _finish()

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
        push_error("FAIL: " + message)

func _finish() -> void:
    if failures.is_empty():
        print("SurvivalWorldBridge save adapter integration tests passed.")
        quit(0)
    else:
        push_error("SurvivalWorldBridge integration failures: " + str(failures))
        quit(1)

func _on_watchdog_timeout() -> void:
    push_error("SurvivalWorldBridge integration test timed out.")
    quit(2)
