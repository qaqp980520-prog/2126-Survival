extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.new_game(7) == Rules.new_game(7), "same seed produces the same state")
	_expect(Rules.new_game(7)["levels"] == [1, 0, 2, 1], "seed 7 uses the documented water levels")

	var initial: Dictionary = Rules.new_game(7)
	var blocked: Dictionary = Rules.move_boat(initial, 1)
	_expect(not bool(blocked["ok"]) and blocked["reason"] == "gate_closed", "closed gate blocks movement")
	_expect(int(initial["turns"]) == 0 and int(initial["position"]) == 0, "invalid action leaves source state unchanged")

	var state: Dictionary = initial
	state = _apply(state, Rules.toggle_gate(state))
	state = _apply(state, Rules.move_boat(state, 1))
	var pressure_block: Dictionary = Rules.move_boat(state, 1)
	_expect(not bool(pressure_block["ok"]) and pressure_block["reason"] == "gate_closed", "second gate remains independently closed")
	state = _apply(state, Rules.toggle_gate(state))
	var mismatch: Dictionary = Rules.move_boat(state, 1)
	_expect(not bool(mismatch["ok"]) and mismatch["reason"] == "pressure_mismatch", "unsafe water-level difference blocks transit")
	_expect(int(state["turns"]) == 3 and int(state["position"]) == 1, "pressure rejection consumes no turn")

	state = _apply(state, Rules.pump(state, 1))
	state = _apply(state, Rules.move_boat(state, 1))
	_expect(int(state["position"]) == 2, "equalized chamber allows safe transit")
	_expect(int(state["pump_energy"]) == 2, "pumping consumes one energy unit")

	var boundary: Dictionary = Rules.new_game(7)
	var low: Dictionary = Rules.pump(boundary, -1)
	_expect(not bool(low["ok"]) and low["reason"] == "level_limit", "water level cannot go below zero")
	_expect(int(boundary["pump_energy"]) == Rules.MAX_PUMP_ENERGY, "rejected pump does not consume energy")

	for seed_value in Rules.SEEDS:
		var solved: Dictionary = _solve(seed_value)
		_expect(str(solved["status"]) == "won", "layout %d has a valid route within the action budget" % seed_value)
		_expect(int(solved["turns"]) <= Rules.MAX_TURNS, "layout %d completes within ten actions" % seed_value)

	var terminal: Dictionary = Rules.new_game(7)
	terminal["status"] = "won"
	var locked: Dictionary = Rules.toggle_gate(terminal)
	_expect(not bool(locked["ok"]) and locked["reason"] == "terminal", "terminal state rejects further actions")

	if failures.is_empty():
		print("KROLL Tidal Lock rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _solve(seed_value: int) -> Dictionary:
	var state: Dictionary = Rules.new_game(seed_value)
	while str(state["status"]) == "playing" and int(state["position"]) < Rules.CHAMBER_COUNT - 1:
		var position: int = int(state["position"])
		state = _apply(state, Rules.toggle_gate(state))
		var levels: Array = state["levels"]
		while absi(int(levels[position]) - int(levels[position + 1])) > 1:
			var delta: int = 1 if int(levels[position]) < int(levels[position + 1]) else -1
			var result: Dictionary = Rules.pump(state, delta)
			if not bool(result["ok"]):
				return state
			state = result["state"]
			levels = state["levels"]
		var moved: Dictionary = Rules.move_boat(state, 1)
		if not bool(moved["ok"]):
			return state
		state = moved["state"]
	return state

func _apply(state: Dictionary, result: Dictionary) -> Dictionary:
	_expect(bool(result.get("ok", false)), "expected action to succeed, got %s" % str(result.get("reason", "")))
	return result.get("state", state)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
