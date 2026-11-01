extends RefCounted

const PUZZLES: Array[Dictionary] = [
	{"id":"delta_relay","name":"Delta Relay","brief":"Reconstruct the buried signal glyph from six scan rows.","rows":["001100","011110","111111","110011","011110","001100"]},
	{"id":"basalt_archive","name":"Basalt Archive","brief":"Map the stepped basalt deposit without leaving an unknown cell.","rows":["100001","110011","111111","011110","001100","000000"]},
	{"id":"ice_shelf","name":"Ice Shelf","brief":"Recover the ice-shelf survey outline from the raster scan.","rows":["111111","100001","101101","100001","111111","000000"]}
]

func get_puzzle_count() -> int:
	return PUZZLES.size()

func get_puzzle(index: int) -> Dictionary:
	if index < 0 or index >= PUZZLES.size():
		return {}
	return PUZZLES[index].duplicate(true)

func make_state(index: int) -> Dictionary:
	if index < 0 or index >= PUZZLES.size():
		return {}
	var board: Array = []
	for _y in range(6):
		var row: Array[int] = []
		for _x in range(6):
			row.append(0)
		board.append(row)
	return {"puzzle_index":index,"board":board,"moves":0,"status":"playing"}

func get_row_clues(puzzle: Dictionary) -> Array:
	var result: Array = []
	for row_text in puzzle.get("rows", []):
		var line: Array[int] = []
		for column in range(str(row_text).length()):
			line.append(1 if str(row_text).substr(column, 1) == "1" else 0)
		result.append(_line_clues(line))
	return result

func get_column_clues(puzzle: Dictionary) -> Array:
	var result: Array = []
	var rows: Array = puzzle.get("rows", [])
	if rows.is_empty():
		return result
	for x in range(str(rows[0]).length()):
		var line: Array[int] = []
		for row_text in rows:
			line.append(1 if str(row_text).substr(x, 1) == "1" else 0)
		result.append(_line_clues(line))
	return result

func _line_clues(line: Array[int]) -> Array[int]:
	var clues: Array[int] = []
	var run: int = 0
	for value in line:
		if value == 1:
			run += 1
		elif run > 0:
			clues.append(run)
			run = 0
	if run > 0:
		clues.append(run)
	if clues.is_empty():
		clues.append(0)
	return clues

func mark_cell(state: Dictionary, x: int, y: int, mark: int) -> Dictionary:
	if not _valid_state(state) or str(state.get("status", "")) != "playing":
		return {"ok":false,"reason":"invalid_or_finished_state"}
	if x < 0 or x >= 6 or y < 0 or y >= 6:
		return {"ok":false,"reason":"out_of_bounds"}
	if mark < 0 or mark > 2:
		return {"ok":false,"reason":"invalid_mark"}
	var updated: Dictionary = state.duplicate(true)
	var board: Array = updated["board"]
	var changed: bool = int(board[y][x]) != mark
	if changed:
		board[y][x] = mark
		updated["moves"] = int(updated.get("moves", 0)) + 1
	if _is_solved(updated):
		updated["status"] = "solved"
	return {"ok":true,"changed":changed,"state":updated}

func is_solved(state: Dictionary) -> bool:
	return _valid_state(state) and _is_solved(state)

func _is_solved(state: Dictionary) -> bool:
	var puzzle: Dictionary = get_puzzle(int(state.get("puzzle_index", -1)))
	if puzzle.is_empty():
		return false
	var rows: Array = puzzle["rows"]
	var board: Array = state["board"]
	for y in range(6):
		for x in range(6):
			var filled: bool = str(rows[y]).substr(x, 1) == "1"
			var expected: int = 1 if filled else 2
			if int(board[y][x]) != expected:
				return false
	return true

func get_progress(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {"marked":0,"total":36,"moves":0,"solved":false}
	var marked: int = 0
	var board: Array = state["board"]
	for row in board:
		for value in row:
			if int(value) != 0:
				marked += 1
	return {"marked":marked,"total":36,"moves":int(state.get("moves", 0)),"solved":_is_solved(state)}

func reset_state(state: Dictionary) -> Dictionary:
	if not _valid_state(state):
		return {}
	return make_state(int(state["puzzle_index"]))

func advance_state(state: Dictionary) -> Dictionary:
	if not _valid_state(state) or str(state.get("status", "")) != "solved":
		return {"ok":false,"reason":"site_not_solved"}
	var next_index: int = int(state["puzzle_index"]) + 1
	if next_index >= PUZZLES.size():
		var finished: Dictionary = state.duplicate(true)
		finished["status"] = "campaign_complete"
		return {"ok":true,"state":finished}
	return {"ok":true,"state":make_state(next_index)}

func _valid_state(state: Dictionary) -> bool:
	if not state.has("puzzle_index") or not state.has("board") or not state.has("moves") or not state.has("status"):
		return false
	var index: Variant = state["puzzle_index"]
	var moves: Variant = state["moves"]
	var board: Variant = state["board"]
	if not (index is int) or int(index) < 0 or int(index) >= PUZZLES.size():
		return false
	if not (moves is int) or int(moves) < 0:
		return false
	if not (board is Array) or board.size() != 6:
		return false
	for row in board:
		if not (row is Array) or row.size() != 6:
			return false
		for value in row:
			if not (value is int) or int(value) < 0 or int(value) > 2:
				return false
	return str(state["status"]) in ["playing","solved","campaign_complete"]
