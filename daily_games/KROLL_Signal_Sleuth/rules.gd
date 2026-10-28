extends RefCounted
class_name KrollSignalSleuthRules

const SIZE: int = 5
const MAX_MOVES: int = 60
const PUZZLES: Array[String] = [
	"0010001110111111010110101",
	"0010001110111110111000100",
	"1111110001101011000111111"
]

static func create_game(seed_value: int = 20261028) -> Dictionary:
	var puzzle_index: int = posmod(seed_value, PUZZLES.size())
	var solution: Array = _make_solution(PUZZLES[puzzle_index])
	var marks: Array = []
	for _index in range(SIZE * SIZE):
		marks.append(0)
	return {
		"seed": seed_value,
		"puzzle_index": puzzle_index,
		"solution": solution,
		"row_clues": _build_clues(solution, true),
		"col_clues": _build_clues(solution, false),
		"marks": marks,
		"moves": 0,
		"status": "playing",
		"message": "Use the row and column clues to reveal the picture."
	}

## Cell marks: 0 unknown, 1 filled, 2 marked empty. Invalid input never mutates state.
static func toggle_cell(state: Dictionary, row: int, col: int) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	if row < 0 or row >= SIZE or col < 0 or col >= SIZE:
		return false
	var marks_value: Variant = state.get("marks", null)
	if not (marks_value is Array) or marks_value.size() != SIZE * SIZE:
		return false
	var marks: Array = marks_value
	var index: int = row * SIZE + col
	var current_mark: int = int(marks[index])
	marks[index] = (current_mark + 1) % 3
	state["moves"] = int(state.get("moves", 0)) + 1
	if _is_solved(state):
		state["status"] = "won"
		state["message"] = "Pattern verified. Grid stabilized."
	elif int(state["moves"]) >= MAX_MOVES:
		state["status"] = "lost"
		state["message"] = "Move budget exhausted. Restart or try another grid."
	return true

static func _make_solution(puzzle_text: String) -> Array:
	var solution: Array = []
	for row_index in range(SIZE):
		var row: Array = []
		for col_index in range(SIZE):
			row.append(puzzle_text.substr(row_index * SIZE + col_index, 1) == "1")
		solution.append(row)
	return solution

static func _build_clues(solution: Array, read_rows: bool) -> Array:
	var all_clues: Array = []
	for line_index in range(SIZE):
		var clues: Array = []
		var run_length: int = 0
		for offset in range(SIZE):
			var filled: bool = bool(solution[line_index][offset]) if read_rows else bool(solution[offset][line_index])
			if filled:
				run_length += 1
			elif run_length > 0:
				clues.append(run_length)
				run_length = 0
		if run_length > 0:
			clues.append(run_length)
		if clues.is_empty():
			clues.append(0)
		all_clues.append(clues)
	return all_clues

static func _is_solved(state: Dictionary) -> bool:
	var solution_value: Variant = state.get("solution", null)
	var marks_value: Variant = state.get("marks", null)
	if not (solution_value is Array) or solution_value.size() != SIZE:
		return false
	if not (marks_value is Array) or marks_value.size() != SIZE * SIZE:
		return false
	for index in range(SIZE * SIZE):
		var row_index: int = int(index / SIZE)
		var col_index: int = index % SIZE
		var row_value: Variant = solution_value[row_index]
		if not (row_value is Array) or row_value.size() != SIZE:
			return false
		var solution_filled: bool = bool(row_value[col_index])
		var marked_filled: bool = int(marks_value[index]) == 1
		if solution_filled != marked_filled:
			return false
	return true
