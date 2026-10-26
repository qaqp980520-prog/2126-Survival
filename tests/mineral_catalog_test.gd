extends SceneTree

const Catalog = preload("res://systems/MineralCatalog.gd")
const Inventory = preload("res://systems/SurvivalInventory.gd")
const OreVisual = preload("res://prototypes/minerals/MineralOreVisual.gd")
const MiningVFX = preload("res://prototypes/minerals/MineralMiningVFX.gd")

func _initialize() -> void:
	_test_all_seven_minerals_registered()
	_test_inventory_weight_and_save_compatibility()
	_test_visual_and_vfx_nodes_construct()
	print("Mineral catalog regression tests passed.")
	quit(0)

func _test_all_seven_minerals_registered() -> void:
	assert(Catalog.get_ids().size() == 7)
	for item_id in ["copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore", "coal_ore", "uranium_ore"]:
		assert(Catalog.has_mineral(item_id), "Missing mineral: " + item_id)
		assert(not Catalog.get_mineral(item_id).is_empty())

func _test_inventory_weight_and_save_compatibility() -> void:
	var inventory = Inventory.new({"iron_ore": 1, "copper_ore": 1}, 1)
	assert(is_equal_approx(inventory.total_weight_kg(), 5.8))
	assert(inventory.add_item("gold_ore", 2) == 2)
	assert(inventory.add_item("silver_ore", 1) == 1)
	assert(inventory.add_item("aluminium_ore", 1) == 1)
	assert(inventory.add_item("coal_ore", 3) == 3)
	assert(inventory.add_item("uranium_ore", 1) == 1)
	var saved: Dictionary = inventory.to_save_dict()
	var restored = Inventory.new()
	assert(restored.load_save_dict(saved))
	assert(restored.counts["iron_ore"] == 1)
	assert(restored.counts["copper_ore"] == 1)
	assert(restored.counts["uranium_ore"] == 1)
	assert(is_equal_approx(restored.total_weight_kg(), inventory.total_weight_kg()))
	assert(restored.add_item("unknown_ore", 1) == 0)

func _test_visual_and_vfx_nodes_construct() -> void:
	var visual = OreVisual.new()
	visual.mineral_id = "uranium_ore"
	visual.random_seed = 7
	root.add_child(visual)
	assert(visual.get_child_count() == 7)
	var vfx = MiningVFX.new()
	root.add_child(vfx)
	vfx.play_hit("uranium_ore", Vector3.ZERO)
	assert(vfx.get_child_count() > 0)
