extends RefCounted
class_name ThermalSortRules

const SEEDS: Array[int] = [101, 202, 303]
const MAX_MISTAKES: int = 2
const BIN_NAMES: Array[String] = ["cold", "stable", "hot"]
const TEMPERATURES: Array[Array] = [
	[-18, 4, 23, -7, 11, -24, 0, 16, -12, 8, 29, -3],
	[15, -16, 2, 26, -8, 10, -21, 5, 18, -2, 0, 31],
	[6, -11, 20, -25, 13, -4, 27, 1, -18, 9, 22, -6]
]

static func new_game(seed_value: int = 101) -> Dictionary:
	var index: int = _layout_index(seed_value)
	return {
		"seed": SEEDS[index],
		"temperatures": TEMPERATURES[index].duplicate(true),
		"index": 0,
		"correct": 0,
		"mistakes": 0,
		"status": "playing",
		"message": "Sort each canister: <= -10 C cold, -9..9 C stable, >= 10 C hot."
	}

static func expected_bin(temperature: int) -> String:
	if temperature <= -10:
		return "cold"
	if temperature >= 10:
		return "hot"
	return "stable"

static func route(state: Dictionary, bin_name: String) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	if not BIN_NAMES.has(bin_name):
		return _result(false, "invalid_bin", state)
	var temperatures: Array = state.get("temperatures", [])
	var index: int = int(state.get("index", -1))
	if index < 0 or index >= temperatures.size() or not (temperatures[index] is int):
		return _result(false, "invalid_state", state)
	var next: Dictionary = state.duplicate(true)
	var temperature: int = int(temperatures[index])
	if bin_name == expected_bin(temperature):
		next["correct"] = int(next.get("correct", 0)) + 1
		next["message"] = "Correct routing: %d C -> %s." % [temperature, bin_name.to_upper()]
	else:
		next["mistakes"] = int(next.get("mistakes", 0)) + 1
		next["message"] = "MISROUTED: %d C belongs in %s." % [temperature, expected_bin(temperature).to_upper()]
	next["index"] = index + 1
	_resolve_terminal(next)
	return _result(true, "routed", next)

static func _resolve_terminal(state: Dictionary) -> void:
	if int(state.get("mistakes", 0)) > MAX_MISTAKES:
		state["status"] = "failed"
		state["message"] = "SHIFT FAILED: too many routing errors. Restart and try again."
	elif int(state.get("index", 0)) >= (state.get("temperatures", []) as Array).size():
		state["status"] = "won"
		state["message"] = "SHIFT COMPLETE: all canisters processed within the error budget."

static func _layout_index(seed_value: int) -> int:
	var found: int = SEEDS.find(seed_value)
	return found if found >= 0 else posmod(seed_value, TEMPERATURES.size())

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}
