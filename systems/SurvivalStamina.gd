extends RefCounted
class_name SurvivalStamina

## Small deterministic stamina model shared by the production SurfaceWorld.
## Balance values are prototype defaults and remain easy to tune independently.
const SAVE_SCHEMA_VERSION: int = 1
const MAX_STAMINA: float = 100.0
const MOVE_DRAIN_PER_SECOND: float = 2.0
const IDLE_RECOVERY_PER_SECOND: float = 6.0
const JUMP_COST: float = 10.0

var current_stamina: float = MAX_STAMINA

func tick(delta_seconds: float, moving: bool, movement_multiplier: float = 1.0) -> void:
	if not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return
	if moving:
		var safe_multiplier: float = movement_multiplier if is_finite(movement_multiplier) else 1.0
		safe_multiplier = clampf(safe_multiplier, 0.1, 1.0)
		var drain_rate: float = MOVE_DRAIN_PER_SECOND / safe_multiplier
		current_stamina = maxf(0.0, current_stamina - drain_rate * delta_seconds)
	else:
		current_stamina = minf(MAX_STAMINA, current_stamina + IDLE_RECOVERY_PER_SECOND * delta_seconds)

func can_jump() -> bool:
	return current_stamina >= JUMP_COST

func spend_jump() -> bool:
	if not can_jump():
		return false
	current_stamina = maxf(0.0, current_stamina - JUMP_COST)
	return true

func add_stamina(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var before: float = current_stamina
	current_stamina = minf(MAX_STAMINA, current_stamina + amount)
	return current_stamina - before

func reset() -> void:
	current_stamina = MAX_STAMINA

func to_save_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"current": current_stamina
	}

func validate_save_dict(data: Dictionary) -> bool:
	if data.size() != 2 or not data.has("schema_version") or not data.has("current"):
		return false
	var schema: Variant = data.get("schema_version")
	var current: Variant = data.get("current")
	if not (schema is int) or int(schema) != SAVE_SCHEMA_VERSION:
		return false
	if not (current is int or current is float):
		return false
	var value: float = float(current)
	return is_finite(value) and value >= 0.0 and value <= MAX_STAMINA

func load_save_dict(data: Dictionary) -> bool:
	if not validate_save_dict(data):
		return false
	current_stamina = float(data["current"])
	return true
