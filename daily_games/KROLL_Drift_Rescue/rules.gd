extends RefCounted
class_name KROLLDriftRescueRules

const BOARD_SIZE: int = 9
const MAX_SPEED: int = 2
const MISSIONS: Array[Dictionary] = [
	{
		"name":"Debris-Free Transfer",
		"start":Vector2i(1, 4),
		"goal":Vector2i(7, 4),
		"obstacles":[],
		"fuel":6,
		"max_turns":8,
		"par":5
	},
	{
		"name":"Broken Bulkhead",
		"start":Vector2i(1, 6),
		"goal":Vector2i(7, 2),
		"obstacles":[Vector2i(4, 5),Vector2i(4, 6),Vector2i(4, 7),Vector2i(4, 8)],
		"fuel":7,
		"max_turns":10,
		"par":7
	},
	{
		"name":"Cryo-Ring Extraction",
		"start":Vector2i(1, 1),
		"goal":Vector2i(7, 7),
		"obstacles":[
			Vector2i(3, 2),Vector2i(4, 2),Vector2i(5, 2),
			Vector2i(5, 3),Vector2i(5, 4),
			Vector2i(3, 5),Vector2i(4, 5),Vector2i(5, 5)
		],
		"fuel":8,
		"max_turns":11,
		"par":8
	}
]
const THRUSTS: Dictionary = {
	"thrust_up":Vector2i(0, -1),
	"thrust_down":Vector2i(0, 1),
	"thrust_left":Vector2i(-1, 0),
	"thrust_right":Vector2i(1, 0)
}

static func level_count() -> int:
	return MISSIONS.size()

static func mission_at(index: int) -> Dictionary:
	return MISSIONS[clampi(index, 0, MISSIONS.size() - 1)].duplicate(true)

static func new_state(level_index: int = 0) -> Dictionary:
	var mission: Dictionary = mission_at(level_index)
	return {
		"level_index":clampi(level_index, 0, level_count() - 1),
		"position":mission["start"],
		"velocity":Vector2i.ZERO,
		"fuel":int(mission["fuel"]),
		"starting_fuel":int(mission["fuel"]),
		"turns":0,
		"max_turns":int(mission["max_turns"]),
		"par":int(mission["par"]),
		"status":"active",
		"campaign_score":0,
		"completed_levels":{},
		"history":[]
	}

static func perform_action(state: Dictionary, action: String) -> Dictionary:
	if action == "undo":
		return undo(state)
	if action == "restart":
		return {"accepted":true,"reason":"restarted","state":restart_level(state)}
	if action == "next":
		return advance(state)
	if str(state.get("status", "active")) != "active":
		return _rejected(state, "inactive")
	if action != "coast" and not THRUSTS.has(action):
		return _rejected(state, "unknown_action")

	var fuel_cost: int = 0 if action == "coast" else 1
	var fuel: int = int(state.get("fuel", 0))
	if fuel < fuel_cost:
		return _rejected(state, "fuel_empty")
	if int(state.get("turns", 0)) >= int(state.get("max_turns", 0)):
		return _rejected(state, "turn_limit")

	var mission: Dictionary = mission_at(int(state.get("level_index", 0)))
	var position: Vector2i = state.get("position", mission["start"])
	var velocity: Vector2i = state.get("velocity", Vector2i.ZERO)
	var acceleration: Vector2i = THRUSTS.get(action, Vector2i.ZERO)
	var next_velocity := Vector2i(
		clampi(velocity.x + acceleration.x, -MAX_SPEED, MAX_SPEED),
		clampi(velocity.y + acceleration.y, -MAX_SPEED, MAX_SPEED)
	)
	var next_position: Vector2i = position + next_velocity
	var next_history: Array = state.get("history", []).duplicate(true)
	next_history.append(_capture_undo_state(state))
	var next_turns: int = int(state.get("turns", 0)) + 1
	var next_fuel: int = fuel - fuel_cost
	var obstacles: Array = mission.get("obstacles", [])

	for cell in _trace_cells(position, next_velocity):
		if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_SIZE or cell.y >= BOARD_SIZE:
			return _failed_move(state, next_velocity, next_fuel, next_turns, next_history, "out_of_bounds")
		if obstacles.has(cell):
			return _failed_move(state, next_velocity, next_fuel, next_turns, next_history, "collision")

	var updated: Dictionary = state.duplicate(true)
	updated["position"] = next_position
	updated["velocity"] = next_velocity
	updated["fuel"] = next_fuel
	updated["turns"] = next_turns
	updated["history"] = next_history

	if next_position == mission["goal"] and next_velocity == Vector2i.ZERO:
		updated["status"] = "completed"
		var completed: Dictionary = updated.get("completed_levels", {}).duplicate(true)
		var level_key: String = str(int(updated.get("level_index", 0)))
		if not completed.has(level_key):
			var award: int = 100 if next_turns <= int(updated.get("par", 0)) else 75
			updated["campaign_score"] = int(updated.get("campaign_score", 0)) + award
			completed[level_key] = true
		updated["completed_levels"] = completed
		return {"accepted":true,"reason":"docked","state":updated}

	if next_turns >= int(updated.get("max_turns", 0)):
		updated["status"] = "failed"
		return {"accepted":true,"reason":"turn_limit","state":updated}
	return {"accepted":true,"reason":"thrust","state":updated}

