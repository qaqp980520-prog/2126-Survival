extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules := Rules.new()
	_test_scenarios(rules)
	_test_thrusters_and_immutability(rules)
	_test_braking_and_moving_target(rules)
	_test_collision_and_bounds(rules)
	_test_docking_and_campaign(rules)
	_test_reference_routes(rules)
	_test_invalid_inputs(rules)
	if failures.is_empty():
		print("KROLL Inertial Docking rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_scenarios(rules: RefCounted) -> void:
	_expect(rules.get_scenario_count() == 3, "three docking trials are authored")
	_expect(rules.get_scenario(-1).is_empty() and rules.get_scenario(3).is_empty(), "invalid trial indices are rejected")
	var ids: Array[String] = []
	for index in range(rules.get_scenario_count()):
		var scenario: Dictionary = rules.get_scenario(index)
		ids.append(str(scenario.get("id", "")))
		var state: Dictionary = rules.make_state(index)
		_expect(str(state.get("status", "")) == "flying", "trial %d starts in flight" % index)
		_expect(state.get("position") is Vector2 and state.get("target_base") is Vector2, "trial %d uses vector position state" % index)
	_expect(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2], "all three trials have distinct identifiers")
	_expect(rules.make_state(-1).is_empty(), "invalid trial creation returns an empty state")

func _test_thrusters_and_immutability(rules: RefCounted) -> void:
	var state: Dictionary = rules.make_state(0)
	var original: Dictionary = state.duplicate(true)
	var result: Dictionary = rules.step(state, {"thrust":true,"right":true}, 0.05)
	_expect(bool(result.get("ok", false)), "valid thruster step succeeds")
	if bool(result.get("ok", false)):
		var updated: Dictionary = result["state"]
		var updated_velocity: Vector2 = updated["velocity"]
		_expect(updated_velocity.length() > 0.0, "main thruster accelerates the craft")
		_expect(float(updated["angle"]) > 0.0, "right yaw input rotates the craft")
		_expect(float(updated["fuel"]) < float(original["fuel"]), "thrusters consume finite fuel")
		_expect((state["position"] as Vector2).is_equal_approx(original["position"]), "step does not mutate caller position")
		_expect(float(state["fuel"]) == float(original["fuel"]), "step does not mutate caller fuel")

func _test_braking_and_moving_target(rules: RefCounted) -> void:
	var state: Dictionary = rules.make_state(0)
	state["velocity"] = Vector2(70.0, 0.0)
	var result: Dictionary = rules.step(state, {"brake":true}, 0.05)
	_expect(bool(result.get("ok", false)), "braking step succeeds")
	if bool(result.get("ok", false)):
		var braked_velocity: Vector2 = result["state"]["velocity"]
		_expect(braked_velocity.length() < 70.0, "retro-brake reduces relative speed")
	var moving_brake_state: Dictionary = rules.make_state(1)
	moving_brake_state["velocity"] = moving_brake_state["target_velocity"]
	var moving_brake: Dictionary = rules.step(moving_brake_state, {"brake":true}, 0.05)
	var target_velocity: Vector2 = moving_brake_state["target_velocity"]
	var braked_moving_velocity: Vector2 = moving_brake["state"]["velocity"]
	_expect(braked_moving_velocity.distance_to(target_velocity) < 0.001, "retro-brake does not introduce drift when already matching a moving berth")
	var moving: Dictionary = rules.make_state(1)
	var before: Vector2 = rules.call("get_target_position", moving)
	var advanced: Dictionary = rules.step(moving, {}, 0.05)
	_expect(bool(advanced.get("ok", false)), "unpowered drift step succeeds")
	if bool(advanced.get("ok", false)):
		var after_state: Dictionary = advanced["state"]
		var after: Vector2 = rules.call("get_target_position", after_state)
		_expect(before.distance_to(after) > 0.001, "moving berth position advances with elapsed time")

func _test_collision_and_bounds(rules: RefCounted) -> void:
	var collision_state: Dictionary = rules.make_state(2)
	var obstacle: Dictionary = collision_state["obstacles"][0]
	collision_state["position"] = obstacle["position"]
	var collision_result: Dictionary = rules.step(collision_state, {}, 0.016)
	_expect(bool(collision_result.get("ok", false)), "collision step is valid")
	_expect(str(collision_result.get("state", {}).get("status", "")) == "crashed", "debris collision ends the trial")
	var boundary_state: Dictionary = rules.make_state(0)
	boundary_state["position"] = Vector2(361.0, 0.0)
	var boundary_result: Dictionary = rules.step(boundary_state, {}, 0.016)
	_expect(str(boundary_result.get("state", {}).get("status", "")) == "lost", "leaving the navigation envelope ends the trial")

