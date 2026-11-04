extends SceneTree

const InventoryScript = preload("res://systems/SurvivalInventory.gd")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

func _initialize() -> void:
	_test_carry_limit_growth()
	_test_overweight_boundary_and_recovery()
	_test_super_heavy_jump_boundary_and_recovery()
	_test_invalid_item_and_amount()
	_test_unknown_count_fallback_weight()
	_test_runtime_dictionary_corruption_is_not_serialized()
	print("Inventory weight boundary regression tests passed.")
	quit(0)

func _test_carry_limit_growth() -> void:
	var inventory = InventoryScript.new({}, 1)
	assert(is_equal_approx(inventory.carry_limit_kg(), 65.0))
	inventory.set_game_day(6)
	assert(is_equal_approx(inventory.carry_limit_kg(), 66.0))
	inventory.set_game_day(0)
	assert(is_equal_approx(inventory.carry_limit_kg(), 65.0))

func _test_overweight_boundary_and_recovery() -> void:
	var inventory = InventoryScript.new()
	assert(inventory.add_item("meat", 86) == 86)
	assert(is_equal_approx(inventory.total_weight_kg(), 64.5))
	assert(not inventory.is_overweight())
	assert(inventory.add_item("meat", 1) == 1)
	assert(is_equal_approx(inventory.total_weight_kg(), 65.25))
	assert(inventory.is_overweight())
	assert(is_equal_approx(inventory.movement_multiplier(), 0.68))
	assert(inventory.remove_item("meat", 1) == 1)
	assert(not inventory.is_overweight())
	assert(is_equal_approx(inventory.movement_multiplier(), 1.0))

func _test_super_heavy_jump_boundary_and_recovery() -> void:
	var inventory = InventoryScript.new()
	assert(inventory.add_item("rock", 36) == 36)
	assert(is_equal_approx(inventory.total_weight_kg(), 90.0))
	assert(not inventory.is_super_heavy())
	assert(inventory.can_jump())
	assert(inventory.add_item("rock", 1) == 1)
	assert(inventory.is_super_heavy())
	assert(not inventory.can_jump())
	assert(is_equal_approx(inventory.movement_multiplier(), 0.42))
	assert(inventory.remove_item("rock", 1) == 1)
	assert(not inventory.is_super_heavy())
	assert(inventory.can_jump())
	var bridge = BridgeScript.new()
	assert(bridge.bind_inventory(inventory))
	assert(bridge.drop_item("rock", 1))
	assert(not inventory.is_super_heavy())
	assert(bridge.call("can_player_jump"))
	bridge.free()

func _test_invalid_item_and_amount() -> void:
	var inventory = InventoryScript.new()
	assert(inventory.add_item("not_registered", 1) == 0)
	assert(inventory.add_item("rock", 0) == 0)
	assert(inventory.remove_item("rock", -1) == 0)
	assert(inventory.add_item("rock", InventoryScript.MAX_SAVED_COUNT) == InventoryScript.MAX_SAVED_COUNT)
	assert(inventory.add_item("rock", 1) == 0)

func _test_unknown_count_fallback_weight() -> void:
	var inventory = InventoryScript.new()
	assert(is_equal_approx(inventory.total_weight_kg(), 0.0))
	inventory.counts["legacy_unregistered_item"] = 2
	assert(is_equal_approx(inventory.total_weight_kg(), 2.0))
	assert(inventory.add_item("legacy_unregistered_item", 1) == 0)
	var payload := inventory.to_save_dict()
	payload["inventory"]["legacy_unregistered_item"] = 1
	var previous_counts: Dictionary = inventory.counts.duplicate(true)
	assert(not inventory.load_save_dict(payload))
	assert(inventory.counts == previous_counts)

func _test_runtime_dictionary_corruption_is_not_serialized() -> void:
	var inventory = InventoryScript.new({"meat":4,"rock":2}, 3)
	inventory.counts["meat"] = 1.5
	inventory.counts["rock"] = -7
	inventory.counts["berries"] = "not-a-count"
	inventory.counts["legacy_unknown"] = 2
	assert(inventory.get_item_count("meat") == 0)
	assert(inventory.get_item_count("rock") == 0)
	assert(inventory.get_item_count("berries") == 0)
	assert(inventory.get_item_count("unknown") == 0)
	assert(inventory.add_item("meat", 1) == 0)
	assert(inventory.remove_item("rock", 1) == 0)
	assert(is_equal_approx(inventory.total_weight_kg(), 2.0))
	var save: Dictionary = inventory.to_save_dict()
	assert(save["inventory"]["meat"] == 0)
	assert(save["inventory"]["rock"] == 0)
	assert(save["inventory"]["berries"] == 0)
	assert(not save["inventory"].has("legacy_unknown"))
	assert(save["game_day"] == 3)
	var bridge = BridgeScript.new()
	assert(bridge.bind_inventory(inventory))
	assert(bridge.get_item_count("meat") == 0)
	bridge.free()
