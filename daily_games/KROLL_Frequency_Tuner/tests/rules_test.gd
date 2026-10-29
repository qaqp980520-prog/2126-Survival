extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for seed_value in Rules.SEEDS:
		var state: Dictionary = Rules.new_game(seed_value)
		var duplicate: Dictionary = Rules.new_game(seed_value)
		_expect(state == duplicate, "seed %d creates a deterministic state" % seed_value)
		_expect(Rules.output_values(state["target_frequencies"]) == state["target_outputs"], "seed %d target outputs match its target dials" % seed_value)
		_solve_layout(state)
	_expect(Rules.next_seed(13) == 27 and Rules.next_seed(41) == 13, "layout cycling wraps deterministically")

	var seen_outputs: Dictionary = {}
	var mapping_is_unique: bool = true
	for x in range(10):
		for y in range(10):
			for z in range(10):
				var output: Array[int] = Rules.output_values([x, y, z])
				var output_key: String = "%d-%d-%d" % [output[0], output[1], output[2]]
				if seen_outputs.has(output_key):
					mapping_is_unique = false
				seen_outputs[output_key] = true
	_expect(mapping_is_unique and seen_outputs.size() == 1000, "modulo-10 signal transform maps all 1000 dial states uniquely")

	var invalid_state: Dictionary = Rules.new_game(13)
	var before: Dictionary = invalid_state.duplicate(true)
	var invalid_dial: Dictionary = Rules.tune(invalid_state, 3, 1)
	_expect(not bool(invalid_dial["ok"]) and invalid_dial["reason"] == "invalid_dial", "out-of-range dial is rejected")
	_expect(invalid_dial["state"] == before, "invalid dial leaves state unchanged")
	var invalid_delta: Dictionary = Rules.tune(invalid_state, 0, 2)
	_expect(not bool(invalid_delta["ok"]) and invalid_delta["state"] == before, "multi-step delta is rejected without mutation")

	var exhausted: Dictionary = Rules.new_game(13)
	for i in range(Rules.MOVE_LIMIT):
		var result: Dictionary = Rules.tune(exhausted, 0, 1)
		_expect(bool(result["ok"]), "legal tuning move %d is accepted" % (i + 1))
		exhausted = result["state"]
	_expect(str(exhausted["status"]) == "failed", "unmatched outputs fail when the move budget is exhausted")
	var terminal_before: Dictionary = exhausted.duplicate(true)
	var terminal_result: Dictionary = Rules.tune(exhausted, 1, -1)
	_expect(not bool(terminal_result["ok"]) and terminal_result["reason"] == "terminal", "terminal state rejects further tuning")
	_expect(terminal_result["state"] == terminal_before, "terminal rejection leaves state unchanged")

	if failures.is_empty():
		print("KROLL Frequency Tuner rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _solve_layout(start_state: Dictionary) -> void:
	var state: Dictionary = start_state.duplicate(true)
	var target_frequencies: Array = state["target_frequencies"]
	for dial in range(3):
		var forward_steps: int = posmod(int(target_frequencies[dial]) - int(state["frequencies"][dial]), 10)
		var delta: int = 1
		if forward_steps > 5:
			forward_steps = 10 - forward_steps
			delta = -1
		for step in range(forward_steps):
			var result: Dictionary = Rules.tune(state, dial, delta)
			_expect(bool(result["ok"]), "seed %d accepts legal step on dial %d" % [int(state["seed"]), dial + 1])
			state = result["state"]
	_expect(str(state["status"]) == "won", "seed %d reaches the exact output lock" % int(start_state["seed"]))
	_expect(int(state["moves"]) <= Rules.MOVE_LIMIT, "seed %d is solvable within the move budget" % int(start_state["seed"]))

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
