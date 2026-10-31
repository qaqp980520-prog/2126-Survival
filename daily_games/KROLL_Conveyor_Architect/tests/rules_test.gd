extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_all_solutions()
	_test_missing_conveyor_recovery()
	_test_wall_and_loop_rejection()
	_test_budget_and_invalid_input()
	if failures.is_empty():
		print("KROLL Conveyor Architect rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_all_solutions() -> void:
	for level_index in range(RulesScript.get_level_count()):
		var state: Dictionary = RulesScript.create_state(level_index)
		var path: Array[Vector2i] = RulesScript.get_solution_path(level_index)
		_expect(path.size() >= 2, "level %d has a non-empty route" % level_index)
		for path_index in range(path.size() - 1):
			var direction: int = RulesScript.direction_between(path[path_index], path[path_index + 1])
			_expect(direction >= 0, "level %d solution uses orthogonal directions" % level_index)
			var result: Dictionary = RulesScript.place_conveyor(state, path[path_index], direction)
			_expect(bool(result.get("ok", false)), "level %d accepts solution conveyor %d" % [level_index, path_index])
		var guard: int = path.size() + 2
		while str(state.get("status", "")) != "delivered" and guard > 0:
			RulesScript.advance(state)
			guard -= 1
		_expect(str(state.get("status", "")) == "delivered", "level %d deterministic route delivers cargo" % level_index)
		_expect(state.get("position") == state.get("goal"), "level %d cargo finishes at the receiving dock" % level_index)
		_expect(int(state.get("placements_used", 0)) == int(state.get("placement_budget", -1)), "level %d solution fits the exact conveyor budget" % level_index)

func _test_missing_conveyor_recovery() -> void:
	var state: Dictionary = RulesScript.create_state(0)
	_expect(bool(RulesScript.place_conveyor(state, Vector2i(0, 2), RulesScript.DIRECTION_RIGHT).get("ok", false)), "start conveyor can be placed")
	_expect(bool(RulesScript.advance(state).get("ok", false)), "cargo advances from the input")
	_expect(str(state.get("status", "")) == "running", "cargo enters the next cell")
	var stalled: Dictionary = RulesScript.advance(state)
	_expect(not bool(stalled.get("ok", true)) and str(stalled.get("reason", "")) == "missing_conveyor", "missing conveyor safely stalls cargo")
	_expect(str(state.get("status", "")) == "stalled", "stalled status is explicit")
	_expect(bool(RulesScript.place_conveyor(state, Vector2i(1, 2), RulesScript.DIRECTION_UP).get("ok", false)), "player can repair a stalled route")
	_expect(str(state.get("status", "")) == "planning", "placing a missing conveyor resumes planning")
	_expect(bool(RulesScript.advance(state).get("ok", false)), "repaired route advances cargo")

func _test_wall_and_loop_rejection() -> void:
	var wall_state: Dictionary = RulesScript.create_state(0)
	RulesScript.place_conveyor(wall_state, Vector2i(0, 2), RulesScript.DIRECTION_RIGHT)
	RulesScript.advance(wall_state)
	RulesScript.place_conveyor(wall_state, Vector2i(1, 2), RulesScript.DIRECTION_RIGHT)
	var wall_result: Dictionary = RulesScript.advance(wall_state)
	_expect(str(wall_result.get("reason", "")) == "wall_collision", "cargo cannot pass through a blocked cell")
	_expect(str(wall_state.get("status", "")) == "jammed", "wall collision jams the route")
	var loop_state: Dictionary = RulesScript.create_state(0)
	RulesScript.place_conveyor(loop_state, Vector2i(0, 2), RulesScript.DIRECTION_RIGHT)
	RulesScript.place_conveyor(loop_state, Vector2i(1, 2), RulesScript.DIRECTION_UP)
	RulesScript.place_conveyor(loop_state, Vector2i(1, 1), RulesScript.DIRECTION_DOWN)
	RulesScript.advance(loop_state)
	RulesScript.advance(loop_state)
	var loop_result: Dictionary = RulesScript.advance(loop_state)
	_expect(str(loop_result.get("reason", "")) == "route_loop", "cargo cannot revisit a previously visited cell")
	_expect(str(loop_state.get("status", "")) == "jammed", "route loop is reported as a jam")

func _test_budget_and_invalid_input() -> void:
	var state: Dictionary = RulesScript.create_state(0)
	var path: Array[Vector2i] = RulesScript.get_solution_path(0)
	for path_index in range(path.size() - 1):
		var direction: int = RulesScript.direction_between(path[path_index], path[path_index + 1])
		RulesScript.place_conveyor(state, path[path_index], direction)
	var before: Dictionary = state.duplicate(true)
	var extra: Dictionary = RulesScript.place_conveyor(state, Vector2i(5, 5), RulesScript.DIRECTION_UP)
	_expect(str(extra.get("reason", "")) == "placement_budget_exhausted", "extra conveyors cannot exceed the build budget")
	_expect(state.get("conveyors", {}) == before.get("conveyors", {}), "rejected placement leaves the route unchanged")
	var invalid_direction: Dictionary = RulesScript.place_conveyor(state, Vector2i(5, 4), 9)
	_expect(str(invalid_direction.get("reason", "")) == "invalid_direction", "invalid direction is rejected")
	var goal: Vector2i = state.get("goal", Vector2i.ZERO)
	var goal_result: Dictionary = RulesScript.place_conveyor(state, goal, RulesScript.DIRECTION_LEFT)
	_expect(str(goal_result.get("reason", "")) == "goal_cell", "receiving dock cannot be overwritten")
	var outside: Dictionary = RulesScript.place_conveyor(state, Vector2i(-1, 0), RulesScript.DIRECTION_RIGHT)
	_expect(str(outside.get("reason", "")) == "out_of_bounds", "out-of-bounds cells are rejected")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