func _test_docking_and_campaign(rules: RefCounted) -> void:
	var state: Dictionary = rules.make_state(0)
	state["position"] = rules.call("get_target_position", state)
	state["velocity"] = Vector2.ZERO
	state["angle"] = float(state["target_heading"])
	for _index in range(22):
		var result: Dictionary = rules.step(state, {}, 0.05)
		_expect(bool(result.get("ok", false)), "docking dwell step remains valid")
		state = result["state"]
		if str(state["status"]) == "docked":
			break
	_expect(str(state["status"]) == "docked", "stable low-speed aligned craft docks after the dwell interval")
	var second: Dictionary = rules.advance_state(state)["state"]
	_expect(int(second.get("scenario_index", -1)) == 1, "successful docking advances to the moving berth")
	var last: Dictionary = rules.make_state(2)
	last["position"] = rules.call("get_target_position", last)
	last["velocity"] = Vector2.ZERO
	last["angle"] = float(last["target_heading"])
	for _index in range(22):
		last = rules.step(last, {}, 0.05)["state"]
		if str(last["status"]) == "docked":
			break
	var completed: Dictionary = rules.advance_state(last)["state"]
	_expect(str(completed.get("status", "")) == "campaign_complete", "third successful docking completes the campaign")

func _test_reference_routes(rules: RefCounted) -> void:
	var routes: Array = [
		[Vector2(0.0,0.0), Vector2(200.0,110.0), Vector2(260.0,140.0)],
		[Vector2(-120.0,175.0), Vector2(0.0,140.0), Vector2(180.0,70.0), Vector2(240.0,-80.0)],
		[Vector2(-160.0,100.0), Vector2(0.0,150.0), Vector2(180.0,150.0), Vector2(260.0,70.0)]
	]
	for scenario_index in range(routes.size()):
		var final_state: Dictionary = _run_reference_route(rules, scenario_index, routes[scenario_index])
		_expect(str(final_state.get("status", "")) == "docked", "authored reference route completes %s" % str(rules.get_scenario(scenario_index).get("name", scenario_index)))

func _run_reference_route(rules: RefCounted, scenario_index: int, waypoints: Array) -> Dictionary:
	var state: Dictionary = rules.make_state(scenario_index)
	var waypoint_index: int = 0
	for _frame in range(2400):
		var target: Vector2 = rules.call("get_target_position", state)
		var waypoint: Vector2 = waypoints[waypoint_index] if waypoint_index < waypoints.size() else target
		var position: Vector2 = state["position"]
		var velocity: Vector2 = state["velocity"]
		var offset: Vector2 = waypoint - position
		var distance: float = offset.length()
		if distance < 28.0 and waypoint_index < waypoints.size():
			waypoint_index += 1
			waypoint = waypoints[waypoint_index] if waypoint_index < waypoints.size() else target
			offset = waypoint - position
			distance = offset.length()
		var desired_speed: float = minf(55.0, sqrt(maxf(0.0, 44.0 * distance)))
		var desired_velocity: Vector2 = offset.normalized() * desired_speed
		var acceleration: Vector2 = (desired_velocity - velocity) * 0.45
		var controls: Dictionary = {}
		if acceleration.length() > 1.0:
			var acceleration_direction: Vector2 = acceleration.normalized()
			var forward := Vector2(cos(float(state["angle"])), sin(float(state["angle"])))
			var reversing: bool = acceleration_direction.dot(forward) < 0.0
			var aim_direction: Vector2 = acceleration_direction * (-1.0 if reversing else 1.0)
			var angle_error: float = wrapf(atan2(aim_direction.y, aim_direction.x) - float(state["angle"]), -PI, PI)
			controls = {
				"left":angle_error < -0.035,
				"right":angle_error > 0.035,
				"thrust":not reversing and absf(angle_error) < 0.25 and float(state["fuel"]) > 0.0 and acceleration.length() > 1.8,
				"reverse":reversing and absf(angle_error) < 0.25 and float(state["fuel"]) > 0.0 and acceleration.length() > 1.8,
				"brake":false
			}
		else:
			var relative_speed_for_brake: float = (velocity - state["target_velocity"]).length()
			controls = {"left":false,"right":false,"thrust":false,"reverse":false,"brake":relative_speed_for_brake > 3.0 and distance < 70.0}
		if waypoint_index >= waypoints.size() and distance < 75.0:
			var docking_error: float = wrapf(float(state["target_heading"]) - float(state["angle"]), -PI, PI)
			var relative_speed_for_docking: float = (velocity - state["target_velocity"]).length()
			controls["left"] = docking_error < -0.035
			controls["right"] = docking_error > 0.035
			controls["thrust"] = false
			controls["reverse"] = false
			controls["brake"] = relative_speed_for_docking > 2.5
		var result: Dictionary = rules.step(state, controls, 0.05)
		if not bool(result.get("ok", false)):
			return {}
		state = result["state"]
		if str(state.get("status", "")) != "flying":
			break
	return state

func _test_invalid_inputs(rules: RefCounted) -> void:
	_expect(not bool(rules.step({}, {}, 0.05).get("ok", false)), "empty state is rejected")
	var state: Dictionary = rules.make_state(0)
	_expect(not bool(rules.step(state, {}, 0.0).get("ok", false)), "zero delta is rejected")
	_expect(not bool(rules.step(state, {}, -0.1).get("ok", false)), "negative delta is rejected")
	state["fuel"] = -1.0
	_expect(not bool(rules.step(state, {}, 0.05).get("ok", false)), "negative fuel state is rejected")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
