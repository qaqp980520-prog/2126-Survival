extends RefCounted
class_name SurvivalQuickUse

## Four-slot consumable hotbar. Inventory remains authoritative for item counts.
const SAVE_SCHEMA_VERSION: int = 1
const SLOT_COUNT: int = 4
const DEFAULT_SLOTS: Array[String] = ["berries", "herbs", "meat", "food"]
const STAMINA_RESTORE: Dictionary = {
	"berries": 8.0,
	"herbs": 12.0,
	"meat": 24.0,
	"food": 30.0
}

var slots: Array[String] = DEFAULT_SLOTS.duplicate()
var selected_slot: int = 0

func get_slot_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return ""
	return slots[slot_index]

func get_slot_count(slot_index: int, inventory: RefCounted) -> int:
	var item_id: String = get_slot_item(slot_index)
	if item_id.is_empty() or inventory == null:
		return 0
	var counts: Variant = inventory.get("counts")
	if not (counts is Dictionary):
		return 0
	var count: Variant = counts.get(item_id, 0)
	if not (count is int) or int(count) < 0:
		return 0
	return int(count)

func select_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	selected_slot = slot_index
	return true

func assign_slot(slot_index: int, item_id: String) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or not STAMINA_RESTORE.has(item_id):
		return false
	slots[slot_index] = item_id
	return true

func consume_selected(inventory: RefCounted, stamina: RefCounted) -> Dictionary:
	if inventory == null or stamina == null:
		return {"ok": false, "reason": "unavailable"}
	if not inventory.has_method("remove_item") or not inventory.has_method("add_item") or not stamina.has_method("add_stamina"):
		return {"ok": false, "reason": "contract"}
	var item_id: String = get_slot_item(selected_slot)
	if item_id.is_empty() or not STAMINA_RESTORE.has(item_id):
		return {"ok": false, "reason": "invalid_slot"}
	var current_value: Variant = stamina.get("current_stamina")
	var maximum: float = float(stamina.call("get_max_stamina")) if stamina.has_method("get_max_stamina") else 0.0
	if not (current_value is int or current_value is float) or not is_finite(float(current_value)) or maximum <= 0.0:
		return {"ok": false, "reason": "stamina_state"}
	if float(current_value) >= maximum:
		return {"ok": false, "reason": "stamina_full", "item_id": item_id}
	if get_slot_count(selected_slot, inventory) <= 0:
		return {"ok": false, "reason": "empty", "item_id": item_id}
	var removed: int = int(inventory.call("remove_item", item_id, 1))
	if removed != 1:
		return {"ok": false, "reason": "inventory_rejected", "item_id": item_id}
	var restored: float = float(stamina.call("add_stamina", float(STAMINA_RESTORE[item_id])))
	if restored <= 0.0:
		var returned: int = int(inventory.call("add_item", item_id, 1))
		return {"ok": false, "reason": "stamina_rejected", "rollback_complete": returned == 1, "item_id": item_id}
	return {
		"ok": true,
		"reason": "consumed",
		"item_id": item_id,
		"restored": restored,
		"remaining": get_slot_count(selected_slot, inventory)
	}

func reset() -> void:
	slots = DEFAULT_SLOTS.duplicate()
	selected_slot = 0

func to_save_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"slots": slots.duplicate(),
		"selected_slot": selected_slot
	}

func validate_save_dict(data: Dictionary) -> bool:
	if data.size() != 3 or not data.has("schema_version") or not data.has("slots") or not data.has("selected_slot"):
		return false
	var schema: Variant = data.get("schema_version")
	var raw_slots: Variant = data.get("slots")
	var selected: Variant = data.get("selected_slot")
	if not (schema is int) or int(schema) != SAVE_SCHEMA_VERSION:
		return false
	if not (selected is int) or int(selected) < 0 or int(selected) >= SLOT_COUNT:
		return false
	if not (raw_slots is Array) or raw_slots.size() != SLOT_COUNT:
		return false
	for item_id in raw_slots:
		if not (item_id is String) or not STAMINA_RESTORE.has(item_id):
			return false
	return true

func load_save_dict(data: Dictionary) -> bool:
	if not validate_save_dict(data):
		return false
	var restored_slots: Array[String] = []
	for item_id in data["slots"]:
		restored_slots.append(str(item_id))
	slots = restored_slots
	selected_slot = int(data["selected_slot"])
	return true
