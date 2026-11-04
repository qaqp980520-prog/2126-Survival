extends RefCounted
class_name TidalLockRules

const MAX_WATER_LEVEL: int = 5
const RELAY_REWARD: int = 100
const LEVELS: Array[Dictionary] = [
	{
		"name": "Service Lock",
		"lower_level": 1,
		"initial_chamber_level": 1,
		"upper_level": 3,
		"par_actions": 7,
		"max_actions": 10,
		"brief": "The chamber already matches the lower basin. Board first, then raise the water."
	},
	{
		"name": "Pressure Exchange",
		"lower_level": 4,
		"initial_chamber_level": 2,
		"upper_level": 1,
		"par_actions": 10,
		"max_actions": 13,
		"brief": "Raise the chamber to the lower basin before boarding, then drain toward the upper basin."
	},
	{
		"name": "High Reservoir",
		"lower_level": 0,
		"initial_chamber_level": 3,
		"upper_level": 5,
		"par_actions": 13,
		"max_actions": 16,
		"brief": "Drain fully for boarding, then fill the chamber to the high reservoir."
	}
]

static func level_count() -> int:
	return LEVELS.size()

static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)].duplicate(true)

static func new_state(index: int) -> Dictionary:
	var safe_index: int = clampi(index, 0, LEVELS.size() - 1)
	var level: Dictionary = get_level(safe_index)
	return {
		"level_index": safe_index,
		"chamber_level": int(level["initial_chamber_level"]),
		"ship_position": "lower",
		"lower_gate_open": false,
		"upper_gate_open": false,
		"actions": 0,
		"status": "playing",
		"message": "Close both gates before changing the water level."
	}

static func perform_action(state: Dictionary, action: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "invalid")) != "playing":
		return _rejected(state, "The lock is not active. Reset or advance to continue.")

	var level: Dictionary = get_level(int(next.get("level_index", 0)))
	var chamber_level: int = int(next.get("chamber_level", -1))
	var lower_level: int = int(level["lower_level"])
	var upper_level: int = int(level["upper_level"])
	var lower_open: bool = bool(next.get("lower_gate_open", false))
	var upper_open: bool = bool(next.get("upper_gate_open", false))
	var ship_position: String = str(next.get("ship_position", "invalid"))
	var message: String = ""
	var accepted: bool = false

	match action:
		"pump_up":
			if lower_open or upper_open:
				message = "Close both gates before pumping."
			elif chamber_level >= MAX_WATER_LEVEL:
				message = "The chamber is already at maximum level."
			else:
				next["chamber_level"] = chamber_level + 1
				message = "Pumped one level into the chamber."
				accepted = true
		"pump_down":
			if lower_open or upper_open:
				message = "Close both gates before pumping."
			elif chamber_level <= 0:
				message = "The chamber is already at minimum level."
			else:
				next["chamber_level"] = chamber_level - 1
				message = "Drained one level from the chamber."
				accepted = true
		"toggle_lower_gate":
			if lower_open:
				next["lower_gate_open"] = false
				message = "Lower gate closed."
				accepted = true
			elif upper_open:
				message = "The upper gate must be closed first."
			elif chamber_level != lower_level:
				message = "Water levels must match the lower basin before opening this gate."
			elif ship_position != "lower" and ship_position != "chamber":
				message = "The ship is not on the lower side of this gate."
			else:
				next["lower_gate_open"] = true
				message = "Lower gate opened. The levels are equal."
				accepted = true
		"toggle_upper_gate":
			if upper_open:
				next["upper_gate_open"] = false
				message = "Upper gate closed."
				accepted = true
			elif lower_open:
				message = "The lower gate must be closed first."
			elif chamber_level != upper_level:
				message = "Water levels must match the upper basin before opening this gate."
			elif ship_position != "chamber" and ship_position != "upper":
				message = "The ship must reach the chamber before using the upper gate."
			else:
				next["upper_gate_open"] = true
				message = "Upper gate opened. The levels are equal."
				accepted = true
		"move_ship":
			if ship_position == "lower" and lower_open and chamber_level == lower_level:
				next["ship_position"] = "chamber"
				message = "Ship entered the lock chamber."
				accepted = true
			elif ship_position == "chamber" and lower_open and chamber_level == lower_level:
				next["ship_position"] = "lower"
				message = "Ship returned to the lower basin."
				accepted = true
			elif ship_position == "chamber" and upper_open and chamber_level == upper_level:
				next["ship_position"] = "upper"
				message = "Ship reached the upper basin."
				accepted = true
			elif ship_position == "upper" and upper_open and chamber_level == upper_level:
				next["ship_position"] = "chamber"
				message = "Ship returned to the lock chamber."
				accepted = true
			else:
				message = "Open the matching gate before moving the ship."
		_:
			message = "Unknown lock operation."

	if not accepted:
		return _rejected(state, message)

	next["actions"] = int(next.get("actions", 0)) + 1
	if int(next["actions"]) > int(level["max_actions"]):
		next["status"] = "failed"
		message = "Action limit exceeded. Reset this lock and try a cleaner sequence."
	elif str(next["ship_position"]) == "upper":
		next["status"] = "won"
		message = "Lock cleared. The vessel reached the upper basin."
	next["message"] = message
	return {"accepted": true, "state": next, "message": message}

static func reward_for_clear(state: Dictionary) -> int:
	var level: Dictionary = get_level(int(state.get("level_index", 0)))
	return RELAY_REWARD if int(state.get("actions", 0)) <= int(level["par_actions"]) else 75

static func _rejected(state: Dictionary, message: String) -> Dictionary:
	var unchanged: Dictionary = state.duplicate(true)
	unchanged["message"] = message
	return {"accepted": false, "state": unchanged, "message": message}
