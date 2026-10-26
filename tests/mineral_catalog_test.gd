extends SceneTree

const Catalog = preload("res://systems/MineralCatalog.gd")
const Inventory = preload("res://systems/SurvivalInventory.gd")
const OreVisual = preload("res://prototypes/minerals/MineralOreVisual.gd")
const MiningVFX = preload("res://prototypes/minerals/MineralMiningVFX.gd")
const InventoryPreview = preload("res://prototypes/minerals/MineralInventoryPreview.gd")
const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Bridge = preload("res://systems/SurvivalWorldBridge.gd")
const VeinRegistry = preload("res://systems/MineralVeinRegistry.gd")

func _initialize() -> void:
	# Defer until SceneTree initialization completes so add_child() invokes _ready()
	# before tests inspect generated visuals, bridge inventory, or mining-node state.
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_all_seven_minerals_registered()
	await process_frame
	_test_inventory_weight_and_save_compatibility()
	await process_frame
	_test_visual_and_vfx_nodes_construct()
	await process_frame
	_test_mining_depletes_vein_and_adds_inventory()
	await process_frame
	_test_full_inventory_does_not_consume_vein()
	await process_frame
	_test_inventory_preview_builds_single_model()
	await process_frame
	_test_vein_save_load_validation()
	await process_frame
	_test_vein_depletion_restore_and_signal()
	await process_frame
	_test_offline_regeneration_round_trip()
	await process_frame
	_test_regeneration_caps_and_clock_rollback()
	await process_frame
	_test_legacy_vein_save_without_regen_fields()
	await process_frame
	_test_vein_registry_save_restore_and_atomic_rejection()
	await process_frame
	print("Mineral catalog regression tests passed.")
	quit(0)

func _test_all_seven_minerals_registered() -> void:
	assert(Catalog.get_ids().size() == 7)
	for item_id in ["copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore", "coal_ore", "uranium_ore"]:
		assert(Catalog.has_mineral(item_id), "Missing mineral: " + item_id)
		assert(not Catalog.get_mineral(item_id).is_empty())
		assert(is_equal_approx(float(Catalog.get_mineral(item_id)["weight_kg"]), float(Inventory.ITEM_WEIGHTS[item_id])))

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

func _test_mining_depletes_vein_and_adds_inventory() -> void:
	var bridge = Bridge.new()
	bridge.name = "Bridge"
	root.add_child(bridge)
	var mining = MiningNode.new()
	mining.name = "CopperVein"
	mining.mineral_id = "copper_ore"
	mining.remaining_units = 2
	mining.units_per_hit = 1
	mining.inventory_bridge_path = NodePath("../Bridge")
	root.add_child(mining)
	assert(mining.mine_hit(Vector3.ZERO) == 1)
	assert(mining.remaining_units == 1)
	assert(int(bridge.inventory.counts["copper_ore"]) == 1)
	assert(mining.mine_hit(Vector3.ZERO) == 1)
	assert(mining.remaining_units == 0)
	assert(int(bridge.inventory.counts["copper_ore"]) == 2)
	assert(mining.mine_hit(Vector3.ZERO) == 0)
	mining.queue_free()
	bridge.queue_free()

func _test_full_inventory_does_not_consume_vein() -> void:
	var bridge = Bridge.new()
	bridge.name = "FullBridge"
	root.add_child(bridge)
	assert(bridge.inventory.add_item("copper_ore", Inventory.MAX_SAVED_COUNT) == Inventory.MAX_SAVED_COUNT)
	var mining = MiningNode.new()
	mining.name = "FullInventoryVein"
	mining.mineral_id = "copper_ore"
	mining.remaining_units = 3
	mining.units_per_hit = 2
	mining.inventory_bridge_path = NodePath("../FullBridge")
	root.add_child(mining)
	assert(mining.mine_hit(Vector3.ZERO) == 0)
	assert(mining.remaining_units == 3, "A rejected pickup must not consume vein stock")
	assert(int(bridge.inventory.counts["copper_ore"]) == Inventory.MAX_SAVED_COUNT)
	mining.queue_free()
	bridge.queue_free()

func _test_visual_and_vfx_nodes_construct() -> void:
	# Build render resources off-tree: headless CI validates node construction without
	# registering dummy renderer meshes that cannot be visually inspected in this run.
	var visual = OreVisual.new()
	visual.mineral_id = "uranium_ore"
	visual.random_seed = 7
	visual.build_model()
	assert(visual.get_child_count() == 7)
	var vfx = MiningVFX.new()
	vfx.play_hit("uranium_ore", Vector3.ZERO)
	assert(vfx.get_child_count() > 0)
	visual.free()
	vfx.free()

