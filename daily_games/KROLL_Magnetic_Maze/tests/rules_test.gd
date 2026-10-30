extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.create_state(0)
	for _step in range(3):
		first = _pulse(first)
	_expect(Rules.get_status(first) == "won", "Dockside Straight is solved in three pushes")

	var second: Dictionary = Rules.create_state(1)
	second = _move_many(second, [Vector2i.UP, Vector2i.UP, Vector2i.RIGHT])
	second = _pulse(second)
	second = _pulse(second)
	second = _move_many(second, [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP])
	second = _pulse(second)
	second = _pulse(second)
	_expect(Rules.get_status(second) == "won", "Corner Transfer is solved with a two-axis route")
	_expect(int(second.get("moves", 0)) <= Rules.MOVE_LIMIT, "Corner Transfer remains inside the action budget")

	var third: Dictionary = Rules.create_state(2)
	for _step in range(4):
		third = _pulse(third)
	third = _move_many(third, [Vector2i.UP, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN])
	for _step in range(4):
		third = _pulse(third)
	_expect(Rules.get_status(third) == "won", "Split-Level Route is solved using eight magnetic charges")
	_expect(int(third.get("charges", -1)) == 0, "Split-Level Route uses exactly its eight-charge budget")

	var pull_state: Dictionary = Rules.create_state(0)
	pull_state["mode"] = "pull"
	var pull_result: Dictionary = Rules.pulse(pull_state)
	_expect(bool(pull_result.get("ok", false)), "pull mode can attract an aligned crate")
	pull_state = pull_result.get("state", pull_state)
	_expect(Vector2i(pull_state["crate"]) == Vector2i(1, 3), "pull mode moves the crate one cell toward the player")
	var charges_before: int = int(pull_state["charges"])
	var blocked_pull: Dictionary = Rules.pulse(pull_state)
	_expect(not bool(blocked_pull.get("ok", false)), "pull cannot move a crate into the player")
	_expect(int(blocked_pull.get("state", {}).get("charges", -1)) == charges_before, "blocked pull does not consume a charge")

	var invalid_state: Dictionary = Rules.create_state(0)
	var invalid_before: Dictionary = invalid_state.duplicate(true)
	var invalid_move: Dictionary = Rules.move_player(invalid_state, Vector2i(1, 1))
	_expect(not bool(invalid_move.get("ok", false)), "diagonal movement is rejected")
	_expect(invalid_move.get("state", {}) == invalid_before, "invalid movement leaves the state unchanged")

	var wall_state: Dictionary = Rules.create_state(0)
	wall_state["player"] = Vector2i(3, 0)
	wall_state["crate"] = Vector2i(3, 4)
	wall_state["facing"] = Vector2i.DOWN
	var wall_pulse: Dictionary = Rules.pulse(wall_state)
	_expect(not bool(wall_pulse.get("ok", false)), "a wall blocks the magnetic ray")
	_expect(int(wall_pulse.get("state", {}).get("charges", -1)) == int(wall_state["charges"]), "blocked ray does not consume a charge")

	var blocked_move_state: Dictionary = Rules.create_state(0)
	var blocked_move: Dictionary = Rules.move_player(blocked_move_state, Vector2i.LEFT)
	_expect(bool(blocked_move.get("ok", false)) and not bool(blocked_move.get("moved", true)), "blocked movement still updates facing without spending an action")
	_expect(Vector2i(blocked_move.get("state", {})["facing"]) == Vector2i.LEFT, "blocked movement turns the magnet toward the attempted direction")

	if failures.is_empty():
		print("KROLL Magnetic Maze rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _pulse(state: Dictionary) -> Dictionary:
	var result: Dictionary = Rules.pulse(state)
	_expect(bool(result.get("ok", false)), "magnetic pulse succeeds along a clear ray")
	return result.get("state", state)

func _move_many(state: Dictionary, directions: Array[Vector2i]) -> Dictionary:
	for direction in directions:
		var result: Dictionary = Rules.move_player(state, direction)
		_expect(bool(result.get("ok", false)), "cardinal movement input is accepted")
		state = result.get("state", state)
	return state

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
