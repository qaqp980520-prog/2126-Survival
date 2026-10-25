extends SceneTree

const Adapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")

func _initialize() -> void:
	_test_round_trip_preserves_world_fields()
	_test_rejects_unknown_item_atomically()
	_test_rejects_unsupported_world_version()
	print("Inventory save adapter tests passed.")
	quit()

func _test_round_trip_preserves_world_fields() -> void:
	var old_world := {
		"version": 2,
		"game_day": 4,
		"inventory": {"meat": 2, "rock": 3},
		"crops": [{"id": "crop_a", "growth": 0.5}],
		"world_seed": 12345
	}
	var converted: Dictionary = Adapter.world_save_to_inventory_payload(old_world)
	assert(converted.get("ok", false))
	var payload: Dictionary = converted["payload"]
	assert(payload["schema_version"] == 1)
	assert(payload["game_day"] == 4)
	assert(payload["inventory"]["meat"] == 2)

	var restored: Dictionary = Adapter.apply_inventory_payload_to_world_save(old_world, payload)
	assert(restored.get("ok", false))
	var updated: Dictionary = restored["world_save"]
	assert(updated["version"] == 2)
	assert(updated["world_seed"] == 12345)
	assert(updated["crops"] == old_world["crops"])
	assert(updated["inventory"]["rock"] == 3)

func _test_rejects_unknown_item_atomically() -> void:
	var old_world := {"version": 1, "game_day": 3, "inventory": {"mystery_item": 9}}
	var converted: Dictionary = Adapter.world_save_to_inventory_payload(old_world)
	assert(not converted.get("ok", false))
	var payload := {"schema_version": 1, "game_day": 9, "inventory": {"mystery_item": 1}}
	var restored: Dictionary = Adapter.apply_inventory_payload_to_world_save(old_world, payload)
	assert(not restored.get("ok", false))
	assert(old_world["game_day"] == 3)
	assert(old_world["inventory"]["mystery_item"] == 9)

func _test_rejects_unsupported_world_version() -> void:
	var old_world := {"version": 3, "game_day": 1, "inventory": {"meat": 1}}
	assert(not Adapter.world_save_to_inventory_payload(old_world).get("ok", false))
