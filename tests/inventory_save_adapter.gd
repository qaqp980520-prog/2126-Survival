extends SceneTree

const Adapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")

func _initialize() -> void:
	_test_round_trip_preserves_world_fields()
	_test_accepts_legacy_m1_3_inventory_shape()
	_test_accepts_integer_valued_float_version()
	_test_rejects_unknown_item_atomically()
	_test_rejects_malformed_counts_and_days()
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

func _test_accepts_legacy_m1_3_inventory_shape() -> void:
	# Mirrors the M1.3.4 source's actual top-level save keys and inventory IDs.
	var old_world := {
		"version": 2,
		"inventory": {
			"credits": 100, "meat": 2, "hide": 1, "bone": 3,
			"berries": 4, "seeds": 5, "herbs": 6, "food": 7
		},
		"game_day": 8,
		"stamina": 75.0,
		"selected_hotbar_slot": 2,
		"hotbar_slots": ["", "meat", "", "food", "", "", "", "", "", ""],
		"world_state": {
			"harvested_world_crop_ids": ["crop_1"],
			"planted_crops": [{"position": [1.0, 0.0, 2.0], "seed_type": "berries"}]
		}
	}
	var converted: Dictionary = Adapter.world_save_to_inventory_payload(old_world)
	assert(converted.get("ok", false))
	var payload: Dictionary = converted["payload"]
	assert(payload["game_day"] == 8)
	assert(payload["inventory"]["credits"] == 100)
	assert(payload["inventory"]["food"] == 7)

	var restored: Dictionary = Adapter.apply_inventory_payload_to_world_save(old_world, payload)
	assert(restored.get("ok", false))
	var updated: Dictionary = restored["world_save"]
	assert(updated["stamina"] == 75.0)
	assert(updated["selected_hotbar_slot"] == 2)
	assert(updated["hotbar_slots"] == old_world["hotbar_slots"])
	assert(updated["world_state"] == old_world["world_state"])
	assert(updated["inventory"]["herbs"] == 6)

func _test_accepts_integer_valued_float_version() -> void:
	# The legacy validator casts numeric versions to int, so 2.0 was accepted.
	var old_world := {"version": 2.0, "game_day": 1, "inventory": {"meat": 1}}
	assert(Adapter.world_save_to_inventory_payload(old_world).get("ok", false))

func _test_rejects_unknown_item_atomically() -> void:
	var old_world := {"version": 1, "game_day": 3, "inventory": {"mystery_item": 9}}
	var converted: Dictionary = Adapter.world_save_to_inventory_payload(old_world)
	assert(not converted.get("ok", false))
	var payload := {"schema_version": 1, "game_day": 9, "inventory": {"mystery_item": 1}}
	var restored: Dictionary = Adapter.apply_inventory_payload_to_world_save(old_world, payload)
	assert(not restored.get("ok", false))
	assert(old_world["game_day"] == 3)
	assert(old_world["inventory"]["mystery_item"] == 9)

func _test_rejects_malformed_counts_and_days() -> void:
	var fractional_count := {"version": 2, "game_day": 1, "inventory": {"meat": 1.5}}
	assert(not Adapter.world_save_to_inventory_payload(fractional_count).get("ok", false))
	var negative_count := {"version": 2, "game_day": 1, "inventory": {"meat": -1}}
	assert(not Adapter.world_save_to_inventory_payload(negative_count).get("ok", false))
	var too_large_count := {"version": 2, "game_day": 1, "inventory": {"meat": 1000000001}}
	assert(not Adapter.world_save_to_inventory_payload(too_large_count).get("ok", false))
	var fractional_day := {"version": 2, "game_day": 1.5, "inventory": {"meat": 1}}
	assert(not Adapter.world_save_to_inventory_payload(fractional_day).get("ok", false))
	var too_large_day := {"version": 2, "game_day": 1000000001, "inventory": {"meat": 1}}
	assert(not Adapter.world_save_to_inventory_payload(too_large_day).get("ok", false))
	var bad_schema := {"schema_version": 2, "game_day": 1, "inventory": {"meat": 1}}
	assert(not Adapter.apply_inventory_payload_to_world_save({"version": 2}, bad_schema).get("ok", false))

func _test_rejects_unsupported_world_version() -> void:
	var old_world := {"version": 3, "game_day": 1, "inventory": {"meat": 1}}
	assert(not Adapter.world_save_to_inventory_payload(old_world).get("ok", false))
