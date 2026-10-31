extends SceneTree
const Rules = preload("res://rules.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	_expect(Rules.LEVELS.size() == 3, "three authored knight circuits are available")
	for level_index in range(Rules.LEVELS.size()):
		var level: Dictionary = Rules.get_level(level_index)
		var solution: Array = level.get("solution", [])
		_expect(Rules.validate_solution(solution), "level %d has a complete legal 25-square knight tour" % level_index)
		var state: Dictionary = Rules.new_game(level_index)
		_expect(str(state.get("level_id", "")) == str(level.get("id", "")), "level %d initializes with its stable ID" % level_index)
		_expect(state["position"] == level["start"], "level %d starts at its authored square" % level_index)
	var state: Dictionary = Rules.new_game(0)
	var first_hint: Vector2i = Rules.solution_next_move(state)
	_expect(first_hint == Vector2i(2,1), "first level hint points to the next legal tour square")
	_expect(Rules.can_move(state, first_hint), "authored hint is a legal knight move")
	var moved: Dictionary = Rules.move(state, first_hint)
	_expect(int(moved["moves"]) == 1 and moved["visited"].size() == 2, "legal knight move records one new visited square")
	var revisit: Dictionary = Rules.move(moved, Vector2i(0,0))
	_expect(int(revisit["moves"]) == 1, "visited start square cannot be entered again")
	var illegal: Dictionary = Rules.move(moved, Vector2i(3,1))
	_expect(int(illegal["moves"]) == 1, "non-knight movement is rejected")
	var undo: Dictionary = Rules.undo(moved)
	_expect(int(undo["moves"]) == 0 and undo["position"] == Vector2i(0,0), "undo restores the previous square and move count")
	var reset: Dictionary = Rules.reset(moved)
	_expect(int(reset["moves"]) == 0 and reset["visited"].size() == 1, "reset restores the level's starting state")
	var no_undo: Dictionary = Rules.undo(reset)
	_expect(no_undo["visited"].size() == 1, "undo cannot remove the starting square")
	for level_index in range(Rules.LEVELS.size()):
		var level: Dictionary = Rules.get_level(level_index)
		var solution: Array = level["solution"]
		var route: Dictionary = Rules.new_game(level_index)
		for index in range(1, solution.size()):
			route = Rules.move(route, solution[index])
		_expect(str(route["status"]) == "complete" and int(route["moves"]) == 24, "level %d completes after exactly 24 legal jumps" % level_index)
		var next: Dictionary = Rules.next_level(route)
		_expect(int(next["level_index"]) == (level_index + 1) % Rules.LEVELS.size(), "completed level %d advances to the next circuit" % level_index)
	var blocked: Dictionary = Rules.next_level(Rules.new_game(0))
	_expect(int(blocked["level_index"]) == 0, "unfinished circuit cannot be skipped")
	_expect(not Rules.is_in_bounds(Vector2i(-1,0)) and not Rules.is_in_bounds(Vector2i(5,5)), "out-of-board coordinates are rejected")
	if failures.is_empty():
		print("KROLL Knight Circuit rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
