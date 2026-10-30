extends SceneTree

const Rules = preload("res://rules.gd")
const SOLUTIONS: Array = [
	[[1, 1, 3], [1, 3, 1], [1, 3, 1], [2, 2, 1], [2, 2, 1], [3, 1, 1]],
	[[1, 1, 3], [1, 3, 1], [2, 2, 1], [2, 2, 1], [2, 2, 1], [3, 1, 1]],
	[[1, 1, 3], [1, 3, 1], [1, 3, 1], [2, 2, 1], [1, 3, 1], [3, 1, 1]]
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_scenario(0).size() > 0 and Rules.get_scenario(2).size() > 0, "three authored scenarios are available")
	_expect(Rules.get_scenario(-1).is_empty() and Rules.get_scenario(3).is_empty(), "invalid scenario indexes are rejected")
	for scenario_index in range(3):
		var state: Dictionary = Rules.new_state(scenario_index)
		_expect(not state.is_empty(), "scenario %d creates a fresh state" % scenario_index)
		for cycle in range(Rules.ROUND_COUNT):
			var desired: Array = SOLUTIONS[scenario_index][cycle]
			for sector in range(3):
				while int(state["crew"][sector]) > int(desired[sector]):
					var decrease: Dictionary = Rules.set_crew(state, sector, -1)
					_expect(bool(decrease.get("ok", false)), "crew can be reassigned downward")
					state = decrease["state"]
			for sector in range(3):
				while int(state["crew"][sector]) < int(desired[sector]):
					var increase: Dictionary = Rules.set_crew(state, sector, 1)
					_expect(bool(increase.get("ok", false)), "crew can be reassigned upward without exceeding the pool")
					state = increase["state"]
			var before: Dictionary = state.duplicate(true)
			var result: Dictionary = Rules.advance(state)
			_expect(bool(result.get("ok", false)), "scenario %d cycle %d accepts a complete crew assignment" % [scenario_index, cycle + 1])
			_expect(int(state.get("round", -1)) == int(before.get("round", -2)), "advancing is non-mutating to the input snapshot")
			state = result["state"]
			_expect(int(state.get("energy", 0)) > 0 and int(state.get("oxygen", 0)) > 0 and int(state.get("hull", 0)) > 0, "scenario %d keeps all critical systems online" % scenario_index)
		_expect(str(state.get("status", "")) == "won", "scenario %d has a validated six-cycle winning allocation" % scenario_index)
		_expect(int(state.get("energy", 0)) >= 5 and int(state.get("oxygen", 0)) >= 5 and int(state.get("hull", 0)) >= 30, "scenario %d finishes above all reserve targets" % scenario_index)

	var invalid_state: Dictionary = Rules.new_state(0)
	invalid_state["crew"] = [1, 1, 1]
	var invalid_result: Dictionary = Rules.advance(invalid_state)
	_expect(not bool(invalid_result.get("ok", false)) and str(invalid_result.get("reason", "")) == "crew_must_total_five", "incomplete crew assignment cannot run a cycle")
	var min_crew_state: Dictionary = Rules.new_state(0)
	var min_result: Dictionary = Rules.set_crew(min_crew_state, 0, -1)
	_expect(not bool(min_result.get("ok", false)), "a station cannot be left without a crew member")
	var invalid_delta: Dictionary = Rules.set_crew(min_crew_state, 0, 0)
	_expect(not bool(invalid_delta.get("ok", false)), "unsupported crew adjustment values are rejected")

	var failure_state: Dictionary = Rules.new_state(0)
	failure_state["energy"] = 1
	failure_state["crew"] = [1, 1, 3]
	var failure_result: Dictionary = Rules.advance(failure_state)
	_expect(bool(failure_result.get("ok", false)) and str(failure_result["state"].get("status", "")) == "failed", "a critical reserve reaching zero ends the shift")
	_expect(int(failure_result["state"].get("energy", -1)) == 0, "critical energy reserve is clamped at zero")

	var malformed_assignment: Dictionary = Rules.new_state(0)
	malformed_assignment["crew"] = [1, "two", 2]
	var malformed_result: Dictionary = Rules.set_crew(malformed_assignment, 0, 1)
	_expect(not bool(malformed_result.get("ok", false)), "malformed crew state is rejected without indexing errors")

	var cap_state: Dictionary = Rules.new_state(0)
	cap_state["energy"] = 20
	cap_state["crew"] = [3, 1, 1]
	var cap_result: Dictionary = Rules.advance(cap_state)
	_expect(bool(cap_result.get("ok", false)) and int(cap_result["state"].get("energy", -1)) <= Rules.ENERGY_CAP, "energy never exceeds the storage cap")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("KROLL Station Shift rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
