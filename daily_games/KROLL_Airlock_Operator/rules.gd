extends RefCounted

const REQUIRED_PODS: int = 3
const MAX_ACTIONS: int = 28
const MAX_PRESSURE: int = 100
const PRESSURE_STEP: int = 50
const MAX_PRESSURE_DIFFERENCE: int = 10
const MIN_DOOR_OXYGEN: int = 30
const TRANSFER_OXYGEN_COST: int = 5

static func new_game() -> Dictionary:
	return {
		"exterior_pressure": 0, "airlock_pressure": 0, "habitat_pressure": 100,
		"oxygen": 60, "pods_exterior": REQUIRED_PODS, "pods_airlock": 0,
		"pods_delivered": 0, "outer_open": false, "inner_open": false,
		"actions": 0, "result": "playing"
	}

## Rejected actions are side-effect free; success returns a new state snapshot.
static func apply_action(state: Dictionary, action: String) -> Dictionary:
	if str(state.get("result", "")) != "playing":
		return {"ok": false, "reason": "finished", "state": state.duplicate(true)}
	for key in ["exterior_pressure", "airlock_pressure", "habitat_pressure", "oxygen", "pods_exterior", "pods_airlock", "pods_delivered", "outer_open", "inner_open", "actions"]:
		if not state.has(key):
			return {"ok": false, "reason": "invalid_state", "state": state.duplicate(true)}
	var next: Dictionary = state.duplicate(true)
	var reason := ""
	match action:
		"pressurize":
			if bool(next["outer_open"]) or bool(next["inner_open"]):
				reason = "door_open"
			elif int(next["airlock_pressure"]) >= MAX_PRESSURE:
				reason = "pressure_limit"
			else:
				next["airlock_pressure"] = mini(MAX_PRESSURE, int(next["airlock_pressure"]) + PRESSURE_STEP)
		"vent":
			if bool(next["outer_open"]) or bool(next["inner_open"]):
				reason = "door_open"
			elif int(next["airlock_pressure"]) <= 0:
				reason = "pressure_limit"
			else:
				next["airlock_pressure"] = maxi(0, int(next["airlock_pressure"]) - PRESSURE_STEP)
		"recycle_oxygen":
			if bool(next["outer_open"]) or bool(next["inner_open"]):
				reason = "door_open"
			elif int(next["oxygen"]) >= 100:
				reason = "oxygen_full"
			else:
				next["oxygen"] = mini(100, int(next["oxygen"]) + 20)
		"open_outer":
			if bool(next["inner_open"]):
				reason = "interlock"
			elif bool(next["outer_open"]):
				reason = "already_open"
			elif abs(int(next["airlock_pressure"]) - int(next["exterior_pressure"])) > MAX_PRESSURE_DIFFERENCE:
				reason = "pressure_mismatch"
			elif int(next["oxygen"]) < MIN_DOOR_OXYGEN:
				reason = "low_oxygen"
			else:
				next["outer_open"] = true
		"close_outer":
			if not bool(next["outer_open"]):
				reason = "already_closed"
			else:
				next["outer_open"] = false
		"load_pod":
			if not bool(next["outer_open"]):
				reason = "outer_closed"
			elif int(next["pods_exterior"]) <= 0:
				reason = "no_pods"
			elif int(next["oxygen"]) < TRANSFER_OXYGEN_COST:
				reason = "low_oxygen"
			else:
				next["pods_exterior"] = int(next["pods_exterior"]) - 1
				next["pods_airlock"] = int(next["pods_airlock"]) + 1
				next["oxygen"] = int(next["oxygen"]) - TRANSFER_OXYGEN_COST
		"open_inner":
			if bool(next["outer_open"]):
				reason = "interlock"
			elif bool(next["inner_open"]):
				reason = "already_open"
			elif int(next["pods_airlock"]) <= 0:
				reason = "airlock_empty"
			elif abs(int(next["airlock_pressure"]) - int(next["habitat_pressure"])) > MAX_PRESSURE_DIFFERENCE:
				reason = "pressure_mismatch"
			elif int(next["oxygen"]) < MIN_DOOR_OXYGEN:
				reason = "low_oxygen"
			else:
				next["inner_open"] = true
		"unload_pod":
			if not bool(next["inner_open"]):
				reason = "inner_closed"
			elif int(next["pods_airlock"]) <= 0:
				reason = "airlock_empty"
			elif int(next["oxygen"]) < TRANSFER_OXYGEN_COST:
				reason = "low_oxygen"
			else:
				next["pods_airlock"] = int(next["pods_airlock"]) - 1
				next["pods_delivered"] = int(next["pods_delivered"]) + 1
				next["oxygen"] = int(next["oxygen"]) - TRANSFER_OXYGEN_COST
		_:
			reason = "unknown_action"
	if not reason.is_empty():
		return {"ok": false, "reason": reason, "state": state.duplicate(true)}
	next["actions"] = int(next["actions"]) + 1
	if int(next["pods_delivered"]) >= REQUIRED_PODS and not bool(next["outer_open"]) and not bool(next["inner_open"]):
		next["result"] = "won"
	elif int(next["oxygen"]) <= 0 or int(next["actions"]) >= MAX_ACTIONS:
		next["result"] = "lost"
	return {"ok": true, "reason": "applied", "state": next, "result": str(next["result"])}
