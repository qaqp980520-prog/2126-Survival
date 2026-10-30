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

var slots: Array[String] = ["berries", "herbs", "meat", "food"]
var selected_slot: int = 0
var _consuming: bool = false

func get_slot_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return ""
	return slots[slot_index]

func get_slot_count(slot_index: int, inventory_bridge: Node) -> int:
	var item_id: String = get_slot_item(slot_index)
	if item_id.is_empty() or inventory_bridge == null or not inventory_bridge.has_method("get_item_count"):
		return 0
	return int(inventory_bridge.call("get_item_count", item_id))

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

func consume_selected(inventory_bridge: Node, stamina: RefCounted) -> Dictionary:
	if _consuming:
		return {"ok": false, "reason": "interaction_in_progress"}
	if inventory_bridge == null or stamina == null:
		return {"ok": false, "reason": "unavailable"}
	if not inventory_bridge.has_method("consume_item") or not inventory_bridge.has_method("collect_world_item") or not inventory_bridge.has_method("get_item_count") or not stamina.has_method("add_stamina"):
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
	if get_slot_count(selected_slot, inventory_bridge) <= 0:
		return {"ok": false, "reason": "empty", "item_id": item_id}
	_consuming = true
	if not bool(inventory_bridge.call("consume_item", item_id, 1)):
		_consuming = false
		return {"ok": false, "reason": "inventory_rejected", "item_id": item_id}
	var restored: float = float(stamina.call("add_stamina", float(STAMINA_RESTORE[item_id])))
	if restored <= 0.0:
		var returned: bool = bool(inventory_bridge.call("collect_world_item", item_id, 1))
		_consuming = false
		return {"ok": false, "reason": "stamina_rejected", "rollback_complete": returned, "item_id": item_id}
	_consuming = false
	return {
		"ok": true,
		"reason": "consumed",
		"item_id": item_id,
		"restored": restored,
		"remaining": get_slot_count(selected_slot, inventory_bridge)
	}

func reset() -> void:
	slots = ["berries", "herbs", "meat", "food"]
	selected_slot = 0
	_consuming = false

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
