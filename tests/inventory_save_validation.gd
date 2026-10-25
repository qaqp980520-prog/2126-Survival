extends SceneTree

const Inventory = preload("res://systems/SurvivalInventory.gd")

func _initialize() -> void:
	_test_valid_round_trip()
	_test_rejects_fractional_counts_atomically()
	_test_rejects_unknown_items_and_bad_schema()
	_test_rejects_invalid_game_day_atomically()
	_test_rejects_unregistered_runtime_items()
	print("Inventory save validation smoke tests passed.")
	quit()

func _test_valid_round_trip() -> void:
	var inventory = Inventory.new({"meat": 2, "rock": 3}, 5)
	var saved: Dictionary = inventory.to_save_dict()
	var restored = Inventory.new()
	assert(restored.load_save_dict(saved))
	assert(restored.counts["meat"] == 2)
	assert(restored.counts["rock"] == 3)
	assert(restored.counts["berries"] == 0)
	assert(restored.game_day == 5)
	assert(is_equal_approx(restored.total_weight_kg(), 9.0))

func _test_rejects_fractional_counts_atomically() -> void:
	var inventory = Inventory.new({"meat": 4}, 7)
	var before: Dictionary = inventory.to_save_dict()
	var bad_save := {
		"schema_version": 1,
		"game_day": 2,
		"inventory": {"meat": 1.5}
	}
	assert(not inventory.load_save_dict(bad_save))
	assert(inventory.to_save_dict() == before)

func _test_rejects_unknown_items_and_bad_schema() -> void:
	var inventory = Inventory.new({"meat": 1}, 2)
	var before: Dictionary = inventory.to_save_dict()
	assert(not inventory.load_save_dict({
		"schema_version": 99,
		"game_day": 2,
		"inventory": {"meat": 1}
	}))
	assert(not inventory.load_save_dict({
		"schema_version": 1,
		"game_day": 2,
		"inventory": {"unknown_ore": 50}
	}))
	assert(inventory.to_save_dict() == before)

func _test_rejects_invalid_game_day_atomically() -> void:
	var inventory = Inventory.new({"meat": 3}, 4)
	var before: Dictionary = inventory.to_save_dict()
	assert(not inventory.load_save_dict({
		"schema_version": 1,
		"game_day": 2.5,
		"inventory": {"meat": 1}
	}))
	assert(not inventory.load_save_dict({
		"schema_version": 1,
		"game_day": -1,
		"inventory": {"meat": 1}
	}))
	assert(inventory.to_save_dict() == before)

func _test_rejects_unregistered_runtime_items() -> void:
	var inventory = Inventory.new()
	assert(inventory.add_item("unregistered_item", 1) == 0)
	assert(inventory.remove_item("unregistered_item", 1) == 0)
