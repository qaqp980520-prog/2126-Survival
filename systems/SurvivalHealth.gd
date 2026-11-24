extends RefCounted
class_name SurvivalHealth

## Deterministic player-health model. Damage is applied by world-owned systems.
const SAVE_SCHEMA_VERSION: int = 1
const MAX_HEALTH: float = 100.0

var current_health: float = MAX_HEALTH
var last_damage_source_id: String = ""
var damage_event_count: int = 0

func get_current_health() -> float:
	return current_health

func get_max_health() -> float:
	return MAX_HEALTH

func is_alive() -> bool:
	return current_health > 0.0

func get_snapshot() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": MAX_HEALTH,
		"is_alive": is_alive(),
		"last_damage_source_id": last_damage_source_id,
		"damage_event_count": damage_event_count
	}

func apply_damage(amount: float, source_entity_id: String) -> Dictionary:
	if not is_finite(amount) or amount <= 0.0:
		return {"ok": false, "reason": "damage_amount_invalid"}
	if source_entity_id.strip_edges().is_empty():
		return {"ok": false, "reason": "damage_source_invalid"}
	if not is_alive():
		return {"ok": false, "reason": "player_defeated"}
	var applied: float = minf(amount, current_health)
	current_health = maxf(0.0, current_health - applied)
	last_damage_source_id = source_entity_id
	damage_event_count += 1
	return {
		"ok": true,
		"applied": applied,
		"current_health": current_health,
		"defeated": not is_alive()
	}

func heal(amount: float) -> Dictionary:
	if not is_finite(amount) or amount <= 0.0:
		return {"ok": false, "reason": "healing_amount_invalid"}
	var before: float = current_health
	current_health = minf(MAX_HEALTH, current_health + amount)
	return {
		"ok": current_health > before,
		"reason": "" if current_health > before else "health_full",
		"restored": current_health - before,
		"current_health": current_health,
		"revived": before <= 0.0 and current_health > 0.0
	}

func reset() -> void:
	current_health = MAX_HEALTH
	last_damage_source_id = ""
	damage_event_count = 0

func to_save_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"current": current_health
	}

func validate_save_dict(data: Dictionary) -> bool:
	if data.size() != 2 or not data.has("schema_version") or not data.has("current"):
		return false
	var schema: Variant = data.get("schema_version")
	var current: Variant = data.get("current")
	if not _is_integer_value(schema) or float(schema) != float(SAVE_SCHEMA_VERSION):
		return false
	if not (current is int or current is float):
		return false
	var value: float = float(current)
	return is_finite(value) and value >= 0.0 and value <= MAX_HEALTH

func load_save_dict(data: Dictionary) -> bool:
	if not validate_save_dict(data):
		return false
	current_health = float(data["current"])
	last_damage_source_id = ""
	damage_event_count = 0
	return true

static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var number: float = float(value)
		return is_finite(number) and floorf(number) == number
	return false
