extends RefCounted
class_name FrequencyTunerRules

const SEEDS: Array[int] = [13, 27, 41]
const MOVE_LIMIT: int = 14
const INITIALS: Array[Array] = [
	[1, 8, 5],
	[8, 3, 9],
	[0, 7, 2]
]
const TARGETS: Array[Array] = [
	[4, 2, 7],
	[2, 6, 3],
	[7, 1, 8]
]

static func new_game(seed_value: int = 13) -> Dictionary:
	var index: int = _layout_index(seed_value)
	var target: Array = TARGETS[index].duplicate(true)
	return {
		"seed": SEEDS[index],
		"frequencies": INITIALS[index].duplicate(true),
		"target_frequencies": target,
		"target_outputs": output_values(target),
		"moves": 0,
		"move_limit": MOVE_LIMIT,
		"status": "playing",
		"message": "Tune all three output signals before the move budget runs out."
	}

static func output_values(frequencies: Array) -> Array[int]:
	if frequencies.size() != 3:
		return []
	var x: int = int(frequencies[0])
	var y: int = int(frequencies[1])
	var z: int = int(frequencies[2])
	var result: Array[int] = [
		posmod(x + 2 * y + z, 10),
		posmod(2 * x + y + 3 * z, 10),
		posmod(3 * x + 2 * y + 2 * z, 10)
	]
	return result

static func tune(state: Dictionary, dial: int, delta: int) -> Dictionary:
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)
	if dial < 0 or dial > 2:
		return _result(false, "invalid_dial", state)
	if abs(delta) != 1:
		return _result(false, "invalid_delta", state)
	var frequencies_value: Variant = state.get("frequencies", null)
	var target_outputs_value: Variant = state.get("target_outputs", null)
	if not (frequencies_value is Array) or frequencies_value.size() != 3:
		return _result(false, "invalid_state", state)
	if not (target_outputs_value is Array) or target_outputs_value.size() != 3:
		return _result(false, "invalid_state", state)
	for value in frequencies_value:
		if not (value is int) or int(value) < 0 or int(value) > 9:
			return _result(false, "invalid_state", state)
	var next: Dictionary = state.duplicate(true)
	var frequencies: Array = next["frequencies"]
	frequencies[dial] = posmod(int(frequencies[dial]) + delta, 10)
	next["moves"] = int(next.get("moves", 0)) + 1
	var outputs: Array[int] = output_values(frequencies)
	if outputs == target_outputs_value:
		next["status"] = "won"
		next["message"] = "SIGNAL LOCKED: all three output channels match."
	elif int(next["moves"]) >= int(next.get("move_limit", MOVE_LIMIT)):
		next["status"] = "failed"
		next["message"] = "TUNING WINDOW CLOSED: reset and try another dial sequence."
	else:
		next["message"] = "Outputs %02d / %02d / %02d — keep tuning." % [outputs[0], outputs[1], outputs[2]]
	return _result(true, "tuned", next)

static func next_seed(seed_value: int) -> int:
	var index: int = SEEDS.find(seed_value)
	return SEEDS[posmod(index + 1, SEEDS.size())] if index >= 0 else SEEDS[0]

static func _layout_index(seed_value: int) -> int:
	var found: int = SEEDS.find(seed_value)
	return found if found >= 0 else posmod(seed_value, INITIALS.size())

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}
