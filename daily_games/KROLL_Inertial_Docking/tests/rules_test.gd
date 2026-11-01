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
