extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Registry = preload("res://systems/MineralVeinRegistry.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_unload_save_reload_and_offline_regeneration()
	await process_frame
	await _test_invalid_restore_is_atomic()
	await process_frame
	print("Mineral vein chunk-stream persistence tests passed.")
	quit(0)

func _test_unload_save_reload_and_offline_regeneration() -> void:
	var registry = Registry.new()
	root.add_child(registry)
	await process_frame

	var first = MiningNode.new()
	first.mineral_id = "gold_ore"
	first.max_units = 8
	first.remaining_units = 1
	first.regen_interval_seconds = 60
	root.add_child(first)
	await process_frame
	first.last_regen_unix = 1000

	var stable_id := "earth/sector-12/chunk--4/vein-gold-01"
	assert(registry.register_vein(stable_id, first, 1000))
	first.remaining_units = 1
	first.last_regen_unix = 1000
	assert(registry.unregister_vein(stable_id, first, 1000))
	assert(not registry.get_registered_ids().has(stable_id))
	assert(registry.get_saved_ids().has(stable_id))

	var save_after_unload: Dictionary = registry.to_save_dict()
	var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(save_after_unload))
	assert(json_roundtrip is Dictionary, "Registry payload must survive JSON serialization")
	assert(registry.validate_save_dict(json_roundtrip, 1000), "JSON-decoded registry schema must validate before restore")
	assert(save_after_unload["veins"].has(stable_id), "Unloaded chunk records must remain serializable")
	assert(int(save_after_unload["veins"][stable_id]["remaining_units"]) == 1)

	first.queue_free()
	await process_frame

	var reloaded = MiningNode.new()
	reloaded.mineral_id = "gold_ore"
	reloaded.max_units = 8
	reloaded.remaining_units = 8
	reloaded.regen_interval_seconds = 60
	root.add_child(reloaded)
	await process_frame
	assert(registry.register_vein(stable_id, reloaded, 1120), "Reloaded chunk must restore using its stable ID")
	assert(reloaded.remaining_units == 3, "Two elapsed intervals must regenerate two units from the saved one-unit vein")
	assert(registry.get_registered_ids().has(stable_id))

	registry.queue_free()
	reloaded.queue_free()
	await process_frame

func _test_invalid_restore_is_atomic() -> void:
	var registry = Registry.new()
	root.add_child(registry)
	await process_frame

	var live = MiningNode.new()
	live.mineral_id = "iron_ore"
	live.max_units = 8
	live.remaining_units = 4
	live.regen_interval_seconds = 60
	root.add_child(live)
	await process_frame
	live.last_regen_unix = 1000
	var stable_id := "earth/sector-0/chunk-0/vein-iron-02"
	assert(registry.register_vein(stable_id, live, 1000))

	var before: Dictionary = registry.to_save_dict()
	var invalid: Dictionary = before.duplicate(true)
	invalid["veins"][stable_id]["remaining_units"] = -1
	assert(not registry.restore_save_dict(invalid, 1120), "Negative stock must reject the complete registry restore")
	assert(live.remaining_units == 4, "Rejected restore must not partially mutate a live vein")
	assert(registry.to_save_dict()["veins"][stable_id]["remaining_units"] == before["veins"][stable_id]["remaining_units"])

	var unknown_mineral: Dictionary = {
		"schema_version": 1,
		"veins": {
			"earth/sector-9/chunk-9/ghost": {
				"schema_version": 2,
				"mineral_id": "unknown_ore",
				"remaining_units": 2,
				"max_units": 4,
				"regen_interval_seconds": 60,
				"last_regen_unix": 1000
			}
		}
	}
	assert(not registry.restore_save_dict(unknown_mineral, 1120), "Unregistered mineral IDs must be rejected even for unloaded chunks")
	assert(live.remaining_units == 4)

	registry.queue_free()
	live.queue_free()
	await process_frame
