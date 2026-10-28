extends RefCounted
class_name KrollMemoryMatrixRules

const TILE_COUNT: int = 9
const FIRST_SEQUENCE_LENGTH: int = 3
const MAX_ROUNDS: int = 6
const MAX_MISTAKES: int = 3

static func create_game(seed_value: int = 20261028) -> Dictionary:
	return {
		"seed": seed_value,
		"round": 1,
		"mistakes": 0,
		"status": "showing",
		"sequence": _make_sequence(seed_value, 1),
		"input_index": 0,
		"message": "Memorize the signal sequence."
	}

static func begin_input(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "showing":
		return false
	state["status"] = "input"
	state["message"] = "Repeat the sequence."
	return true

## Returns false without mutation for invalid input or a locked game.
static func press_tile(state: Dictionary, tile_index: int) -> bool:
	if str(state.get("status", "")) != "input":
		return false
	if tile_index < 0 or tile_index >= TILE_COUNT:
		return false
	var sequence: Variant = state.get("sequence", null)
	if not (sequence is Array) or sequence.is_empty():
		return false
	var input_index := int(state.get("input_index", -1))
	if input_index < 0 or input_index >= sequence.size():
		return false

	if tile_index != int(sequence[input_index]):
		var mistakes := int(state.get("mistakes", 0)) + 1
		state["mistakes"] = mistakes
		state["input_index"] = 0
		if mistakes >= MAX_MISTAKES:
			state["status"] = "lost"
			state["message"] = "Signal integrity lost. Restart to try again."
		else:
			state["status"] = "showing"
			state["message"] = "Mismatch. Memorize the same sequence again."
		return true

	input_index += 1
	state["input_index"] = input_index
	if input_index < sequence.size():
		state["message"] = "Correct signal. Keep going."
		return true

	var current_round := int(state.get("round", 1))
	if current_round >= MAX_ROUNDS:
		state["status"] = "won"
		state["message"] = "All six signal rounds restored."
		return true

	current_round += 1
	state["round"] = current_round
	state["sequence"] = _make_sequence(int(state.get("seed", 0)), current_round)
	state["input_index"] = 0
	state["status"] = "showing"
	state["message"] = "Round %d: memorize %d signals." % [current_round, current_round + 2]
	return true

static func _make_sequence(seed_value: int, round_number: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + round_number * 7919
	var sequence: Array[int] = []
	var length := FIRST_SEQUENCE_LENGTH + round_number - 1
	for _index in range(length):
		sequence.append(rng.randi_range(0, TILE_COUNT - 1))
	return sequence
