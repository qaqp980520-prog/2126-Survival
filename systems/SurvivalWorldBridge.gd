extends Node
class_name SurvivalWorldBridge

## Thin adapter between world pickups/mining outputs and SurvivalInventory.
## It does not replace existing M1.x scenes; integrate it deliberately with the active world controller.

signal inventory_changed(summary: Dictionary)
signal item_collected(item_id: String, amount: int)
signal item_dropped(item_id: String, amount: int)

@export var inventory_script: Script
var inventory: RefCounted

func _ready() -> void:
	if inventory == null:
		if inventory_script != null:
			inventory = inventory_script.new()
		else:
			# class_name lookup is available after Godot's script class scan.
			inventory = SurvivalInventory.new()
	_emit_inventory_changed()

## Allows an existing world controller or save loader to inject the single
## inventory instance instead of creating a second independent source of truth.
## Call before the world begins handling pickups/mining.
func bind_inventory(shared_inventory: RefCounted) -> bool:
	if shared_inventory == null:
		return false
	for required_method in ["add_item", "remove_item", "total_weight_kg", "carry_limit_kg", "movement_multiplier", "can_jump", "to_save_dict", "load_save_dict"]:
		if not shared_inventory.has_method(required_method):
			return false
	inventory = shared_inventory
	_emit_inventory_changed()
	return true

func has_bound_inventory() -> bool:
	return inventory != null

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
	# Mining is deliberately routed through the same item-count API as world pickups.
	return collect_world_item(ore_id, amount)

func drop_item(item_id: String, amount: int = 1) -> bool:
	if not _is_valid_amount(item_id, amount):
		return false
	var removed: int = inventory.remove_item(item_id, amount)
	if removed <= 0:
		return false
	item_dropped.emit(item_id, removed)
	# Weight and penalties are recalculated immediately by the inventory model.
	_emit_inventory_changed()
	return true

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
		return {"weight_kg": 0.0, "limit_kg": 65.0, "overweight": false, "super_heavy": false, "movement_multiplier": 1.0, "can_jump": true}
	return {
		"weight_kg": inventory.total_weight_kg(),
		"limit_kg": inventory.carry_limit_kg(),
		"overweight": inventory.is_overweight(),
		"super_heavy": inventory.is_super_heavy(),
		"movement_multiplier": inventory.movement_multiplier(),
		"can_jump": inventory.can_jump()
	}

func serialize_inventory() -> Dictionary:
	return inventory.to_save_dict() if inventory != null else {}

func restore_inventory(data: Dictionary) -> bool:
	if inventory == null or not inventory.load_save_dict(data):
		return false
	_emit_inventory_changed()
	return true

func _is_valid_amount(item_id: String, amount: int) -> bool:
	return inventory != null and not item_id.strip_edges().is_empty() and amount > 0

func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_summary())
