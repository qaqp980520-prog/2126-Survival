extends RefCounted
class_name SurvivalInventorySaveAdapter

## Converts only the inventory boundary; preserves the legacy world-save envelope.
## This adapter is deliberately not wired into the active world controller yet.
const InventoryModel = preload("res://systems/SurvivalInventory.gd")

static func world_save_to_inventory_payload(world_save: Dictionary) -> Dictionary:
	if not _has_supported_world_version(world_save):
		return {"ok": false, "error": "unsupported_world_schema"}
	var world_day: Variant = world_save.get("game_day", 1)
	var world_inventory: Variant = world_save.get("inventory", null)
	if not (world_inventory is Dictionary):
		return {"ok": false, "error": "invalid_world_inventory"}
	var candidate := {
		"schema_version": InventoryModel.SAVE_SCHEMA_VERSION,
		"game_day": world_day,
		"inventory": world_inventory.duplicate(true)
	}
	var inventory = InventoryModel.new()
	if not inventory.load_save_dict(candidate):
		return {"ok": false, "error": "invalid_inventory_payload"}
	return {"ok": true, "payload": inventory.to_save_dict()}

static func apply_inventory_payload_to_world_save(world_save: Dictionary, inventory_payload: Dictionary) -> Dictionary:
	if not _has_supported_world_version(world_save):
		return {"ok": false, "error": "unsupported_world_schema"}
	var inventory = InventoryModel.new()
	if not inventory.load_save_dict(inventory_payload):
		return {"ok": false, "error": "invalid_inventory_payload"}
	var updated: Dictionary = world_save.duplicate(true)
	updated["inventory"] = inventory.counts.duplicate(true)
	updated["game_day"] = inventory.game_day
	return {"ok": true, "world_save": updated}

static func _has_supported_world_version(world_save: Dictionary) -> bool:
	var version: Variant = world_save.get("version", null)
	return version is int and (version == 1 or version == 2)
