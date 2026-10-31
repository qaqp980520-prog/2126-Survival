extends SceneTree
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.LEVELS.size() == 3, "three authored weather stations are available")
	for level_index in range(Rules.LEVELS.size()):
		_expect(Rules.is_valid_level(level_index), "station %d has valid bounds and a solvable action budget" % level_index)
		_expect(Rules.required_actions(level_index) <= int(Rules.get_level(level_index).get("budget", 0)), "station %d can be solved within its budget" % level_index)
	var state: Dictionary = Rules.new_game(0)
	_expect(str(state.get("level_id", "")) == "coastal_front", "first station starts at Coastal Front")
	_expect(int(state.get("actions_left", -1)) == 14, "station begins with fourteen actions")
	var unchanged: Dictionary = Rules.adjust(state, "temperature", 0)
	_expect(int(unchanged.get("actions_used", -1)) == 0, "invalid adjustment direction costs no action")
	unchanged = Rules.adjust(state, "unknown", 1)
	_expect(int(unchanged.get("actions_used", -1)) == 0, "unknown instrument costs no action")
	var solved_states: Array[Dictionary] = []
	for level_index in range(Rules.LEVELS.size()):
		var level: Dictionary = Rules.get_level(level_index)
		var route: Dictionary = Rules.new_game(level_index)
		for instrument in Rules.INSTRUMENTS:
			var current: int = int(route["readings"][instrument])
			var desired: int = int(level["target"][instrument])
			var direction: int = 1 if desired > current else -1
			while current != desired:
				route = Rules.adjust(route, instrument, direction)
				current = int(route["readings"][instrument])
		var assessment: Dictionary = Rules.evaluate(route)
		_expect(str(route.get("status", "")) == "complete", "station %d reaches a stable forecast" % level_index)
		_expect(bool(assessment.get("complete", false)) and bool(assessment.get("stable", false)), "station %d ends below its storm threshold" % level_index)
		_expect(int(route.get("actions_left", 0)) == int(level["budget"]) - Rules.required_actions(level_index), "station %d spends exactly the required actions" % level_index)
		solved_states.append(route)
	var next: Dictionary = Rules.next_level(solved_states[0])
	_expect(int(next.get("level_index", -1)) == 1, "completed Coastal Front unlocks Desert Thermal")
	var blocked: Dictionary = Rules.next_level(Rules.new_game(0))
	_expect(int(blocked.get("level_index", -1)) == 0, "unfinished station cannot be skipped")
	var reset: Dictionary = Rules.reset(solved_states[1])
	_expect(int(reset.get("level_index", -1)) == 1 and int(reset.get("actions_used", -1)) == 0, "reset restarts the current station")
	var failed: Dictionary = Rules.new_game(0)
	for index in range(14):
		failed = Rules.adjust(failed, "temperature", 1 if index % 2 == 0 else -1)
	_expect(str(failed.get("status", "")) == "failed", "exhausting the action budget without matching the forecast fails the station")
	var locked: Dictionary = Rules.adjust(failed, "humidity", 1)
	_expect(int(locked.get("actions_used", -1)) == int(failed.get("actions_used", -2)), "failed station rejects further adjustments")
	_expect(Rules.storm_load({"humidity": 60, "wind": 30, "pressure": 1010, "temperature": 20}) <= 25, "target coastal weather remains under the storm limit")
	if failures.is_empty():
		print("KROLL Atmosphere Lab rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
