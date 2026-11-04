extends RefCounted

var counts: Dictionary = {}

func add_item(_item_id: String, _amount: int = 1) -> int:
	return 0

func remove_item(_item_id: String, _amount: int = 1) -> int:
	return 0

func total_weight_kg() -> float:
	return 0.0

func carry_limit_kg() -> float:
	return 65.0

func movement_multiplier() -> float:
	return 1.0

func can_jump() -> bool:
	return true

func is_overweight() -> bool:
	return false

func is_super_heavy() -> bool:
	return false

func to_save_dict() -> Dictionary:
	return {"schema_version": 1, "game_day": 1, "inventory": counts.duplicate(true)}

func load_save_dict(data: Dictionary) -> bool:
	var payload: Variant = data.get("inventory", null)
	if not (payload is Dictionary):
		return false
	counts = payload.duplicate(true)
	return true
