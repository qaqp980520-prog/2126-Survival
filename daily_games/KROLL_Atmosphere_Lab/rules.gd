extends RefCounted
## Deterministic weather-station balancing puzzle. Each instrument adjustment costs one action.
const INSTRUMENTS: Array[String] = ["temperature", "humidity", "pressure", "wind"]
const STEP: int = 5
const LIMITS: Dictionary = {
	"temperature": Vector2i(-20, 45),
	"humidity": Vector2i(0, 100),
	"pressure": Vector2i(980, 1040),
	"wind": Vector2i(0, 80)
}
const LEVELS: Array[Dictionary] = [
	{
		"id": "coastal_front",
		"name": "COASTAL FRONT",
		"brief": "A humid sea front is approaching. Stabilize the pressure and reduce the crosswind.",
		"initial": {"temperature": 30, "humidity": 40, "pressure": 995, "wind": 50},
		"target": {"temperature": 20, "humidity": 60, "pressure": 1010, "wind": 30},
		"budget": 14,
		"storm_limit": 25
	},
	{
		"id": "desert_thermal",
		"name": "DESERT THERMAL",
		"brief": "A dry thermal column is forming. Cool the air and bring the pressure down.",
		"initial": {"temperature": 20, "humidity": 40, "pressure": 1015, "wind": 20},
		"target": {"temperature": 35, "humidity": 20, "pressure": 1000, "wind": 15},
		"budget": 14,
		"storm_limit": 25
	},
	{
		"id": "polar_calm",
		"name": "POLAR CALM",
		"brief": "A cold high-pressure pocket needs a gentle wind and controlled humidity.",
		"initial": {"temperature": 10, "humidity": 30, "pressure": 1005, "wind": 25},
		"target": {"temperature": -5, "humidity": 40, "pressure": 1025, "wind": 10},
		"budget": 14,
		"storm_limit": 25
	}
]

static func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)].duplicate(true)

static func new_game(level_index: int = 0) -> Dictionary:
	var safe_index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = get_level(safe_index)
	return {
		"level_index": safe_index,
		"level_id": str(level["id"]),
		"readings": level["initial"].duplicate(true),
		"actions_left": int(level["budget"]),
		"actions_used": 0,
		"status": "playing",
		"history": []
	}

static func adjust(state: Dictionary, instrument: String, direction: int) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "playing":
		return next
	if not INSTRUMENTS.has(instrument) or (direction != -1 and direction != 1):
		return next
	var readings: Dictionary = next.get("readings", {}).duplicate(true)
	if not readings.has(instrument):
		return next
	var bounds: Vector2i = LIMITS[instrument]
	var next_value: int = int(readings[instrument]) + direction * STEP
	if next_value < bounds.x or next_value > bounds.y:
		return next
	readings[instrument] = next_value
	next["readings"] = readings
	next["actions_left"] = int(next.get("actions_left", 0)) - 1
	next["actions_used"] = int(next.get("actions_used", 0)) + 1
	var history: Array = next.get("history", []).duplicate(true)
	history.append({"instrument": instrument, "direction": direction, "value": next_value})
	next["history"] = history
	var assessment: Dictionary = evaluate(next)
	if bool(assessment.get("complete", false)):
		next["status"] = "complete"
	elif int(next["actions_left"]) <= 0:
		next["status"] = "failed"
	return next

static func evaluate(state: Dictionary) -> Dictionary:
	var level: Dictionary = get_level(int(state.get("level_index", 0)))
	var readings: Dictionary = state.get("readings", {})
	var target: Dictionary = level.get("target", {})
	var exact_match: bool = true
	for instrument in INSTRUMENTS:
		if int(readings.get(instrument, 999999)) != int(target.get(instrument, -999999)):
			exact_match = false
	var storm: int = storm_load(readings)
	var stable: bool = storm <= int(level.get("storm_limit", 0))
	return {
		"target_match": exact_match,
		"storm_load": storm,
		"storm_limit": int(level.get("storm_limit", 0)),
		"stable": stable,
		"complete": exact_match and stable
	}

static func storm_load(readings: Dictionary) -> int:
	var humidity: float = float(readings.get("humidity", 0))
	var wind: float = float(readings.get("wind", 0))
	var pressure: float = float(readings.get("pressure", 1010))
	var temperature: float = float(readings.get("temperature", 20))
	var raw: float = humidity * wind / 60.0
	raw += maxf(0.0, 1005.0 - pressure) * 0.7
	raw += maxf(0.0, temperature - 25.0) * 0.5
	return clampi(roundi(maxf(0.0, raw - 25.0)), 0, 100)

static func reset(state: Dictionary) -> Dictionary:
	return new_game(int(state.get("level_index", 0)))

static func next_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return state.duplicate(true)
	return new_game((int(state.get("level_index", 0)) + 1) % LEVELS.size())

static func is_valid_level(level_index: int) -> bool:
	if level_index < 0 or level_index >= LEVELS.size():
		return false
	var level: Dictionary = LEVELS[level_index]
	for instrument in INSTRUMENTS:
		if not level.get("initial", {}).has(instrument) or not level.get("target", {}).has(instrument):
			return false
		var bounds: Vector2i = LIMITS[instrument]
		var initial_value: int = int(level["initial"][instrument])
		var target_value: int = int(level["target"][instrument])
		if initial_value < bounds.x or initial_value > bounds.y or target_value < bounds.x or target_value > bounds.y:
			return false
		if posmod(absi(target_value - initial_value), STEP) != 0:
			return false
	return int(level.get("budget", 0)) >= required_actions(level_index)

static func required_actions(level_index: int) -> int:
	var level: Dictionary = get_level(level_index)
	var total: int = 0
	for instrument in INSTRUMENTS:
		total += int(absi(int(level["target"][instrument]) - int(level["initial"][instrument])) / STEP)
	return total
