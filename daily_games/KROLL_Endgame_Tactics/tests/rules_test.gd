extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(rules.get_puzzle_count() == 3, "three authored endgame puzzles exist")
	_expect(rules.get_puzzle(-1).is_empty(), "negative puzzle index is rejected")
	_expect(rules.get_puzzle(3).is_empty(), "out-of-range puzzle index is rejected")

	var expected_moves: Array[Dictionary] = [
		{"from": Vector2i(4, 7), "to": Vector2i(4, 0)},
		{"from": Vector2i(3, 0), "to": Vector2i(3, 7)},
		{"from": Vector2i(0, 4), "to": Vector2i(7, 4)}
	]
	for puzzle_index in range(3):
		var puzzle: Dictionary = rules.get_puzzle(puzzle_index)
		var board: PackedStringArray = puzzle.get("board", PackedStringArray())
		_expect(board.size() == 64, "puzzle %d builds a complete 8x8 board" % puzzle_index)
		_expect(str(puzzle.get("id", "")).length() > 0, "puzzle %d has a stable ID" % puzzle_index)
		_expect(not rules.is_black_king_in_check(board), "puzzle %d begins with the black king not in check" % puzzle_index)
		var mating_moves: Array[Vector2i] = rules.get_mating_moves(puzzle_index)
		_expect(mating_moves.size() == 1, "puzzle %d has exactly one rook mate-in-one" % puzzle_index)
		_expect(mating_moves.has(expected_moves[puzzle_index]["to"]), "puzzle %d unique solution matches the authored destination" % puzzle_index)
		var solved: Dictionary = rules.evaluate_move(board, expected_moves[puzzle_index]["from"], expected_moves[puzzle_index]["to"])
		_expect(bool(solved.get("ok", false)) and bool(solved.get("mate", false)), "puzzle %d solution produces checkmate" % puzzle_index)
		_expect(rules.is_checkmate(solved.get("board", PackedStringArray())), "puzzle %d resulting board is checkmate" % puzzle_index)

	var first: Dictionary = rules.get_puzzle(0)
	var initial_board: PackedStringArray = first["board"]
	var wrong_move: Dictionary = rules.evaluate_move(initial_board, Vector2i(4, 7), Vector2i(4, 6))
	_expect(bool(wrong_move.get("ok", false)) and not bool(wrong_move.get("mate", true)), "a legal non-mating rook move is distinguished from checkmate")
	_expect(initial_board[60] == "WR" and initial_board[52].is_empty(), "move evaluation never mutates the caller's board")
	var diagonal: Dictionary = rules.evaluate_move(initial_board, Vector2i(4, 7), Vector2i(5, 6))
	_expect(not bool(diagonal.get("ok", true)), "diagonal rook movement is rejected")
	var blocked: PackedStringArray = initial_board.duplicate()
	blocked[52] = "BP"
	_expect(not rules.get_legal_rook_moves(blocked, Vector2i(4, 7)).has(Vector2i(4, 0)), "a rook cannot move through a blocking piece")
	_expect(rules.get_legal_rook_moves(PackedStringArray(), Vector2i.ZERO).is_empty(), "malformed board input returns no legal moves")
	_expect(not rules.is_checkmate(initial_board), "an unchecked initial position is not reported as checkmate")

	var copied_puzzle: Dictionary = rules.get_puzzle(0)
	var copied_board: PackedStringArray = copied_puzzle["board"]
	copied_board[60] = "BK"
	_expect(rules.get_puzzle(0)["board"][60] == "WR", "puzzle boards are returned as defensive copies")

	if failures.is_empty():
		print("KROLL Endgame Tactics rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
