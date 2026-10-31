extends SceneTree

const Rules = preload("res://rules.gd")
const SOLUTIONS: Array = [
	["right", "right", "right", "up", "up", "up", "up", "right", "rotate_left"],
	["right", "right", "right", "rotate_left", "right", "down", "down", "down", "left", "down", "left", "left", "left"],
	["right", "up", "right", "right", "down", "right", "rotate_left", "rotate_left"]
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var initial: Dictionary = Rules.new_game(0)
	_expect(initial.get("player") == Vector2i(1, 5), "first layout creates the authored operator start")
	_expect(initial.get("crate") == Vector2i(2, 2), "first layout creates the authored core start")
	_expect(initial.get("gravity") == 2, "first layout starts with downward gravity")

	var blocked: Dictionary = Rules.apply_action(initial, "left")
	_expect(not bool(blocked.get("ok", false)) and str(blocked.get("reason", "")) == "blocked", "border wall blocks movement")
	_expect(int(initial.get("turns", -1)) == 0 and initial.get("player") == Vector2i(1, 5), "blocked movement leaves the source state unchanged")

	var rotated: Dictionary = Rules.apply_action(initial, "rotate_right")
	_expect(bool(rotated.get("ok", false)), "gravity rotation is accepted")
	_expect(int(rotated.get("state", {}).get("gravity", -1)) == 3, "clockwise rotation changes down gravity to left")
	_expect(rotated.get("state", {}).get("crate") == Vector2i(1, 2), "loose core settles deterministically along the new gravity vector")

	var push_state: Dictionary = initial.duplicate(true)
	push_state["player"] = Vector2i(1, 2)
	push_state["crate"] = Vector2i(2, 2)
	push_state["gravity"] = 1
	var blocked_push: Dictionary = Rules.apply_action(push_state, "right")
	_expect(not bool(blocked_push.get("ok", false)) and str(blocked_push.get("reason", "")) == "crate_blocked", "wall blocks an attempted core push")
	_expect(int(blocked_push.get("state", {}).get("turns", -1)) == int(push_state.get("turns", -2)), "blocked push consumes no turn")

	var invalid: Dictionary = Rules.apply_action(initial, "teleport")
	_expect(not bool(invalid.get("ok", false)) and str(invalid.get("reason", "")) == "invalid_action", "unknown action is rejected")

	for level_index in range(Rules.get_level_count()):
		var state: Dictionary = Rules.new_game(level_index)
		for action in SOLUTIONS[level_index]:
			var result: Dictionary = Rules.apply_action(state, str(action))
			_expect(bool(result.get("ok", false)), "level %d accepts solution action %s" % [level_index + 1, str(action)])
			if not bool(result.get("ok", false)):
				break
			state = result.get("state", state)
		_expect(str(state.get("status", "")) == "won", "level %d has a verified route to the pressure plate and exit" % (level_index + 1))
		_expect(state.get("crate") == state.get("plate"), "level %d ends with the core on its plate" % (level_index + 1))
		_expect(state.get("player") == state.get("exit"), "level %d ends with the operator at the exit" % (level_index + 1))
		_expect(int(state.get("turns", Rules.MAX_TURNS + 1)) <= Rules.MAX_TURNS, "level %d solution fits the turn budget" % (level_index + 1))

	var terminal: Dictionary = Rules.new_game(0)
	terminal["status"] = "won"
	var rejected: Dictionary = Rules.apply_action(terminal, "rotate_left")
	_expect(not bool(rejected.get("ok", false)) and str(rejected.get("reason", "")) == "terminal", "terminal state rejects further actions")

	if failures.is_empty():
		print("KROLL Gravity Foundry rules tests passed.")
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
