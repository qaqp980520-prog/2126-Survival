extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Registry = preload("res://systems/MineralVeinRegistry.gd")
const IRON_ID: String = "earth/sector-30/chunk-0/a-iron-01"
const GOLD_ID: String = "earth/sector-30/chunk-0/z-gold-01"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var registry = Registry.new()
	root.add_child(registry)
	await process_frame
	var iron = _new_vein("iron_ore", 5)
	var gold = _new_vein("gold_ore", 4)
	root.add_child(iron)
	root.add_child(gold)
	await process_frame
	iron.last_regen_unix = now_unix
	gold.last_regen_unix = now_unix
	assert(registry.register_vein(IRON_ID, iron, now_unix))
	assert(registry.register_vein(GOLD_ID, gold, now_unix))

	var before: Dictionary = registry.to_save_dict()
	var invalid_late_record: Dictionary = before.duplicate(true)
	invalid_late_record["veins"][IRON_ID]["remaining_units"] = 2
	invalid_late_record["veins"][GOLD_ID]["remaining_units"] = -1
	assert(not registry.validate_save_dict(invalid_late_record, now_unix), "Validation rejects a payload when a later record is invalid")
	assert(registry.to_save_dict() == before, "Validation is side-effect-free")
	assert(not registry.restore_save_dict(invalid_late_record, now_unix), "Restore rejects the complete multi-vein payload")
	assert(int(iron.remaining_units) == 5, "Earlier valid record is not partially applied")
	assert(int(gold.remaining_units) == 4, "Invalid record leaves its live node unchanged")
	assert(registry.to_save_dict() == before, "Rejected restore preserves the full registry snapshot")

	var valid_update: Dictionary = before.duplicate(true)
	valid_update["veins"][IRON_ID]["remaining_units"] = 3
	valid_update["veins"][GOLD_ID]["remaining_units"] = 2
	assert(registry.validate_save_dict(valid_update, now_unix), "Valid multi-vein payload validates")
	assert(registry.to_save_dict() == before, "Successful validation does not mutate live records")
	assert(registry.restore_save_dict(valid_update, now_unix), "Valid multi-vein payload restores")
	assert(int(iron.remaining_units) == 3 and int(gold.remaining_units) == 2, "Valid payload updates both live nodes")

	assert(registry.unregister_vein(GOLD_ID, gold, now_unix), "Gold record unloads into the stable-ID snapshot")
	gold.queue_free()
	await process_frame
	var with_unloaded: Dictionary = registry.to_save_dict()
	assert(with_unloaded["veins"].has(GOLD_ID), "Unloaded vein remains in the save snapshot")

	var invalid_unloaded: Dictionary = with_unloaded.duplicate(true)
	invalid_unloaded["veins"][GOLD_ID]["mineral_id"] = "unknown_ore"
	assert(not registry.validate_save_dict(invalid_unloaded, now_unix), "Unknown mineral in unloaded record is rejected")
	assert(not registry.restore_save_dict(invalid_unloaded, now_unix), "Invalid unloaded record cannot replace saved registry")
	assert(registry.to_save_dict() == with_unloaded, "Rejected unloaded record preserves all saved IDs and values")
	assert(int(iron.remaining_units) == 3, "Invalid unloaded record does not mutate another live vein")

	var invalid_schema: Dictionary = with_unloaded.duplicate(true)
	invalid_schema["schema_version"] = 1.5
	assert(not registry.restore_save_dict(invalid_schema, now_unix), "Fractional registry schema is rejected")
	assert(registry.to_save_dict() == with_unloaded, "Invalid schema leaves registry unchanged")

	registry.queue_free()
	iron.queue_free()
	await process_frame
	print("Mineral vein registry transactionality tests passed.")
	quit(0)

func _new_vein(mineral_id: String, stock: int) -> Variant:
	var vein = MiningNode.new()
	vein.mineral_id = mineral_id
	vein.max_units = 8
	vein.remaining_units = stock
	vein.regen_interval_seconds = 60
	return vein
