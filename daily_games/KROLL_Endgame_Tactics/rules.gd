extends RefCounted

const BOARD_SIZE: int = 8
const BOARD_CELLS: int = 64
const PUZZLES := [
	{
		"id": "back_rank_seal",
		"name": "Back-Rank Seal",
		"pieces": {
			"WK": Vector2i(5, 2),
			"WR": Vector2i(4, 7),
			"BK": Vector2i(7, 0),
			"BP1": Vector2i(5, 1),
			"BP2": Vector2i(6, 1),
			"BP3": Vector2i(7, 1)
		},
		"mate_from": Vector2i(4, 7),
		"mate_to": Vector2i(4, 0)
	},
	{
		"id": "reverse_file",
		"name": "Reverse File",
		"pieces": {
			"WK": Vector2i(2, 5),
			"WR": Vector2i(3, 0),
			"BK": Vector2i(0, 7),
			"BP1": Vector2i(2, 6),
			"BP2": Vector2i(1, 6),
			"BP3": Vector2i(0, 6)
		},
		"mate_from": Vector2i(3, 0),
		"mate_to": Vector2i(3, 7)
	},
	{
		"id": "side_file_lock",
		"name": "Side-File Lock",
		"pieces": {
			"WK": Vector2i(5, 5),
			"WR": Vector2i(0, 4),
			"BK": Vector2i(7, 7),
			"BP1": Vector2i(6, 5),
			"BP2": Vector2i(6, 6),
			"BP3": Vector2i(6, 7)
		},
		"mate_from": Vector2i(0, 4),
		"mate_to": Vector2i(7, 4)
	}
]

func get_puzzle_count() -> int:
	return PUZZLES.size()

func get_puzzle(index: int) -> Dictionary:
	if index < 0 or index >= PUZZLES.size():
		return {}
	var puzzle: Dictionary = PUZZLES[index].duplicate(true)
	var board := PackedStringArray()
	board.resize(BOARD_CELLS)
	var pieces: Dictionary = puzzle.get("pieces", {})
	for raw_code in pieces.keys():
		var code: String = "BP" if str(raw_code).begins_with("BP") else str(raw_code)
		var position: Vector2i = pieces[raw_code]
		if not _inside(position):
			return {}
		board[_index(position)] = code
	puzzle["board"] = board
	return puzzle

func get_expected_mate_move(index: int) -> Dictionary:
	var puzzle: Dictionary = get_puzzle(index)
	if puzzle.is_empty():
		return {}
	return {"from": puzzle["mate_from"], "to": puzzle["mate_to"]}

func get_legal_rook_moves(board: PackedStringArray, from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if board.size() != BOARD_CELLS or not _inside(from) or board[_index(from)] != "WR":
		return result
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for direction in directions:
		var cursor: Vector2i = from + direction
		while _inside(cursor):
			if not board[_index(cursor)].is_empty():
				break
			result.append(cursor)
			cursor += direction
	return result

func evaluate_move(board: PackedStringArray, from: Vector2i, to: Vector2i) -> Dictionary:
	if board.size() != BOARD_CELLS:
		return {"ok": false, "error": "invalid_board"}
	if not _inside(from) or not _inside(to) or board[_index(from)] != "WR":
		return {"ok": false, "error": "invalid_origin"}
	if not get_legal_rook_moves(board, from).has(to):
		return {"ok": false, "error": "illegal_rook_move"}
	var next_board: PackedStringArray = board.duplicate()
	next_board[_index(from)] = ""
	next_board[_index(to)] = "WR"
	return {"ok": true, "mate": is_checkmate(next_board), "board": next_board}

func get_mating_moves(index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var puzzle: Dictionary = get_puzzle(index)
	if puzzle.is_empty():
		return result
	var board: PackedStringArray = puzzle["board"]
	var from: Vector2i = puzzle["mate_from"]
	for destination in get_legal_rook_moves(board, from):
		var move_report: Dictionary = evaluate_move(board, from, destination)
		if bool(move_report.get("mate", false)):
			result.append(destination)
	return result

func is_black_king_in_check(board: PackedStringArray) -> bool:
	if board.size() != BOARD_CELLS:
		return false
	var king_position: Vector2i = _find_piece(board, "BK")
	return _inside(king_position) and is_square_attacked_by_white(board, king_position)

func is_square_attacked_by_white(board: PackedStringArray, target: Vector2i) -> bool:
	if board.size() != BOARD_CELLS or not _inside(target):
		return false
	var rook_position: Vector2i = _find_piece(board, "WR")
	if _inside(rook_position) and rook_position != target and (
		rook_position.x == target.x or rook_position.y == target.y
	):
		var step_x: int = 0
		var step_y: int = 0
		if target.x > rook_position.x:
			step_x = 1
		elif target.x < rook_position.x:
			step_x = -1
		if target.y > rook_position.y:
			step_y = 1
		elif target.y < rook_position.y:
			step_y = -1
		var cursor := rook_position + Vector2i(step_x, step_y)
		var blocked: bool = false
		while cursor != target:
			if not board[_index(cursor)].is_empty():
				blocked = true
				break
			cursor += Vector2i(step_x, step_y)
		if not blocked:
			return true
	var white_king: Vector2i = _find_piece(board, "WK")
	return _inside(white_king) and white_king != target and (
		maxi(abs(white_king.x - target.x), abs(white_king.y - target.y)) == 1
	)

func is_checkmate(board: PackedStringArray) -> bool:
	if board.size() != BOARD_CELLS:
		return false
	var black_king: Vector2i = _find_piece(board, "BK")
	if not _inside(black_king) or not is_square_attacked_by_white(board, black_king):
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var destination := black_king + Vector2i(dx, dy)
			if not _inside(destination):
				continue
			var occupant: String = board[_index(destination)]
			if occupant == "BK" or occupant == "BP" or occupant == "WK":
				continue
			var simulated: PackedStringArray = board.duplicate()
			simulated[_index(black_king)] = ""
			simulated[_index(destination)] = "BK"
			if not is_square_attacked_by_white(simulated, destination):
				return false
	return true

func _find_piece(board: PackedStringArray, code: String) -> Vector2i:
	var found_index: int = board.find(code)
	if found_index < 0:
		return Vector2i(-1, -1)
	return Vector2i(found_index % BOARD_SIZE, int(found_index / BOARD_SIZE))

func _inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < BOARD_SIZE and position.y >= 0 and position.y < BOARD_SIZE

func _index(position: Vector2i) -> int:
	return position.y * BOARD_SIZE + position.x
