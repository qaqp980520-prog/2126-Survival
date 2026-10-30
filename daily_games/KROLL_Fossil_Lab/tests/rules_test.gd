extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_scenario_count() == 3, "three authored fossil blueprints exist")
	_expect(Rules.get_target_cells(Rules.get_scenario(0)).size() == 12, "each fossil outline contains twelve bone cells")
	for scenario_index in range(Rules.get_scenario_count()):
		var scenario: Dictionary = Rules.get_scenario(scenario_index)
		var state: Dictionary = Rules.create_state(scenario_index)
		for solution in scenario["solution"]:
			var piece_index: int = int(solution["piece_index"])
			state = Rules.select_piece(state, piece_index)
			state = Rules.set_cursor(state, solution["anchor"])
			var rotations: Array = state["rotations"]
			var current_rotation: int = int(rotations[piece_index])
			var delta: int = posmod(int(solution["rotation"]) - current_rotation, 4)
			for _turn in range(delta):
				state = Rules.rotate_selected(state, 1)
			state = Rules.place_selected(state, scenario)
			_expect(state["placements"].has(piece_index), "authored solution places fragment %d in scenario %d" % [piece_index, scenario_index])
		_expect(Rules.is_won(state, scenario), "scenario %d is fully reconstructed by its authored solution" % scenario_index)
		_expect(state["placements"].size() == Rules.PIECE_COUNT, "scenario %d uses every fragment exactly once" % scenario_index)

	var scenario_zero: Dictionary = Rules.get_scenario(0)
	var state_zero: Dictionary = Rules.create_state(0)
	state_zero = Rules.select_piece(state_zero, 0)
	state_zero = Rules.set_cursor(state_zero, Vector2i(0, 0))
	state_zero = Rules.place_selected(state_zero, scenario_zero)
	_expect(not Rules.can_place(state_zero, scenario_zero, 0, Vector2i(0, 0), 0), "a placed fragment cannot be placed twice")
	_expect(not Rules.can_place(state_zero, scenario_zero, 1, Vector2i(1, 0), 0), "overlapping or non-target fragments are rejected")
	_expect(not Rules.can_place(state_zero, scenario_zero, 0, Vector2i(4, 4), 0), "fragments extending beyond the board are rejected")
	_expect(not Rules.can_place(state_zero, scenario_zero, 0, Vector2i(0, 2), 0), "cells outside the fossil silhouette are rejected")
	var rotated_cells: Array[Vector2i] = Rules.get_piece_cells(0, 1, Vector2i(2, 1))
	_expect(rotated_cells == [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)], "quarter-turn rotation is normalized around the anchor")
	state_zero = Rules.remove_selected(state_zero)
	_expect(state_zero["placements"].is_empty() and not Rules.is_won(state_zero, scenario_zero), "undo removes the selected fragment and clears victory")
	state_zero = Rules.set_cursor(state_zero, Vector2i(99, -4))
	_expect(state_zero["cursor"] == Vector2i(4, 0), "cursor movement clamps to board boundaries")
	_expect(Rules.get_scenario(-1)["name"] == Rules.get_scenario(2)["name"], "scenario selection wraps deterministically")
	_finish(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if exit_code == 0 and failures.is_empty():
		print("KROLL Fossil Lab rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
