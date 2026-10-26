extends SceneTree

const InventoryScript = preload("res://systems/SurvivalInventory.gd")
const BridgeScript = preload("res://systems/SurvivalWorldBridge.gd")

func _initialize() -> void:
	_test_carry_limit_growth()
	_test_overweight_boundary_and_recovery()
	_test_super_heavy_jump_boundary_and_recovery()
	_test_invalid_item_and_amount()
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

	# Exercise the real world bridge drop path, not only the inventory model.
	var bridge = BridgeScript.new()
	assert(bridge.bind_inventory(inventory))
	assert(bridge.drop_item("rock", 1))
	assert(not inventory.is_super_heavy())
	assert(bridge.call("can_player_jump"))

func _test_invalid_item_and_amount() -> void:
	var inventory = InventoryScript.new()
	assert(inventory.add_item("not_registered", 1) == 0)
	assert(inventory.add_item("rock", 0) == 0)
	assert(inventory.remove_item("rock", -1) == 0)
	assert(inventory.add_item("rock", InventoryScript.MAX_SAVED_COUNT) == InventoryScript.MAX_SAVED_COUNT)
	assert(inventory.add_item("rock", 1) == 0)
