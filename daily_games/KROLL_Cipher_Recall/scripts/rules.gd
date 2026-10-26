extends RefCounted

const GRID_SIZE: int = 3
const CELL_COUNT: int = GRID_SIZE * GRID_SIZE
const START_LENGTH: int = 3
const TOTAL_ROUNDS: int = 5
const INITIAL_LIVES: int = 3

static func make_sequence(rng: RandomNumberGenerator, length: int) -> Array[int]:
	var result: Array[int] = []
	for _index in range(maxi(0, length)):
		result.append(rng.randi_range(0, CELL_COUNT - 1))
	return result

static func next_round_length(round_number: int) -> int:
	return START_LENGTH + maxi(0, round_number - 1)

static func is_correct_input(sequence: Array[int], index: int, cell: int) -> bool:
	if index < 0 or index >= sequence.size():
		return false
	if cell < 0 or cell >= CELL_COUNT:
		return false
	return sequence[index] == cell

static func is_round_complete(sequence: Array[int], index: int) -> bool:
	return not sequence.is_empty() and index >= sequence.size()

static func can_advance_round(round_number: int) -> bool:
	return round_number < TOTAL_ROUNDS