func _test_inventory_preview_builds_single_model() -> void:
	var preview = InventoryPreview.new()
	preview.mineral_id = "gold_ore"
	root.add_child(preview)
	assert(preview.get_child_count() == 1)
	assert(preview.get_child(0).name == "OreIconModel")
	preview.refresh_preview()
	assert(preview.get_child_count() == 1, "Refreshing preview must leave only one ore model")
	preview.queue_free()

func _test_vein_save_load_validation() -> void:
	var mining = MiningNode.new()
	mining.mineral_id = "silver_ore"
	mining.remaining_units = 17
	root.add_child(mining)
	var saved: Dictionary = mining.to_save_dict()
	assert(int(saved["schema_version"]) == 2, "Regeneration metadata must be saved under schema v2")
	var restored = MiningNode.new()
	restored.mineral_id = "silver_ore"
	root.add_child(restored)
	assert(restored.load_save_dict(saved))
	assert(restored.remaining_units == 17)
	assert(not restored.load_save_dict({"schema_version": 3, "mineral_id": "silver_ore", "remaining_units": 4}))
	assert(restored.remaining_units == 17, "Invalid schema must not mutate vein state")
	assert(not restored.load_save_dict({"schema_version": 1, "mineral_id": "gold_ore", "remaining_units": 4}))
	assert(not restored.load_save_dict({"schema_version": 1, "mineral_id": "silver_ore", "remaining_units": -1}))
	assert(not restored.load_save_dict({"schema_version": 1, "mineral_id": "silver_ore", "remaining_units": 1.5}))
	assert(not restored.load_save_dict({"schema_version": 1, "mineral_id": "silver_ore", "remaining_units": 10001}))
	assert(restored.remaining_units == 17, "Rejected save data must preserve prior state")
	mining.queue_free()
	restored.queue_free()

func _test_vein_depletion_restore_and_signal() -> void:
	var bridge = Bridge.new()
	bridge.name = "SignalBridge"
	root.add_child(bridge)
	var mining = MiningNode.new()
	mining.name = "SignalVein"
	mining.mineral_id = "iron_ore"
	mining.remaining_units = 1
	mining.inventory_bridge_path = NodePath("../SignalBridge")
	root.add_child(mining)
	var depleted_events: Array[String] = []
	mining.ore_depleted.connect(func(item_id: String) -> void: depleted_events.append(item_id))
	assert(mining.mine_hit(Vector3.ZERO) == 1)
	assert(mining.remaining_units == 0)
	assert(not mining.visible)
	assert(depleted_events.size() == 1 and depleted_events[0] == "iron_ore")
	assert(mining.mine_hit(Vector3.ZERO) == 0)
	assert(depleted_events.size() == 1, "Depletion signal must fire once per depletion cycle")
	mining.restore_vein(2)
	assert(mining.remaining_units == 2)
	assert(mining.visible)
	assert(mining.mine_hit(Vector3.ZERO) == 1)
	assert(mining.remaining_units == 1)
	assert(mining.mine_hit(Vector3.ZERO) == 1)
	assert(mining.remaining_units == 0)
	assert(depleted_events.size() == 2, "Restored vein should emit depletion once again")
	mining.restore_vein(20000)
	assert(mining.remaining_units == mining.max_units, "Vein stock must respect its configured maximum")
	mining.queue_free()
	bridge.queue_free()

func _test_offline_regeneration_round_trip() -> void:
	var mining = MiningNode.new()
	mining.mineral_id = "gold_ore"
	mining.max_units = 5
	mining.remaining_units = 1
	mining.regen_interval_seconds = 60
	root.add_child(mining)
	mining.last_regen_unix = 1000
	var saved: Dictionary = mining.to_save_dict()
	var restored = MiningNode.new()
	restored.mineral_id = "gold_ore"
	root.add_child(restored)
	assert(restored.load_save_dict(saved, 1120))
	assert(restored.remaining_units == 3, "Two elapsed intervals should restore two units while offline")
	assert(restored.last_regen_unix == 1120)
	assert(int(restored.to_save_dict()["max_units"]) == 5)
	mining.queue_free()
	restored.queue_free()

