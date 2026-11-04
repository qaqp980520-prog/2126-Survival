extends RefCounted
class_name ThermalContainmentRules

const BOARD_SIZE: int = 4
const CYCLE_LIMIT: int = 4
const TARGET_MIN: int = 19
const TARGET_MAX: int = 29
const VENT_STRENGTH: int = 4
const SOURCE_HEAT: int = 2
const DIFFUSION_RATIO: float = 0.25

const LEVELS: Array[Dictionary] = [
	{
		"name": "Core Cooldown",
		"initial_grid": [
			[24, 25, 26, 24],
			[26, 34, 35, 27],
			[25, 33, 37, 28],
			[23, 26, 27, 25]
		],
		"sources": [[1, 1], [2, 2]],
		"par": [1, 1, 2, 2]
	},
	{
		"name": "Thermal Spine",
		"initial_grid": [
			[27, 37, 23, 26],
			[35, 27, 24, 26],
			[26, 35, 26, 28],
			[23, 23, 28, 28]
		],
		"sources": [[1, 0], [0, 1]],
		"par": [0, 1, 0, 1]
	},
	{
		"name": "Containment Core",
		"initial_grid": [
			[24, 26, 38, 26],
			[27, 27, 35, 22],
			[24, 28, 26, 25],
			[25, 26, 26, 23]
		],
		"sources": [[0, 2], [1, 2]],
		"par": [1, 0, 0, 1]
	}
]

static func mission_at(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

static func new_state() -> Dictionary:
	return start_level(0, 0, [false, false, false])

static func start_level(index: int, campaign_score: int = 0, awarded: Array = []) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	var ledger: Array = [false, false, false]
	for i in range(mini(ledger.size(), awarded.size())):
		ledger[i] = bool(awarded[i])
	var mission: Dictionary = mission_at(index)
	return {
		"level_index": index,
		"grid": mission["initial_grid"].duplicate(true),
		"cycles": 0,
		"selected_row": 0,
		"history": [],
		"completed": false,
		"failed": false,
		"campaign_score": campaign_score,
		"awarded": ledger
	}

static func advance_cycle(state: Dictionary, row: int) -> Dictionary:
	if state.is_empty():
		return {"accepted": false, "reason": "invalid_state", "state": state.duplicate(true)}
	if row < 0 or row >= BOARD_SIZE:
		return {"accepted": false, "reason": "invalid_row", "state": state.duplicate(true)}
	if bool(state.get("completed", false)) or bool(state.get("failed", false)):
		return {"accepted": false, "reason": "inactive", "state": state.duplicate(true)}
	var cycles: int = int(state.get("cycles", 0))
	if cycles >= CYCLE_LIMIT:
		return {"accepted": false, "reason": "cycle_limit", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	var history: Array = next.get("history", [])
	history.append({
		"grid": next["grid"].duplicate(true),
		"cycles": cycles
	})
	next["history"] = history
	next["selected_row"] = row
	next["grid"] = _simulate_cycle(next["grid"], mission_at(int(next["level_index"])), row)
	next["cycles"] = cycles + 1
	var reason: String = "cycle_advanced"
	if int(next["cycles"]) >= CYCLE_LIMIT:
		if is_stable(next["grid"]):
			next["completed"] = true
			reason = "contained"
			var ledger: Array = next["awarded"].duplicate()
			var level_index: int = int(next["level_index"])
			if not bool(ledger[level_index]):
				ledger[level_index] = true
				next["campaign_score"] = int(next["campaign_score"]) + 100
			next["awarded"] = ledger
		else:
			next["failed"] = true
			reason = "thermal_limit_exceeded"
	return {"accepted": true, "reason": reason, "state": next}

static func undo_cycle(state: Dictionary) -> Dictionary:
	if state.is_empty() or bool(state.get("completed", false)):
		return {"accepted": false, "reason": "inactive", "state": state.duplicate(true)}
	var history: Array = state.get("history", []).duplicate(true)
	if history.is_empty():
		return {"accepted": false, "reason": "nothing_to_undo", "state": state.duplicate(true)}
	var previous: Dictionary = history.pop_back()
	var next: Dictionary = state.duplicate(true)
	next["history"] = history
	next["grid"] = previous["grid"].duplicate(true)
	next["cycles"] = int(previous["cycles"])
	next["failed"] = false
	return {"accepted": true, "reason": "undone", "state": next}

static func restart_level(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return new_state()
	return start_level(
		int(state.get("level_index", 0)),
		int(state.get("campaign_score", 0)),
		state.get("awarded", [])
	)

static func advance(state: Dictionary) -> Dictionary:
	if state.is_empty() or not bool(state.get("completed", false)):
		return {"accepted": false, "reason": "not_contained", "state": state.duplicate(true)}
	var current: int = int(state.get("level_index", 0))
	if current + 1 >= LEVELS.size():
		return {"accepted": false, "reason": "campaign_complete", "state": state.duplicate(true)}
	return {
		"accepted": true,
		"reason": "next_chamber",
		"state": start_level(current + 1, int(state.get("campaign_score", 0)), state.get("awarded", []))
	}

static func restart_campaign() -> Dictionary:
	return new_state()

static func is_stable(grid: Array) -> bool:
	if grid.size() != BOARD_SIZE:
		return false
	for row in grid:
		if not (row is Array) or row.size() != BOARD_SIZE:
			return false
		for raw_temperature in row:
			if not (raw_temperature is int or raw_temperature is float):
				return false
			var temperature: float = float(raw_temperature)
			if not is_finite(temperature) or temperature < TARGET_MIN or temperature > TARGET_MAX:
				return false
	return true

static func _simulate_cycle(grid: Array, mission: Dictionary, vent_row: int) -> Array:
	var heated: Array = grid.duplicate(true)
	for column in range(BOARD_SIZE):
		heated[vent_row][column] = maxi(10, int(heated[vent_row][column]) - VENT_STRENGTH)
	for source in mission["sources"]:
		var source_row: int = int(source[0])
		var source_column: int = int(source[1])
		heated[source_row][source_column] = int(heated[source_row][source_column]) + SOURCE_HEAT
	var diffused: Array = heated.duplicate(true)
	var offsets: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for row in range(BOARD_SIZE):
		for column in range(BOARD_SIZE):
			var neighbor_total: int = 0
			var neighbor_count: int = 0
			for offset in offsets:
				var neighbor_row: int = row + offset.y
				var neighbor_column: int = column + offset.x
				if neighbor_row < 0 or neighbor_row >= BOARD_SIZE or neighbor_column < 0 or neighbor_column >= BOARD_SIZE:
					continue
				neighbor_total += int(heated[neighbor_row][neighbor_column])
				neighbor_count += 1
			var current_temperature: float = float(heated[row][column])
			var neighbor_average: float = float(neighbor_total) / float(neighbor_count)
			diffused[row][column] = roundi(current_temperature + DIFFUSION_RATIO * (neighbor_average - current_temperature))
	return diffused
