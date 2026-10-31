extends SceneTree

const Rules = preload("res://rules.gd")
const SOLUTIONS: Array = [
	["right", "right", "down", "down", "right", "right", "down", "down", "right", "right", "down", "down"],
	["right", "right", "down", "down", "down", "right", "right", "down", "right", "right", "down", "down"],
	["down", "down", "right", "right", "left", "left", "up", "up", "right", "right", "right", "right", "down", "down", "down", "down", "right", "right", "down", "down"]
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var initial: Dictionary = Rules.new_game(0)
	_expect(str(initial.get("level_id", "")) == "dockside_echo", "first mission loads the authored dockside echo map")
	_expect(not Rules.is_cell_visible(initial, Vector2i(7, 7)), "distant extraction hatch starts hidden")
	_expect(Rules.is_cell_visible(initial, Vector2i(1, 1)), "operator start is always visible")

	var ping_result: Dictionary = Rules.apply_action(initial, "ping")
	_expect(bool(ping_result.get("ok", false)), "sonar pulse is accepted")
	var ping_state: Dictionary = ping_result.get("state", {})
	_expect(int(ping_state.get("sonar_charges", -1)) == Rules.MAX_SONAR_CHARGES - 1, "sonar pulse consumes exactly one charge")
	_expect(int(ping_state.get("turns", -1)) == 1, "sonar pulse consumes one turn")
	_expect(Rules.is_cell_visible(ping_state, Vector2i(4, 1)), "sonar reveals a nearby wall")
	_expect(not Rules.is_cell_visible(ping_state, Vector2i(7, 7)), "sonar does not reveal cells outside its Manhattan radius")

	var blocked: Dictionary = Rules.apply_action(initial, "left")
	_expect(bool(blocked.get("ok", false)) and str(blocked.get("reason", "")) == "blocked", "unknown wall contact returns a useful blocked result")
	_expect(blocked.get("state", {}).get("player") == Vector2i(1, 1), "blocked movement leaves the operator in place")
	_expect(int(blocked.get("state", {}).get("turns", -1)) == 1, "wall contact consumes one exploration turn")

	var no_charge: Dictionary = Rules.new_game(0)
	no_charge["sonar_charges"] = 0
	var rejected_ping: Dictionary = Rules.apply_action(no_charge, "ping")
	_expect(not bool(rejected_ping.get("ok", false)) and str(rejected_ping.get("reason", "")) == "no_sonar_charge", "sonar cannot be used after all charges are spent")
	_expect(int(rejected_ping.get("state", {}).get("turns", -1)) == 0, "rejected sonar use does not consume a turn")

	var invalid: Dictionary = Rules.apply_action(initial, "teleport")
	_expect(not bool(invalid.get("ok", false)) and str(invalid.get("reason", "")) == "invalid_action", "unknown movement action is rejected")

	for level_index in range(Rules.get_level_count()):
		var state: Dictionary = Rules.new_game(level_index)
		var scan: Dictionary = Rules.apply_action(state, "ping")
		_expect(bool(scan.get("ok", false)), "mission %d accepts an initial sonar scan" % (level_index + 1))
		state = scan.get("state", state)
		for action in SOLUTIONS[level_index]:
			var result: Dictionary = Rules.apply_action(state, str(action))
			_expect(bool(result.get("ok", false)), "mission %d accepts route action %s" % [level_index + 1, str(action)])
			if not bool(result.get("ok", false)):
				break
			state = result.get("state", state)
		_expect(str(state.get("status", "")) == "won", "mission %d has a verified route to all beacons and extraction" % (level_index + 1))
		_expect(state.get("player") == state.get("exit"), "mission %d ends at the extraction hatch" % (level_index + 1))
		_expect(state.get("collected", []).size() == state.get("beacons", []).size(), "mission %d recovers every signal beacon" % (level_index + 1))
		_expect(int(state.get("turns", Rules.MAX_TURNS + 1)) <= Rules.MAX_TURNS, "mission %d fits the exploration turn budget" % (level_index + 1))

	var terminal: Dictionary = Rules.new_game(0)
	terminal["status"] = "won"
	var terminal_action: Dictionary = Rules.apply_action(terminal, "ping")
	_expect(not bool(terminal_action.get("ok", false)) and str(terminal_action.get("reason", "")) == "terminal", "completed mission rejects additional actions")

	if failures.is_empty():
		print("KROLL Echo Mapper rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
