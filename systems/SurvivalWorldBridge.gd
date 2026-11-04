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
	var changed: int = _apply_inventory_operation(StringName("add_item"), item_id, amount, true)
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
	var removed: int = _apply_inventory_operation(StringName("remove_item"), item_id, amount, false)
	if removed <= 0:
		return false
	item_dropped.emit(item_id, removed)
	_emit_inventory_changed()
	return true

func consume_item(item_id: String, amount: int = 1) -> bool:
	if not _is_valid_amount(item_id, amount):
		return false
	var removed: int = _apply_inventory_operation(StringName("remove_item"), item_id, amount, false)
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
	return float(_get_validated_metrics()["weight_kg"])

func get_carry_limit_kg() -> float:
	return float(_get_validated_metrics()["limit_kg"])

func get_movement_multiplier() -> float:
	return float(_get_validated_metrics()["movement_multiplier"])

func can_player_jump() -> bool:
	return bool(_get_validated_metrics()["can_jump"])

func get_summary() -> Dictionary:
	return _get_validated_metrics()

func _get_validated_metrics() -> Dictionary:
	if inventory == null:
		return _default_metrics()
	var weight: float = _read_non_negative_metric("total_weight_kg", 0.0, false)
	var limit: float = _read_non_negative_metric("carry_limit_kg", InventoryModel.BASE_LIMIT_KG, true)
	var overweight: bool = _read_boolean_metric("is_overweight", weight > limit)
	var super_heavy: bool = _read_boolean_metric("is_super_heavy", weight > InventoryModel.SUPER_HEAVY_KG)
	var fallback_multiplier: float = 0.42 if super_heavy else (0.68 if overweight else 1.0)
	var movement_multiplier: float = _read_movement_multiplier(fallback_multiplier)
	var can_jump: bool = _read_boolean_metric("can_jump", not super_heavy)
	return {
		"weight_kg": weight,
		"limit_kg": limit,
		"overweight": overweight,
		"super_heavy": super_heavy,
		"movement_multiplier": movement_multiplier,
		"can_jump": can_jump
	}

func _default_metrics() -> Dictionary:
	return {
		"weight_kg": 0.0,
		"limit_kg": InventoryModel.BASE_LIMIT_KG,
		"overweight": false,
		"super_heavy": false,
		"movement_multiplier": 1.0,
		"can_jump": true
	}

func _read_non_negative_metric(method_name: StringName, fallback: float, require_positive: bool) -> float:
	var value: Variant = inventory.call(method_name)
	if not (value is int or value is float):
		return fallback
	var numeric: float = float(value)
	if not is_finite(numeric) or numeric < 0.0:
		return fallback
	if require_positive and numeric <= 0.0:
		return fallback
	return numeric

func _read_boolean_metric(method_name: StringName, fallback: bool) -> bool:
	var value: Variant = inventory.call(method_name)
	return value if value is bool else fallback

func _read_movement_multiplier(fallback: float) -> float:
	var value: Variant = inventory.call("movement_multiplier")
	if not (value is int or value is float):
		return fallback
	var numeric: float = float(value)
	if not is_finite(numeric) or numeric < 0.0 or numeric > 1.0:
		return fallback
	return numeric

func _apply_inventory_operation(method_name: StringName, item_id: String, requested: int, is_add: bool) -> int:
	if inventory == null or not inventory.has_method(method_name):
		return 0
	var before_count: int = _read_count_snapshot(item_id)
	var raw_result: Variant = inventory.call(method_name, item_id, requested)
	var reported_count: int = _validated_operation_count(raw_result, requested)
	if before_count < 0:
		if reported_count <= 0:
			_emit_inventory_changed()
			return 0
		return reported_count
	var after_count: int = _read_count_snapshot(item_id)
	if after_count < 0:
		_emit_inventory_changed()
		return 0
	var actual_delta: int = after_count - before_count if is_add else before_count - after_count
	if actual_delta != reported_count:
		if actual_delta != 0:
			_emit_inventory_changed()
		return 0
	return reported_count

func _read_count_snapshot(item_id: String) -> int:
	if inventory == null:
		return -1
	var raw_counts: Variant = inventory.get("counts")
	if not (raw_counts is Dictionary):
		return -1
	var raw_count: Variant = raw_counts.get(item_id, 0)
	if not _is_valid_bridge_count(raw_count):
		return -1
	return int(raw_count)

func _validated_operation_count(value: Variant, requested: int) -> int:
	if value is bool or not (value is int or value is float):
		return 0
	var numeric: float = float(value)
	if not is_finite(numeric) or numeric < 1.0 or numeric > float(requested):
		return 0
	if floorf(numeric) != numeric:
		return 0
	return int(numeric)

func _is_valid_bridge_count(value: Variant) -> bool:
	if value is bool or not (value is int or value is float):
		return false
	var numeric: float = float(value)
	return is_finite(numeric) and numeric >= 0.0 and numeric <= float(InventoryModel.MAX_SAVED_COUNT) and floorf(numeric) == numeric

func serialize_inventory() -> Dictionary:
	if inventory == null:
		return {}
	var snapshot: Variant = inventory.call("to_save_dict")
	if not (snapshot is Dictionary):
		return {}
	var snapshot_dictionary: Dictionary = snapshot
	return snapshot_dictionary.duplicate(true)

func restore_inventory(data: Dictionary) -> bool:
	if inventory == null:
		return false
	return _restore_inventory_atomically(data)

func serialize_world_save(existing_world_save: Dictionary) -> Dictionary:
	if inventory == null:
		return {"ok":false,"error":"inventory_unavailable"}
	var snapshot: Variant = inventory.call("to_save_dict")
	if not (snapshot is Dictionary):
		return {"ok":false,"error":"invalid_inventory_snapshot"}
	var snapshot_dictionary: Dictionary = snapshot
	return SaveAdapter.apply_inventory_payload_to_world_save(existing_world_save, snapshot_dictionary.duplicate(true))

func restore_world_save(world_save: Dictionary) -> bool:
	if inventory == null:
		return false
	var converted: Dictionary = SaveAdapter.world_save_to_inventory_payload(world_save)
	if not bool(converted.get("ok", false)):
		return false
	var payload: Dictionary = converted["payload"]
	return _restore_inventory_atomically(payload)

func _restore_inventory_atomically(payload: Dictionary) -> bool:
	if inventory == null:
		return false
	var snapshot_value: Variant = inventory.call("to_save_dict")
	if not (snapshot_value is Dictionary):
		return false
	var snapshot: Dictionary = snapshot_value.duplicate(true)
	var restore_result: Variant = inventory.call("load_save_dict", payload.duplicate(true))
	if restore_result is bool and bool(restore_result):
		_emit_inventory_changed()
		return true
	var rollback_result: Variant = inventory.call("load_save_dict", snapshot.duplicate(true))
	var restored_value: Variant = inventory.call("to_save_dict")
	var rollback_verified: bool = (
		rollback_result is bool
		and bool(rollback_result)
		and restored_value is Dictionary
		and restored_value == snapshot
	)
	if not rollback_verified:
		_emit_inventory_changed()
	return false

func _has_inventory_contract(candidate: Object) -> bool:
	for method_name in REQUIRED_INVENTORY_METHODS:
		if not candidate.has_method(method_name):
			return false
	return true

func _validated_bridge_count(value: Variant) -> int:
	return int(value) if _is_valid_bridge_count(value) else 0

func _is_valid_amount(item_id: String, amount: int) -> bool:
	return inventory != null and not item_id.strip_edges().is_empty() and amount > 0

func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_summary())
