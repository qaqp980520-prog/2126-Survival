extends Node
class_name SurvivalWorldBridge

## Thin adapter between world pickups/mining outputs and SurvivalInventory.
## It does not replace existing M1.x scenes; integrate it deliberately with the active world controller.

const InventoryModel = preload("res://systems/SurvivalInventory.gd")
const SaveAdapter = preload("res://systems/SurvivalInventorySaveAdapter.gd")

signal inventory_changed(summary: Dictionary)
signal item_collected(item_id: String, amount: int)
signal item_dropped(item_id: String, amount: int)

@export var inventory_script: Script
var inventory: RefCounted

func _ready() -> void:
    if inventory_script != null:
        inventory = inventory_script.new()
    else:
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

## Convert the current inventory into an existing M1.3 world-save envelope.
## Unrelated fields (player position, stamina, hotbar, crops, world state) are preserved.
func serialize_world_save(existing_world_save: Dictionary) -> Dictionary:
    if inventory == null:
        return {"ok": false, "error": "inventory_unavailable"}
    return SaveAdapter.apply_inventory_payload_to_world_save(existing_world_save, inventory.to_save_dict())

## Restore only inventory/day from a legacy world-save envelope. Validation occurs before mutation.
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

func _is_valid_amount(item_id: String, amount: int) -> bool:
    return inventory != null and not item_id.strip_edges().is_empty() and amount > 0

func _emit_inventory_changed() -> void:
    inventory_changed.emit(get_summary())
