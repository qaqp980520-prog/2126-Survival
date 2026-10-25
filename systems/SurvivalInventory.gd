extends RefCounted
class_name SurvivalInventory

## Shared inventory data model for 2126 Survival prototypes.
## Callers own UI and world interactions; this class owns counts, weights and save serialization.

const BASE_LIMIT_KG: float = 65.0
const LIMIT_GAIN_PER_DAY_KG: float = 0.2
const SUPER_HEAVY_KG: float = 90.0
const UNKNOWN_ITEM_WEIGHT_KG: float = 1.0
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
		# Unknown item IDs must not silently become weightless.
		var unit_weight := float(ITEM_WEIGHTS.get(item_id, UNKNOWN_ITEM_WEIGHT_KG))
		total += unit_weight * float(amount)
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
	# Validate the entire payload before mutating live inventory state.
	if not data.has("schema_version") or not _is_finite_number(data["schema_version"]):
		return false
	if int(data["schema_version"]) != 1 or float(data["schema_version"]) != 1.0:
		return false
	if not data.has("inventory") or not (data["inventory"] is Dictionary):
		return false
	var day_value: Variant = data.get("game_day", 1)
	if not _is_finite_number(day_value) or float(day_value) < 1.0 or float(day_value) != floorf(float(day_value)):
		return false
	var restored: Dictionary = data["inventory"].duplicate(true)
	for item_id in restored.keys():
		if not (item_id is String) or item_id.strip_edges().is_empty():
			return false
		var amount: Variant = restored[item_id]
		if not _is_finite_number(amount) or float(amount) < 0.0 or float(amount) != floorf(float(amount)):
			return false
	# Commit only after all fields have passed validation.
	counts = restored
	for item_id in ITEM_WEIGHTS.keys():
		if not counts.has(item_id):
			counts[item_id] = 0
	game_day = int(day_value)
	return true

func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return number == number and absf(number) < 1000000000000.0
