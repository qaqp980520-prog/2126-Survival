extends RefCounted
class_name KrollHydroponicsRules

const BED_COUNT: int = 3
const TARGET_HARVESTS: int = 10
const ROUND_SECONDS: float = 90.0
const MAX_MOISTURE: float = 100.0
const WATER_AMOUNT: float = 28.0
const MOISTURE_DRAIN_PER_SECOND: float = 7.0
const GROWTH_PER_SECOND: float = 12.0
const MIN_GROW_MOISTURE: float = 12.0
const HARVEST_REWARD: int = 15
const REPLANT_MOISTURE: float = 45.0

static func create_beds() -> Array[Dictionary]:
	var beds: Array[Dictionary] = []
	for index in range(BED_COUNT):
		beds.append({"growth": 0.0, "moisture": 65.0, "harvests": 0})
	return beds

static func water(bed: Dictionary) -> bool:
	if float(bed.get("growth", 0.0)) >= 100.0:
		return false
	var before: float = float(bed.get("moisture", 0.0))
	var after: float = minf(MAX_MOISTURE, before + WATER_AMOUNT)
	if is_equal_approx(before, after):
		return false
	bed["moisture"] = after
	return true

static func advance_bed(bed: Dictionary, delta_seconds: float) -> void:
	var delta_value: float = maxf(0.0, delta_seconds)
	var growth_value: float = clampf(float(bed.get("growth", 0.0)), 0.0, 100.0)
	var moisture_value: float = clampf(float(bed.get("moisture", 0.0)), 0.0, MAX_MOISTURE)
	if growth_value < 100.0:
		if moisture_value >= MIN_GROW_MOISTURE:
			growth_value = minf(100.0, growth_value + GROWTH_PER_SECOND * delta_value)
		moisture_value = maxf(0.0, moisture_value - MOISTURE_DRAIN_PER_SECOND * delta_value)
	bed["growth"] = growth_value
	bed["moisture"] = moisture_value

static func harvest(bed: Dictionary) -> bool:
	if float(bed.get("growth", 0.0)) < 100.0:
		return false
	bed["growth"] = 0.0
	bed["moisture"] = REPLANT_MOISTURE
	bed["harvests"] = int(bed.get("harvests", 0)) + 1
	return true

static func total_harvests(beds: Array[Dictionary]) -> int:
	var total: int = 0
	for bed in beds:
		total += int(bed.get("harvests", 0))
	return total

static func is_victory(beds: Array[Dictionary]) -> bool:
	return total_harvests(beds) >= TARGET_HARVESTS

static func is_timeout(seconds_left: float) -> bool:
	return seconds_left <= 0.0
