extends SceneTree

const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")
const InventoryScript = preload("res://systems/SurvivalInventory.gd")

func _initialize() -> void:
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

    assert(bridge.call("restore_world_save", legacy_world))
    var payload: Dictionary = bridge.call("serialize_inventory")
    assert(payload["game_day"] == 4)
    assert(payload["inventory"]["meat"] == 2)
    assert(payload["inventory"]["rock"] == 3)
    assert(is_equal_approx(float(bridge.call("get_weight_kg")), 9.0))

    assert(bridge.call("collect_world_item", "berries", 3))
    var before_bad_restore: Dictionary = bridge.call("serialize_inventory").duplicate(true)
    var serialized: Dictionary = bridge.call("serialize_world_save", legacy_world)
    assert(serialized.get("ok", false))
    var updated: Dictionary = serialized["world_save"]
    assert(updated["inventory"]["meat"] == 2)
    assert(updated["inventory"]["rock"] == 3)
    assert(updated["inventory"]["berries"] == 3)
    assert(updated["game_day"] == 4)
    assert(updated["world_seed"] == 12345)
    assert(updated["stamina"] == 75.0)
    assert(updated["hotbar_slots"] == legacy_world["hotbar_slots"])
    assert(updated["selected_hotbar"] == 2)
    assert(updated["player_position"] == legacy_world["player_position"])
    assert(updated["crops"] == legacy_world["crops"])
    assert(updated["world_state"] == legacy_world["world_state"])
    assert(legacy_world == original_world)

    var invalid_world: Dictionary = legacy_world.duplicate(true)
    invalid_world["inventory"] = {"mystery_item": 9}
    assert(not bridge.call("restore_world_save", invalid_world))
    assert(bridge.call("serialize_inventory") == before_bad_restore)

    var unsupported_world: Dictionary = legacy_world.duplicate(true)
    unsupported_world["version"] = 3
    var rejected_export: Dictionary = bridge.call("serialize_world_save", unsupported_world)
    assert(not rejected_export.get("ok", false))
    assert(unsupported_world == legacy_world)

    print("SurvivalWorldBridge save adapter integration tests passed.")
    quit()