static func undo(state: Dictionary) -> Dictionary:
	var history: Array = state.get("history", []).duplicate(true)
	if history.is_empty():
		return _rejected(state, "nothing_to_undo")
	var snapshot: Dictionary = history.pop_back()
	var restored: Dictionary = state.duplicate(true)
	for key in snapshot.keys():
		restored[key] = snapshot[key]
	restored["history"] = history
	return {"accepted":true,"reason":"undone","state":restored}

static func restart_level(state: Dictionary) -> Dictionary:
	var fresh: Dictionary = new_state(int(state.get("level_index", 0)))
	fresh["campaign_score"] = int(state.get("campaign_score", 0))
	fresh["completed_levels"] = state.get("completed_levels", {}).duplicate(true)
	return fresh

static func restart_campaign() -> Dictionary:
	return new_state()

static func advance(state: Dictionary) -> Dictionary:
	if str(state.get("status", "active")) != "completed":
		return _rejected(state, "not_docked")
	var current_index: int = int(state.get("level_index", 0))
	if current_index >= level_count() - 1:
		var finished: Dictionary = state.duplicate(true)
		finished["status"] = "campaign_complete"
		return {"accepted":true,"reason":"campaign_complete","state":finished}
	var next_state: Dictionary = new_state(current_index + 1)
	next_state["campaign_score"] = int(state.get("campaign_score", 0))
	next_state["completed_levels"] = state.get("completed_levels", {}).duplicate(true)
	return {"accepted":true,"reason":"next_mission","state":next_state}

static func _failed_move(
	state: Dictionary,
	next_velocity: Vector2i,
	next_fuel: int,
	next_turns: int,
	next_history: Array,
	reason: String
) -> Dictionary:
	var failed: Dictionary = state.duplicate(true)
	failed["velocity"] = next_velocity
	failed["fuel"] = next_fuel
	failed["turns"] = next_turns
	failed["history"] = next_history
	failed["status"] = "failed"
	return {"accepted":true,"reason":reason,"state":failed}

static func _capture_undo_state(state: Dictionary) -> Dictionary:
	return {
		"position":state.get("position", Vector2i.ZERO),
		"velocity":state.get("velocity", Vector2i.ZERO),
		"fuel":int(state.get("fuel", 0)),
		"turns":int(state.get("turns", 0)),
		"status":str(state.get("status", "active")),
		"campaign_score":int(state.get("campaign_score", 0)),
		"completed_levels":state.get("completed_levels", {}).duplicate(true)
	}

static func _trace_cells(start: Vector2i, delta: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		return result
	for step in range(1, steps + 1):
		var point := Vector2i(
			roundi(float(start.x) + float(delta.x) * float(step) / float(steps)),
			roundi(float(start.y) + float(delta.y) * float(step) / float(steps))
		)
		if result.is_empty() or result.back() != point:
			result.append(point)
	return result

static func _rejected(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted":false,"reason":reason,"state":state}
