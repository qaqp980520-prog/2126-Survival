extends RefCounted
class_name SurvivalInventory

## Shared inventory data model for 2126 Survival prototypes.
## Callers own UI and world interactions; this class owns counts, weights and save serialization.

const BASE_LIMIT_KG: float = 65.0
const LIMIT_GAIN_PER_DAY_KG: float = 0.2
const SUPER_HEAVY_KG: float = 90.0
const ITEM_WEIGHTS: Dictionary = {
	"credits": 0.0,
	"meat": 0.75,
	"hide": 1.1,
	"bone": 0.35,
	"berries": 0.08,
	"seeds": 0.02,
	"herbs": 0.12,
	"food": 0.5,
	"rock": 2.5,
	"iron_ore": 3.0,
	"copper_ore": 2.8,
	"crystal": 0.6
}

var counts: Dictionary = {}
var game_day: int = 1

func _init(initial_counts: Dictionary = {}, initial_day: int = 1) -> void:
	counts = initial_counts.duplicate(true)
	game_day = maxi(1, initial_day)
	for item_id in ITEM_WEIGHTS.keys():
		if not counts.has(item_id):
			counts[item_id] = 0

func carry_limit_kg() -> float:
	return BASE_LIMIT_KG + float(maxi(0, game_day - 1)) * LIMIT_GAIN_PER_DAY_KG

func total_weight_kg() -> float:
	var total := 0.0
	for item_id in counts.keys():
		var amount := maxi(0, int(counts[item_id]))
		total += float(ITEM_WEIGHTS.get(item_id, 0.0)) * float(amount)
	return total

func is_overweight() -> bool:
	return total_weight_kg() > carry_limit_kg()

func is_super_heavy() -> bool:
	return total_weight_kg() > SUPER_HEAVY_KG

func movement_multiplier() -> float:
	if not is_overweight():
		return 1.0
	return 0.42 if is_super_heavy() else 0.68

func can_jump() -> bool:
	return not is_super_heavy()

func add_item(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	if not counts.has(item_id):
		counts[item_id] = 0
	counts[item_id] = maxi(0, int(counts[item_id])) + amount
	return amount

func remove_item(item_id: String, amount: int = 1) -> int:
	if amount <= 0 or not counts.has(item_id):
		return 0
	var removed := mini(amount, maxi(0, int(counts[item_id])))
	counts[item_id] = int(counts[item_id]) - removed
	return removed

func set_game_day(day: int) -> void:
	game_day = maxi(1, day)

func to_save_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"game_day": game_day,
		"inventory": counts.duplicate(true)
	}

func load_save_dict(data: Dictionary) -> bool:
	if not data.has("inventory") or not (data["inventory"] is Dictionary):
		return false
	var restored: Dictionary = data["inventory"].duplicate(true)
	for item_id in restored.keys():
		if not (restored[item_id] is int or restored[item_id] is float):
			return false
		if int(restored[item_id]) < 0:
			return false
	counts = restored
	for item_id in ITEM_WEIGHTS.keys():
		if not counts.has(item_id):
			counts[item_id] = 0
	game_day = maxi(1, int(data.get("game_day", 1)))
	return true