func _test_regeneration_caps_and_clock_rollback() -> void:
	var mining = MiningNode.new()
	mining.max_units = 5
	mining.remaining_units = 4
	mining.regen_interval_seconds = 60
	root.add_child(mining)
	mining.last_regen_unix = 1000
	assert(mining.apply_elapsed_regeneration(1300) == 1)
	assert(mining.remaining_units == 5 and mining.last_regen_unix == 1300)
	mining.remaining_units = 4
	assert(mining.apply_elapsed_regeneration(1359) == 0)
	assert(mining.apply_elapsed_regeneration(1360) == 1)
	assert(mining.remaining_units == 5)
	mining.remaining_units = 1
	mining.last_regen_unix = 2000
	assert(mining.apply_elapsed_regeneration(1990) == 0)
	assert(mining.remaining_units == 1 and mining.last_regen_unix == 2000, "Clock rollback must not change stock or timestamp")
	mining.queue_free()

func _test_legacy_vein_save_without_regen_fields() -> void:
	var mining = MiningNode.new()
	mining.mineral_id = "coal_ore"
	mining.max_units = 5
	root.add_child(mining)
	var legacy := {"schema_version": 1, "mineral_id": "coal_ore", "remaining_units": 2}
	assert(mining.load_save_dict(legacy, 1200))
	assert(mining.remaining_units == 2)
	assert(mining.max_units == 5)
	assert(mining.last_regen_unix == 1200, "Legacy save should start a fresh regen clock")
	var before := mining.to_save_dict()
	assert(not mining.load_save_dict({"schema_version": 1, "mineral_id": "coal_ore", "remaining_units": 6, "max_units": 5}, 1200))
	assert(mining.remaining_units == int(before["remaining_units"]), "Invalid maximum must not partially mutate the vein")
	mining.queue_free()

func _test_vein_registry_save_restore_and_atomic_rejection() -> void:
	var registry = VeinRegistry.new()
	root.add_child(registry)
	var first = MiningNode.new()
	first.mineral_id = "iron_ore"
	first.max_units = 8
	first.remaining_units = 2
	first.regen_interval_seconds = 60
	root.add_child(first)
	first.last_regen_unix = 1000
	var second = MiningNode.new()
	second.mineral_id = "copper_ore"
	second.max_units = 6
	second.remaining_units = 4
	second.regen_interval_seconds = 60
	root.add_child(second)
	second.last_regen_unix = 1000
	assert(registry.register_vein("mine/sector-a/vein-01", first))
	assert(registry.register_vein("mine/sector-a/vein-02", second))
	assert(not registry.register_vein("mine/sector-a/vein-01", second), "Stable IDs must not overwrite another live vein")
	var saved: Dictionary = registry.to_save_dict()
	assert(registry.get_registered_ids() == PackedStringArray(["mine/sector-a/vein-01", "mine/sector-a/vein-02"]))
	first.remaining_units = 1
	second.remaining_units = 1
	assert(registry.restore_save_dict(saved, 1120))
	assert(first.remaining_units == 4, "Registry restore should apply offline time to the first vein")
	assert(second.remaining_units == 6, "Registry restore should cap the second vein at capacity")
	var before_first := first.to_save_dict()
	var before_second := second.to_save_dict()
	var bad := registry.to_save_dict()
	bad["veins"]["mine/sector-a/vein-02"] = {"schema_version": 2, "mineral_id": "copper_ore", "remaining_units": -1}
	assert(not registry.restore_save_dict(bad, 1300), "Invalid record must reject the complete registry restore")
	assert(first.to_save_dict()["remaining_units"] == before_first["remaining_units"], "Invalid batch must not partially mutate earlier records")
	assert(second.to_save_dict()["remaining_units"] == before_second["remaining_units"])
	registry.auto_apply_elapsed_time_on_restore = false
	first.remaining_units = 1
	second.remaining_units = 1
	assert(registry.restore_save_dict(saved, 1120))
	assert(first.remaining_units == 2 and second.remaining_units == 4, "Disabled auto-regeneration must restore saved stock without adding offline units")
	assert(not registry.restore_save_dict({"schema_version": 1, "veins": {"unknown-id": saved["veins"]["mine/sector-a/vein-01"]}}, 1300))
	assert(registry.unregister_vein("mine/sector-a/vein-01", first))
	assert(not registry.unregister_vein("mine/sector-a/vein-01", first))
	registry.queue_free()
	first.queue_free()
	second.queue_free()
