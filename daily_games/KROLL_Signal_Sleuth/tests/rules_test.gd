extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Dictionary = Rules.create_game(20261028)
	var same_seed: Dictionary = Rules.create_game(20261028)
	_expect(int(game["puzzle_index"]) == 0, "default seed selects first grid")
	_expect(game["solution"] == same_seed["solution"], "same seed produces the same solution")
	var row_clues: Array = game["row_clues"]
	_expect(row_clues[0] == [1] and row_clues[1] == [3] and row_clues[2] == [5], "row clues describe the first three rows")
	var col_clues: Array = game["col_clues"]
	_expect(col_clues[0] == [3] and col_clues[2] == [5] and col_clues[4] == [3], "column clues describe the first grid")
	var marks: Array = game["marks"]
	var before_marks: Array = marks.duplicate()
	_expect(not Rules.toggle_cell(game, -1, 0), "negative row is rejected")
	_expect(not Rules.toggle_cell(game, 0, Rules.SIZE), "out-of-range column is rejected")
	_expect(marks == before_marks, "invalid coordinates do not mutate the board")
	_expect(Rules.toggle_cell(game, 0, 0), "valid cell toggles")
	_expect(int(marks[0]) == 1 and int(game["moves"]) == 1, "first mark fills a cell")
	_expect(Rules.toggle_cell(game, 0, 0), "cell cycles to an empty mark")
	_expect(int(marks[0]) == 2, "second mark is empty")
	_expect(Rules.toggle_cell(game, 0, 0), "cell cycles back to unknown")
	_expect(int(marks[0]) == 0, "third mark clears the cell")

	var solved: Dictionary = Rules.create_game(20261028)
	var solution: Array = solved["solution"]
	for row in range(Rules.SIZE):
		var solution_row: Array = solution[row]
		for col in range(Rules.SIZE):
			if bool(solution_row[col]):
				_expect(Rules.toggle_cell(solved, row, col), "solution cell accepts fill")
	_expect(str(solved["status"]) == "won", "correct filled pattern wins without marking every empty cell")
	var won_moves: int = int(solved["moves"])
	_expect(not Rules.toggle_cell(solved, 0, 0), "won board is locked")
	_expect(int(solved["moves"]) == won_moves, "post-win input does not mutate moves")

	var limited: Dictionary = Rules.create_game(20261028)
	for _move in range(Rules.MAX_MOVES):
		if str(limited["status"]) == "playing":
			Rules.toggle_cell(limited, 0, 0)
	_expect(str(limited["status"]) == "lost", "sixty valid marks exhaust the move budget")
	_expect(not Rules.toggle_cell(limited, 0, 0), "lost board is locked")

	var next_grid: Dictionary = Rules.create_game(20261029)
	_expect(int(next_grid["puzzle_index"]) == 1, "next seed selects the second puzzle")
	_expect(next_grid["row_clues"] != game["row_clues"], "different puzzle has different clues")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("KROLL Signal Sleuth rules tests passed.")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
