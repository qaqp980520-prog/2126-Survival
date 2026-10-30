extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_scenarios()
	_test_rotation_and_thrust()
	_test_reverse_thruster()
	_test_docking_constraints()
	_test_docking_success_and_terminal_lock()
	_test_timeout_and_invalid_delta()
	print("KROLL Orbital Docking rules tests passed.")
	quit(0)

func _test_scenarios() -> void:
	assert(Rules.get_scenario_count() == 3)
	var names: Array[String] = []
	for index in range(Rules.get_scenario_count()):
		var scenario: Dictionary = Rules.get_scenario(index)
		var state: Dictionary = Rules.create_state(index)
		assert(Rules.validate_state(state))
		names.append(str(scenario["name"]))
		assert((scenario["target_position"] as Vector2).distance_to(state["position"]) > 100.0)
	assert(names.size() == 3)

func _test_rotation_and_thrust() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	var before_angle: float = float(state["angle"])
	var before_fuel: float = float(state["fuel"])
	var next: Dictionary = Rules.step(state, {"left": true, "thrust": true}, 0.1, scenario)
	assert(float(next["angle"]) < before_angle)
	assert(float(next["fuel"]) < before_fuel)
	assert((next["velocity"] as Vector2).length() > (state["velocity"] as Vector2).length())
	assert(float(state["fuel"]) == before_fuel)

func _test_reverse_thruster() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	state["angle"] = 0.0
	state["velocity"] = Vector2(100.0, 0.0)
	var next: Dictionary = Rules.step(state, {"reverse": true}, 0.1, scenario)
	assert((next["velocity"] as Vector2).x < 100.0)
	assert(float(next["fuel"]) < float(state["fuel"]))

func _test_docking_constraints() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	state["position"] = scenario["target_position"] + Vector2(10.0, 0.0)
	state["velocity"] = Vector2(90.0, 0.0)
	state["angle"] = float(scenario["target_angle"])
	assert(not Rules.can_dock(state, scenario))
	state["velocity"] = Vector2.ZERO
	state["angle"] = float(scenario["target_angle"]) + 0.8
	assert(not Rules.can_dock(state, scenario))
	state["angle"] = float(scenario["target_angle"])
	state["position"] = scenario["target_position"] + Vector2(100.0, 0.0)
	assert(not Rules.can_dock(state, scenario))

func _test_docking_success_and_terminal_lock() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	state["position"] = scenario["target_position"] + Vector2(10.0, 0.0)
	state["velocity"] = Vector2.ZERO
	state["angle"] = float(scenario["target_angle"])
	var docked: Dictionary = Rules.step(state, {}, 0.016, scenario)
	assert(str(docked["status"]) == "docked")
	var locked: Dictionary = Rules.step(docked, {"thrust": true, "left": true}, 0.1, scenario)
	assert(locked == docked)

func _test_timeout_and_invalid_delta() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	var unchanged: Dictionary = Rules.step(state, {"thrust": true}, -0.1, scenario)
	assert(unchanged == state)
	state["elapsed"] = float(scenario["time_limit"])
	var failed: Dictionary = Rules.step(state, {}, 0.016, scenario)
	assert(str(failed["status"]) == "failed")
