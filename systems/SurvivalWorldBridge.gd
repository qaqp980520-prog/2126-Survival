extends Node
class_name SurvivalWorldBridge

const InventoryModel = preload("res://systems/SurvivalInventory.gd")
const SaveAdapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")
const REQUIRED_INVENTORY_METHODS: Array[String] = [
	"add_item", "remove_item", "total_weight_kg", "carry_limit_kg",
	"movement_multiplier", "can_jump", "is_overweight", "is_super_heavy",
	"to_save_dict", "load_save_dict"
]

signal inventory_changed(summary: Dictionary)
signal item_collected(item_id: String, amount: int)
signal item_dropped(item_id: String, amount: int)
signal item_consumed(item_id: String, amount: int)

@export var inventory_script: Script
var inventory: RefCounted

func bind_inventory(candidate: RefCounted) -> bool:
	if candidate == null or not _has_inventory_contract(candidate):
		return false
	inventory = candidate
	if is_inside_tree() and is_node_ready():
		_emit_inventory_changed()
	return true

func _ready() -> void:
	if inventory == null:
		if inventory_script != null:
			var candidate: Variant = inventory_script.new()
			if candidate is RefCounted and _has_inventory_contract(candidate):
				inventory = candidate
		if inventory == null:
			inventory = InventoryModel.new()
	_emit_inventory_changed()

func collect_world_item(item_id: String, amount: int = 1) -> bool:
	if not _is_valid_amount(item_id, amount):
		return false
	var changed: int = inventory.add_item(item_id, amount)
	if changed <= 0:
		return false
	item_collected.emit(item_id, changed)
	_emit_inventory_changed()
	return true

func collect_mined_ore(ore_id: String, amount: int) -> bool:
	return collect_world_item(ore_id, amount)

func drop_item(item_id: String, amount: int = 1) -> bool:
	if not _is_valid_amount(item_id, amount):
		return false
	var removed: int = inventory.remove_item(item_id, amount)
	if removed <= 0:
		return false
	item_dropped.emit(item_id, removed)
	_emit_inventory_changed()
	return true

func consume_item(item_id: String, amount: int = 1) -> bool:
	if not _is_valid_amount(item_id, amount):
		return false
	var removed: int = inventory.remove_item(item_id, amount)
	if removed <= 0:
		return false
	item_consumed.emit(item_id, removed)
	_emit_inventory_changed()
	return true

func get_item_count(item_id: String) -> int:
	if inventory == null:
		return 0
	if inventory.has_method("get_item_count"):
		return _validated_bridge_count(inventory.call("get_item_count", item_id))
	var counts: Variant = inventory.get("counts")
	if not (counts is Dictionary):
		return 0
	var amount: Variant = counts.get(item_id, 0)
	return _validated_bridge_count(amount)

func get_weight_kg() -> float:
	return inventory.total_weight_kg() if inventory != null else 0.0

func get_carry_limit_kg() -> float:
	return inventory.carry_limit_kg() if inventory != null else 65.0

func get_movement_multiplier() -> float:
	return inventory.movement_multiplier() if inventory != null else 1.0

func can_player_jump() -> bool:
	return inventory.can_jump() if inventory != null else true

func get_summary() -> Dictionary:
	if inventory == null:
		return {"weight_kg":0.0,"limit_kg":65.0,"overweight":false,"super_heavy":false,"movement_multiplier":1.0,"can_jump":true}
	return {
		"weight_kg":inventory.total_weight_kg(),
		"limit_kg":inventory.carry_limit_kg(),
		"overweight":inventory.is_overweight(),
		"super_heavy":inventory.is_super_heavy(),
		"movement_multiplier":inventory.movement_multiplier(),
		"can_jump":inventory.can_jump()
	}

func serialize_inventory() -> Dictionary:
	return inventory.to_save_dict() if inventory != null else {}

func restore_inventory(data: Dictionary) -> bool:
	if inventory == null or not inventory.load_save_dict(data):
		return false
	_emit_inventory_changed()
	return true

func serialize_world_save(existing_world_save: Dictionary) -> Dictionary:
	if inventory == null:
		return {"ok":false,"error":"inventory_unavailable"}
	return SaveAdapter.apply_inventory_payload_to_world_save(existing_world_save, inventory.to_save_dict())

func restore_world_save(world_save: Dictionary) -> bool:
	if inventory == null:
		return false
	var converted: Dictionary = SaveAdapter.world_save_to_inventory_payload(world_save)
	if not bool(converted.get("ok", false)):
		return false
	var payload: Dictionary = converted["payload"]
	if not inventory.load_save_dict(payload):
		return false
	_emit_inventory_changed()
	return true

func _has_inventory_contract(candidate: Object) -> bool:
	for method_name in REQUIRED_INVENTORY_METHODS:
		if not candidate.has_method(method_name):
			return false
	return true

func _validated_bridge_count(value: Variant) -> int:
	if not (value is int or value is float):
		return 0
	var numeric: float = float(value)
	if not is_finite(numeric) or numeric < 0.0 or numeric > float(InventoryModel.MAX_SAVED_COUNT):
		return 0
	if floorf(numeric) != numeric:
		return 0
	return int(numeric)

func _is_valid_amount(item_id: String, amount: int) -> bool:
	return inventory != null and not item_id.strip_edges().is_empty() and amount > 0

func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_summary())
