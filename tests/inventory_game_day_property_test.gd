extends SceneTree

const InventoryScript = preload("res://systems/SurvivalInventory.gd")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

func _initialize() -> void:
	_test_direct_assignment_is_clamped()
	_test_world_save_roundtrip_uses_clamped_day()
	print("Inventory game-day property guard tests passed.")
	quit(0)

func _test_direct_assignment_is_clamped() -> void:
	var inventory = InventoryScript.new({}, 3)
	inventory.game_day = -25
	assert(inventory.game_day == 1, "negative direct assignment clamps to day one")
	inventory.game_day = InventoryScript.MAX_SAVED_GAME_DAY + 25
	assert(inventory.game_day == InventoryScript.MAX_SAVED_GAME_DAY, "oversized direct assignment clamps to the save maximum")
	inventory.game_day = 42
	assert(inventory.to_save_dict()["game_day"] == 42, "serialized day reflects the guarded property")
	inventory.set_game_day(-5)
	assert(inventory.game_day == 1, "legacy setter shares the same clamp")

func _test_world_save_roundtrip_uses_clamped_day() -> void:
	var inventory = InventoryScript.new({}, 1)
	inventory.game_day = 42
	var bridge = BridgeScript.new()
	assert(bridge.bind_inventory(inventory))
	var existing_world_save := {
		"version": 2,
		"game_day": 1,
		"inventory": {},
		"world_seed": 20090520,
		"player_position": [1.0, 2.0, 3.0]
	}
	var serialized: Dictionary = bridge.serialize_world_save(existing_world_save)
	assert(bool(serialized.get("ok", false)))
	var updated: Dictionary = serialized["world_save"]
	assert(int(updated["game_day"]) == 42)
	assert(int(updated["world_seed"]) == 20090520)
	assert(updated["player_position"] == existing_world_save["player_position"])
	var before_counts: Dictionary = inventory.counts.duplicate(true)
	var before_day: int = inventory.game_day
	var invalid_world_save := {
		"version": 2,
		"game_day": InventoryScript.MAX_SAVED_GAME_DAY + 1,
		"inventory": {"meat": 1}
	}
	assert(not bridge.restore_world_save(invalid_world_save), "invalid world day must be rejected")
	assert(inventory.game_day == before_day, "rejected world save preserves the current day")
	assert(inventory.counts == before_counts, "rejected world save preserves inventory counts")
	var valid_world_save := {
		"version": 2,
		"game_day": 7,
		"inventory": {"meat": 2}
	}
	assert(bridge.restore_world_save(valid_world_save))
	assert(inventory.game_day == 7)
	assert(inventory.get_item_count("meat") == 2)
	bridge.free()
