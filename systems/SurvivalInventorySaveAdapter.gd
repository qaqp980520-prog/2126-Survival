extends RefCounted
class_name SurvivalInventorySaveAdapter

## Converts only the inventory boundary; preserves the legacy world-save envelope.
## This adapter is deliberately not wired into the active world controller yet.
const InventoryModel = preload("res://systems/SurvivalInventory.gd")
const MAX_SAVED_COUNT: int = 1000000000
const MAX_SAVED_GAME_DAY: int = 1000000000

static func world_save_to_inventory_payload(world_save: Dictionary) -> Dictionary:
	if not _has_supported_world_version(world_save):
		return {"ok": false, "error": "unsupported_world_schema"}
	var world_day: Variant = world_save.get("game_day", 1)
	var world_inventory: Variant = world_save.get("inventory", null)
	if not (world_inventory is Dictionary):
		return {"ok": false, "error": "invalid_world_inventory"}
	var candidate := {
		"schema_version": 1,
		"game_day": world_day,
		"inventory": world_inventory.duplicate(true)
	}
	if not _validate_inventory_payload(candidate):
		return {"ok": false, "error": "invalid_inventory_payload"}
	var inventory = InventoryModel.new()
	if not inventory.load_save_dict(candidate):
		return {"ok": false, "error": "inventory_model_rejected_payload"}
	return {"ok": true, "payload": inventory.to_save_dict()}

static func apply_inventory_payload_to_world_save(world_save: Dictionary, inventory_payload: Dictionary) -> Dictionary:
	if not _has_supported_world_version(world_save):
		return {"ok": false, "error": "unsupported_world_schema"}
	if not _validate_inventory_payload(inventory_payload):
		return {"ok": false, "error": "invalid_inventory_payload"}
	var inventory = InventoryModel.new()
	if not inventory.load_save_dict(inventory_payload):
		return {"ok": false, "error": "inventory_model_rejected_payload"}
	var updated: Dictionary = world_save.duplicate(true)
	updated["inventory"] = inventory.counts.duplicate(true)
	updated["game_day"] = inventory.game_day
	return {"ok": true, "world_save": updated}

static func _has_supported_world_version(world_save: Dictionary) -> bool:
	var version: Variant = world_save.get("version", null)
	return _is_integer_in_range(version, 1, 2)

static func _validate_inventory_payload(payload: Dictionary) -> bool:
	var schema: Variant = payload.get("schema_version", null)
	if not _is_integer_in_range(schema, 1, 1):
		return false
	var day: Variant = payload.get("game_day", null)
	if not _is_integer_in_range(day, 1, MAX_SAVED_GAME_DAY):
		return false
	var saved_inventory: Variant = payload.get("inventory", null)
	if not (saved_inventory is Dictionary):
		return false
	for item_id in saved_inventory.keys():
		if not (item_id is String) or not InventoryModel.ITEM_WEIGHTS.has(item_id):
			return false
		if not _is_integer_in_range(saved_inventory[item_id], 0, MAX_SAVED_COUNT):
			return false
	return true

static func _is_integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number >= float(minimum) and number <= float(maximum) and floorf(number) == number
