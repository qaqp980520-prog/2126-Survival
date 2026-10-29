extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.new_game(101) == Rules.new_game(101), "same seed creates the same shift")
	_expect(Rules.new_game(101)["temperatures"].size() == 12, "each shift contains twelve canisters")
	_expect(Rules.expected_bin(-10) == "cold", "minus ten Celsius is cold")
	_expect(Rules.expected_bin(-9) == "stable", "minus nine Celsius is stable")
	_expect(Rules.expected_bin(9) == "stable", "nine Celsius is stable")
	_expect(Rules.expected_bin(10) == "hot", "ten Celsius is hot")

	var initial: Dictionary = Rules.new_game(101)
	var invalid: Dictionary = Rules.route(initial, "ambient")
	_expect(not bool(invalid["ok"]) and invalid["reason"] == "invalid_bin", "unknown bins are rejected")
	_expect(int(initial["index"]) == 0 and int(initial["mistakes"]) == 0, "invalid routing leaves source state unchanged")

	for seed_value in Rules.SEEDS:
		var state: Dictionary = Rules.new_game(seed_value)
		var temperatures: Array = state["temperatures"]
		for temperature in temperatures:
			state = _apply(state, Rules.route(state, Rules.expected_bin(int(temperature))))
		_expect(str(state["status"]) == "won", "seed %d can be sorted without errors" % seed_value)
		_expect(int(state["correct"]) == 12 and int(state["mistakes"]) == 0, "seed %d counts all twelve correct routes" % seed_value)

	var failure: Dictionary = Rules.new_game(101)
	for attempt in range(3):
		var current_temp: int = int(failure["temperatures"][int(failure["index"])])
		var expected: String = Rules.expected_bin(current_temp)
		var wrong: String = "cold" if expected != "cold" else "stable"
		failure = _apply(failure, Rules.route(failure, wrong))
	_expect(str(failure["status"]) == "failed" and int(failure["mistakes"]) == 3, "third routing error ends the shift")

	var terminal: Dictionary = Rules.route(failure, "hot")
	_expect(not bool(terminal["ok"]) and terminal["reason"] == "terminal", "terminal shifts reject more actions")

	if failures.is_empty():
		print("KROLL Thermal Sort rules tests passed.")
		quit(0)
	else:
		for failure_message in failures:
			push_error("FAIL: " + failure_message)
		quit(1)

func _apply(state: Dictionary, result: Dictionary) -> Dictionary:
	_expect(bool(result.get("ok", false)), "expected route to succeed, got %s" % str(result.get("reason", "")))
	return result.get("state", state)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
