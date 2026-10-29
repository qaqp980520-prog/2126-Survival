extends RefCounted
class_name RailYardRules

const SEEDS: Array[int] = [1, 2, 3]
const LAYOUTS: Array = [
	["B", "A", "C", "D", "E"],
	["C", "A", "B", "D", "E"],
	["D", "B", "A", "C", "E"]
]
const TARGET_ORDER: Array[String] = ["A", "B", "C", "D", "E"]
const SIDING_CAPACITY: int = 3
const MAX_MOVES: int = 12
const ACTION_DIRECT: String = "direct"
const ACTION_PUSH: String = "push"
const ACTION_POP: String = "pop"

static func new_game(seed_value: int = 1) -> Dictionary:
	var layout_index: int = posmod(seed_value - 1, SEEDS.size())
	var incoming: Array[String] = []
	for car_value in LAYOUTS[layout_index]:
		incoming.append(str(car_value))
	return {
		"seed": SEEDS[layout_index],
		"incoming": incoming,
		"siding": [],
		"output": [],
		"moves": 0,
		"max_moves": MAX_MOVES,
		"status": "playing",
		"message": "Sort A–E. Use the siding stack to move cars out of order."
	}

static func apply_action(state: Dictionary, action_name: String) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	var incoming_value: Variant = state.get("incoming", null)
	var siding_value: Variant = state.get("siding", null)
	var output_value: Variant = state.get("output", null)
	if not (incoming_value is Array) or not (siding_value is Array) or not (output_value is Array):
		return _result(false, "invalid_state", state)
	var incoming: Array = incoming_value
	var siding: Array = siding_value
	var output: Array = output_value
	if incoming.size() + siding.size() + output.size() != TARGET_ORDER.size():
		return _result(false, "invalid_state", state)
	var next: Dictionary = state.duplicate(true)
	incoming = next["incoming"]
	siding = next["siding"]
	output = next["output"]
	var expected: String = str(TARGET_ORDER[output.size()]) if output.size() < TARGET_ORDER.size() else ""
	match action_name:
		ACTION_DIRECT:
			if incoming.is_empty():
				return _result(false, "input_empty", state)
			if str(incoming[0]) != expected:
				return _result(false, "wrong_car", state)
			output.append(incoming.pop_front())
		ACTION_PUSH:
			if incoming.is_empty():
				return _result(false, "input_empty", state)
			if siding.size() >= SIDING_CAPACITY:
				return _result(false, "siding_full", state)
			siding.append(incoming.pop_front())
		ACTION_POP:
			if siding.is_empty():
				return _result(false, "siding_empty", state)
			if str(siding.back()) != expected:
				return _result(false, "wrong_car", state)
			output.append(siding.pop_back())
		_:
			return _result(false, "unknown_action", state)
	next["incoming"] = incoming
	next["siding"] = siding
	next["output"] = output
	next["moves"] = int(next.get("moves", 0)) + 1
	if output.size() == TARGET_ORDER.size() and incoming.is_empty() and siding.is_empty():
		next["status"] = "won"
		next["message"] = "Yard cleared. All five cars are in order."
	elif int(next["moves"]) >= MAX_MOVES:
		next["status"] = "failed"
		next["message"] = "Move limit reached. Restart and try a different shunting sequence."
	else:
		next["message"] = "%s move completed." % action_name.capitalize()
	return _result(true, "action_applied", next)

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}
