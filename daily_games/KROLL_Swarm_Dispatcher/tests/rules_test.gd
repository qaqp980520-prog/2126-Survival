extends SceneTree

const RulesScript = preload("res://rules.gd")
const PLANS: Array = [
	[
		["down", "down", "down", "down", "down", "right", "right", "right", "right", "right"],
		["down", "down", "down", "down", "left", "left", "left", "down", "left", "left"],
		["up", "up", "right", "up", "up", "up", "right", "right", "right", "right"]
	],
	[
		["down", "down", "down", "right", "right", "right", "up", "up", "up", "right", "right"],
		["down", "down", "down", "down", "down", "left", "left", "left", "left", "left", "wait"],
		["up", "up", "down", "up", "down", "up", "down", "right", "down", "right", "right"]
	],
	[
		["up", "right", "right", "right", "right", "up", "right", "up", "up", "up"],
		["up", "up", "up", "up", "up", "left", "left", "left", "left", "left"],
		["down", "left", "left", "down", "down", "down", "down", "right", "right", "wait"]
	]
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_invalid_inputs_and_copy_isolation()
	_test_same_target_collision()
	_test_head_on_swap()
	_test_obstacle_rejects_whole_tick()
	_test_program_limit()
	_test_all_missions_and_campaign_score()
	if failures.is_empty():
		print("KROLL Swarm Dispatcher rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_invalid_inputs_and_copy_isolation() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	var invalid_action: Dictionary = rules.append_action(state, 0, "teleport")
	_expect(not bool(invalid_action.get("ok", true)) and str(invalid_action.get("reason", "")) == "invalid_action", "unknown commands are rejected")
	var invalid_drone: Dictionary = rules.append_action(state, 3, "wait")
	_expect(not bool(invalid_drone.get("ok", true)) and str(invalid_drone.get("reason", "")) == "invalid_drone", "unknown drone indexes are rejected")
	var appended: Dictionary = rules.append_action(state, 0, "right")
	_expect(bool(appended.get("ok", false)), "valid route commands can be appended")
	var original_program: Array = state["programs"][0]
	_expect(original_program.is_empty(), "appending a command does not mutate the caller's prior state")

func _test_same_target_collision() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	state["positions"] = [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 6)]
	state["programs"] = [["right"], ["left"], []]
	var result: Dictionary = rules.step_tick(state)
	_expect(not bool(result.get("ok", true)) and str(result.get("reason", "")) == "collision_same_target", "two drones cannot reserve the same destination in one tick")
	_expect(state["positions"] == [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 6)], "a rejected collision leaves every drone at its previous position")

func _test_head_on_swap() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	state["positions"] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(6, 6)]
	state["programs"] = [["right"], ["left"], []]
	var result: Dictionary = rules.step_tick(state)
	_expect(not bool(result.get("ok", true)) and str(result.get("reason", "")) == "head_on_swap", "head-on swaps are rejected even when destination cells differ")

func _test_obstacle_rejects_whole_tick() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	state["positions"] = [Vector2i(2, 3), Vector2i(6, 1), Vector2i(1, 6)]
	state["programs"] = [["right"], ["down"], []]
	var result: Dictionary = rules.step_tick(state)
	_expect(not bool(result.get("ok", true)) and str(result.get("reason", "")) == "blocked_by_obstacle", "a wall blocks the entire synchronized tick")
	_expect(state["positions"][1] == Vector2i(6, 1), "a valid move from another drone is not partially committed when one route is blocked")

func _test_program_limit() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	for _index in range(rules.get_max_commands()):
		var result: Dictionary = rules.append_action(state, 0, "wait")
		_expect(bool(result.get("ok", false)), "program accepts a command below the limit")
		state = result["state"]
	var overflow: Dictionary = rules.append_action(state, 0, "wait")
	_expect(not bool(overflow.get("ok", true)) and str(overflow.get("reason", "")) == "program_limit", "program length is capped at twenty-four commands per drone")

func _test_all_missions_and_campaign_score() -> void:
	var rules := RulesScript.new()
	var state: Dictionary = rules.create_state(0)
	_expect(rules.get_level_count() == 3, "three missions are available")
	for level_index in range(rules.get_level_count()):
		if level_index > 0:
			var advanced: Dictionary = rules.advance_level(state)
			_expect(bool(advanced.get("ok", false)), "campaign advances to mission %d" % (level_index + 1))
			state = advanced["state"]
		for drone_index in range(3):
			for action_value in PLANS[level_index][drone_index]:
				var appended: Dictionary = rules.append_action(state, drone_index, str(action_value))
				_expect(bool(appended.get("ok", false)), "mission %d accepts drone %d route command" % [level_index + 1, drone_index + 1])
				state = appended["state"]
		var execution: Dictionary = rules.run_all(state)
		_expect(bool(execution.get("ok", false)), "mission %d route program executes" % (level_index + 1))
		state = execution["state"]
		_expect(str(state.get("status", "")) == "passed", "all three drones dock in mission %d" % (level_index + 1))
		_expect(int(state.get("score", 0)) == 100, "mission %d awards exactly one hundred points" % (level_index + 1))
		if level_index == 2:
			var final: Dictionary = rules.advance_level(state)
			_expect(bool(final.get("ok", false)), "final mission completes the campaign")
			state = final["state"]
	_expect(str(state.get("status", "")) == "campaign_complete", "campaign reaches its terminal state")
	_expect(int(state.get("total_score", 0)) == 300, "campaign score accumulates exactly once per mission")
	var restarted: Dictionary = rules.restart_campaign()
	_expect(bool(restarted.get("ok", false)) and int(restarted.get("state", {}).get("campaign_score", -1)) == 0, "fresh campaign resets score")
	_expect(not bool(rules.step_tick(state).get("ok", true)), "completed campaign rejects further ticks")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
