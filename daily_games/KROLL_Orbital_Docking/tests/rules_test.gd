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
	_test_all_scenarios_have_reference_solutions()
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
		var target_position: Vector2 = scenario["target_position"]
		var ship_position: Vector2 = state["position"]
		assert(target_position.distance_to(ship_position) > 100.0)
	assert(names.size() == 3)

func _test_rotation_and_thrust() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	var before_angle: float = float(state["angle"])
	var before_fuel: float = float(state["fuel"])
	var next: Dictionary = Rules.step(state, {"left": true, "thrust": true}, 0.1, scenario)
	assert(float(next["angle"]) < before_angle)
	assert(float(next["fuel"]) < before_fuel)
	var next_velocity: Vector2 = next["velocity"]
	var original_velocity: Vector2 = state["velocity"]
	assert(next_velocity.length() > original_velocity.length())
	assert(float(state["fuel"]) == before_fuel)

func _test_reverse_thruster() -> void:
	var scenario: Dictionary = Rules.get_scenario(0)
	var state: Dictionary = Rules.create_state(0)
	state["angle"] = 0.0
	state["velocity"] = Vector2(100.0, 0.0)
	var next: Dictionary = Rules.step(state, {"reverse": true}, 0.1, scenario)
	var next_velocity: Vector2 = next["velocity"]
	assert(next_velocity.x < 100.0)
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


func _test_all_scenarios_have_reference_solutions() -> void:
	for index in range(Rules.get_scenario_count()):
		var scenario: Dictionary = Rules.get_scenario(index)
		var state: Dictionary = Rules.create_state(index)
		for frame in range(6600):
			if str(state["status"]) != "active":
				break
			var position: Vector2 = state["position"]
			var velocity: Vector2 = state["velocity"]
			var to_target: Vector2 = scenario["target_position"] - position
			var distance: float = to_target.length()
			var desired_speed: float = minf(220.0, sqrt(2.0 * Rules.REVERSE_ACCELERATION * maxf(0.0, distance - 20.0)))
			var desired_velocity: Vector2 = to_target.normalized() * desired_speed
			var error_vector: Vector2 = desired_velocity - velocity
			var desired_angle: float = float(state["angle"])
			var reverse: bool = false
			if error_vector.length() > 4.0:
				desired_angle = atan2(error_vector.y, error_vector.x)
				var initial_difference: float = wrapf(desired_angle - float(state["angle"]), -PI, PI)
				reverse = absf(initial_difference) > 2.2
				if reverse:
					desired_angle = wrapf(desired_angle + PI, -PI, PI)
			else:
				desired_angle = float(scenario["target_angle"])
			var difference: float = wrapf(desired_angle - float(state["angle"]), -PI, PI)
			var left: bool = difference < -0.04
			var right: bool = difference > 0.04
			var thrust: bool = absf(difference) < 0.15 and not reverse and float(state["fuel"]) > 0.0
			var reverse_thrust: bool = absf(difference) < 0.15 and reverse and float(state["fuel"]) > 0.0
			state = Rules.step(state, {
				"left": left,
				"right": right,
				"thrust": thrust,
				"reverse": reverse_thrust
			}, 1.0 / 60.0, scenario)
		assert(str(state["status"]) == "docked", "scenario %d must have a deterministic reference docking solution" % index)
