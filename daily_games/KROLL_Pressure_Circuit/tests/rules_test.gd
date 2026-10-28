extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.create_puzzle(2701)
	var second: Dictionary = Rules.create_puzzle(2701)
	_expect(first.get("masks", []) == second.get("masks", []), "same seed creates the same scrambled board")
	_expect(first.get("path", []).size() == 9, "solution path has nine connected pipe cells")
	_expect(not Rules.is_solved(first), "scrambled puzzle does not start solved")

	var mask := Rules.DIR_N
	for _turn in range(4):
		mask = Rules.rotate_mask(mask)
	_expect(mask == Rules.DIR_N, "four clockwise turns restore the original connector")

	var corner := Rules.DIR_N | Rules.DIR_E
	_expect(Rules.rotate_mask(corner) == (Rules.DIR_E | Rules.DIR_S), "clockwise rotation preserves elbow geometry")
	_expect(not Rules.rotate_tile(first, Vector2i(-1, 2)), "out-of-board rotation is rejected")
	_expect(not Rules.rotate_tile(first, Vector2i(5, 5)), "empty tile rotation is rejected")
	_expect(int(first.get("moves", -1)) == 0, "rejected rotations do not consume moves")

	var solved: Dictionary = Rules.create_puzzle(2701)
	solved["masks"] = (solved["solution_masks"] as Array).duplicate()
	var solution_path: Array = solved["path"]
	var solution_masks: Array = solved["solution_masks"]
	var reciprocal_connections_valid := true
	for path_index in range(solution_path.size() - 1):
		var current: Vector2i = solution_path[path_index]
		var next_cell: Vector2i = solution_path[path_index + 1]
		var delta: Vector2i = next_cell - current
		var outgoing_bit: int = Rules._direction_bit(delta)
		var incoming_bit: int = Rules._direction_bit(-delta)
		var current_mask := int(solution_masks[current.y * Rules.COLS + current.x])
		var next_mask := int(solution_masks[next_cell.y * Rules.COLS + next_cell.x])
		if (current_mask & outgoing_bit) == 0 or (next_mask & incoming_bit) == 0:
			reciprocal_connections_valid = false
	_expect(reciprocal_connections_valid, "every adjacent solution path pair has reciprocal connectors")
	_expect(Rules.is_solved(solved), "the stored solution connects source to target")
	var solved_source: Vector2i = solved["source"]
	_expect(not Rules.rotate_tile(solved, solved_source), "solved puzzle is terminal and rejects further rotations")
	_expect(int(solved.get("moves", -1)) == 0, "rejected post-win rotation does not change the move count")

	var solvable: Dictionary = Rules.create_puzzle(2705)
	var solvable_path: Array = solvable["path"]
	var solvable_masks: Array = solvable["masks"]
	var solved_masks: Array = solvable["solution_masks"]
	for cell_value in solvable_path:
		var cell: Vector2i = cell_value
		var index := cell.y * Rules.COLS + cell.x
		var guard := 0
		while int(solvable_masks[index]) != int(solved_masks[index]) and not Rules.is_solved(solvable) and guard < 4:
			_expect(Rules.rotate_tile(solvable, cell), "solution rotation is accepted before terminal state")
			guard += 1
	_expect(Rules.is_solved(solvable), "scrambled board can connect IN to OUT within the move limit")
	_expect(int(solvable.get("moves", Rules.MAX_MOVES + 1)) <= Rules.MAX_MOVES, "solving the puzzle stays within the move limit")

	var invalid_target: Dictionary = Rules.create_puzzle(2703)
	invalid_target["target"] = Vector2i(6, 1)
	_expect(not Rules.is_solved(invalid_target), "out-of-board target cannot alias an in-board cell index")
	var malformed_board: Dictionary = Rules.create_puzzle(2704)
	malformed_board["masks"] = [Rules.DIR_E]
	_expect(not Rules.is_solved(malformed_board), "malformed mask array cannot report a connected route")

	var blocked: Dictionary = Rules.create_puzzle(2702)
	var blocked_masks: Array = blocked["masks"]
	for index in range(blocked_masks.size()):
		blocked_masks[index] = 0
	var source: Vector2i = blocked["source"]
	blocked_masks[source.y * Rules.COLS + source.x] = Rules.DIR_N
	_expect(not Rules.is_solved(blocked), "a source with no reciprocal neighbour cannot reach the target")
	for _move in range(Rules.MAX_MOVES):
		_expect(Rules.rotate_tile(blocked, source), "rotation is accepted while moves remain")
	_expect(Rules.is_failed(blocked), "reaching the move limit without a route fails the puzzle")
	_expect(not Rules.rotate_tile(blocked, source), "rotation after the move limit is rejected")
	_expect(int(blocked.get("moves", -1)) == Rules.MAX_MOVES, "move count never exceeds the configured limit")

	print("KROLL Pressure Circuit rules tests passed." if failures.is_empty() else "KROLL Pressure Circuit rules tests failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
