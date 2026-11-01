extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules := Rules.new()
	_test_scenarios_and_initial_state(rules)
	_test_controls_and_output(rules)
	_test_battery_and_failure(rules)
	_test_heat_trip(rules)
	_test_all_arrays_can_be_completed(rules)
	if failures.is_empty():
		print("KROLL Wind Farm Dispatch rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_scenarios_and_initial_state(rules: RefCounted) -> void:
	_expect(rules.get_scenario_count() == 3, "three authored wind arrays exist")
	_expect(rules.get_scenario(-1).is_empty() and rules.get_scenario(3).is_empty(), "invalid scenario indices are rejected")
	var state: Dictionary = rules.make_state(0)
	_expect(str(state.get("status", "")) == "playing", "new array starts in playing state")
	_expect(int(state.get("battery", -1)) == Rules.INITIAL_BATTERY, "new array receives the defined battery reserve")
	_expect(state.get("turbines", []).size() == 3, "three independently controlled turbines are created")
	_expect(rules.get_current_weather(state).get("wind_direction", -1) == 0, "North Array begins with a north wind")
	_expect(rules.make_state(-1).is_empty(), "invalid array creation returns an empty state")

func _test_controls_and_output(rules: RefCounted) -> void:
	var state: Dictionary = rules.make_state(0)
	var original: Dictionary = state.duplicate(true)
	_expect(not bool(rules.set_turbine_yaw(state, -1, 0).get("ok", false)), "negative turbine indices are rejected")
	_expect(not bool(rules.set_turbine_yaw(state, 0, 4).get("ok", false)), "yaw outside the four cardinal directions is rejected")
	_expect(not bool(rules.set_turbine_pitch(state, 3, 1).get("ok", false)), "out-of-range turbine indices are rejected")
	_expect(not bool(rules.set_turbine_pitch(state, 0, -1).get("ok", false)), "negative blade pitch is rejected")
	var yaw_result: Dictionary = rules.set_turbine_yaw(state, 0, 1)
	_expect(bool(yaw_result.get("ok", false)), "valid yaw adjustment succeeds")
	_expect(int(state["turbines"][0]["yaw"]) == int(original["turbines"][0]["yaw"]), "yaw adjustment does not mutate the caller's state")
	_expect(rules.estimate_turbine_output(4, 0, 0, 1) == 4, "aligned medium pitch produces four units at wind speed four")
	_expect(rules.estimate_turbine_output(4, 0, 2, 1) == 0, "opposite yaw produces no rounded output at the same wind speed")
	_expect(rules.estimate_turbine_output(4, 0, 0, 0) > rules.estimate_turbine_output(4, 0, 0, 2), "aggressive pitch increases output")
	_expect(rules.estimate_turbine_output(4, 0, 0, 4) == -1, "invalid pitch is rejected by the estimator")

func _test_battery_and_failure(rules: RefCounted) -> void:
	var surplus_state: Dictionary = rules.make_state(0)
	for index in range(3):
		var yaw_result: Dictionary = rules.set_turbine_yaw(surplus_state, index, 0)
		surplus_state = yaw_result["state"]
		var pitch_result: Dictionary = rules.set_turbine_pitch(surplus_state, index, 1)
		surplus_state = pitch_result["state"]
	var surplus_result: Dictionary = rules.resolve_round(surplus_state)
	_expect(bool(surplus_result.get("ok", false)), "valid round resolves")
	if bool(surplus_result.get("ok", false)):
		var surplus_next: Dictionary = surplus_result["state"]
		_expect(int(surplus_result["report"]["generation"]) == 9, "three aligned turbines generate nine units in the first wind window")
		_expect(int(surplus_next["battery"]) == 8, "surplus generation charges the battery up to capacity")
		_expect(bool(surplus_result["report"]["served"]), "surplus generation serves the grid demand")
	var failed_state: Dictionary = rules.make_state(0)
	for index in range(3):
		failed_state = rules.set_turbine_yaw(failed_state, index, 2)["state"]
		failed_state = rules.set_turbine_pitch(failed_state, index, 3)["state"]
	var failed_result: Dictionary = rules.resolve_round(failed_state)
	_expect(bool(failed_result.get("ok", false)), "underpowered round still resolves into a recorded outcome")
	if bool(failed_result.get("ok", false)):
		_expect(str(failed_result["state"]["status"]) == "failed", "uncovered demand causes an array failure")
		_expect(int(failed_result["report"]["unmet"]) > 0, "failure records the unmet grid demand")
		_expect(int(failed_result["state"]["battery"]) == 0, "battery reserve is exhausted on an uncovered shortfall")

func _test_heat_trip(rules: RefCounted) -> void:
	var state: Dictionary = rules.make_state(0)
	for index in range(3):
		state = rules.set_turbine_yaw(state, index, 0)["state"]
		state = rules.set_turbine_pitch(state, index, 0)["state"]
	for _round in range(3):
		var result: Dictionary = rules.resolve_round(state)
		_expect(bool(result.get("ok", false)), "aggressive-pitch heat test round resolves")
		if not bool(result.get("ok", false)):
			return
		state = result["state"]
	var turbines: Array = state["turbines"]
	_expect(not bool(turbines[0]["online"]), "turbine trips when accumulated heat reaches the safety threshold")
	_expect(int(turbines[0]["heat"]) == Rules.TRIP_HEAT, "heat is clamped to the trip threshold and state remains valid")
	_expect(rules.get_estimated_outputs(state)[0] == 0, "tripped turbine contributes no output in the next round")

func _test_all_arrays_can_be_completed(rules: RefCounted) -> void:
	var state: Dictionary = rules.make_state(0)
	for scenario_index in range(rules.get_scenario_count()):
		if scenario_index > 0:
			var advance: Dictionary = rules.advance_scenario(state)
			_expect(bool(advance.get("ok", false)), "completed array unlocks the next array")
			if not bool(advance.get("ok", false)):
				return
			state = advance["state"]
		while str(state["status"]) == "playing":
			var weather: Dictionary = rules.get_current_weather(state)
			for turbine_index in range(3):
				state = rules.set_turbine_yaw(state, turbine_index, int(weather["wind_direction"]))["state"]
				state = rules.set_turbine_pitch(state, turbine_index, 2)["state"]
			var result: Dictionary = rules.resolve_round(state)
			_expect(bool(result.get("ok", false)), "deterministic dispatch strategy resolves every scheduled round")
			if not bool(result.get("ok", false)):
				return
			state = result["state"]
			_expect(str(state["status"]) != "failed", "aligned pitch-two dispatch serves the scheduled grid demand")
		_expect(str(state["status"]) == "won", "each four-round wind array can be completed")
	_expect(str(state["status"]) == "won", "third array completes before campaign closeout")
	var final_advance: Dictionary = rules.advance_scenario(state)
	_expect(bool(final_advance.get("ok", false)), "final array can be closed out")
	if bool(final_advance.get("ok", false)):
		_expect(str(final_advance["state"]["status"]) == "campaign_complete", "three successful arrays complete the campaign")
	var reset_state: Dictionary = rules.reset_state(state)
	_expect(int(reset_state["round_index"]) == 0 and int(reset_state["battery"]) == Rules.INITIAL_BATTERY, "reset restores the current array's initial state")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
