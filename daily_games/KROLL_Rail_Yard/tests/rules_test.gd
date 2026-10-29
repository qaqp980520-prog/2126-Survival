extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.new_game(1)
	_expect(first == Rules.new_game(1), "same seed creates identical yard state")
	_expect(first.get("incoming") == ["B", "A", "C", "D", "E"], "seed 1 layout is deterministic")
	_expect(Rules.new_game(2).get("incoming") == ["C", "A", "B", "D", "E"], "seed 2 layout is deterministic")
	_expect(Rules.new_game(3).get("incoming") == ["D", "B", "A", "C", "E"], "seed 3 layout is deterministic")

	var invalid_direct: Dictionary = Rules.apply_action(first, "direct")
	_expect(not bool(invalid_direct.get("ok", false)) and invalid_direct.get("reason") == "wrong_car", "wrong next car cannot enter output")
	_expect(first == invalid_direct.get("state", {}), "rejected action does not mutate source state")

	var capacity_state: Dictionary = Rules.new_game(3)
	for _index in range(Rules.SIDING_CAPACITY):
		var pushed: Dictionary = Rules.apply_action(capacity_state, "push")
		_expect(bool(pushed.get("ok", false)), "siding accepts cars up to capacity")
		capacity_state = pushed.get("state", capacity_state)
	var capacity_before: Dictionary = capacity_state.duplicate(true)
	var overflow: Dictionary = Rules.apply_action(capacity_state, "push")
	_expect(not bool(overflow.get("ok", false)) and overflow.get("reason") == "siding_full", "siding overflow is rejected")
	_expect(capacity_state == overflow.get("state", {}) and capacity_state == capacity_before, "siding overflow preserves all tracks")

	var plans: Array = [
		["push", "direct", "pop", "direct", "direct", "direct"],
		["push", "direct", "direct", "pop", "direct", "direct"],
		["push", "push", "direct", "pop", "direct", "pop", "direct"]
	]
	for layout_index in range(Rules.SEEDS.size()):
		var state: Dictionary = Rules.new_game(Rules.SEEDS[layout_index])
		for action_name in plans[layout_index]:
			var result: Dictionary = Rules.apply_action(state, str(action_name))
			_expect(bool(result.get("ok", false)), "seed %d accepts planned %s action" % [Rules.SEEDS[layout_index], str(action_name)])
			state = result.get("state", state)
		_expect(str(state.get("status", "")) == "won", "seed %d sorts all cars" % Rules.SEEDS[layout_index])
		_expect(state.get("output", []) == Rules.TARGET_ORDER, "seed %d output is A–E" % Rules.SEEDS[layout_index])
		_expect(state.get("incoming", []).is_empty() and state.get("siding", []).is_empty(), "seed %d leaves both input and siding empty" % Rules.SEEDS[layout_index])
		_expect(int(state.get("moves", 0)) <= Rules.MAX_MOVES, "seed %d stays inside move budget" % Rules.SEEDS[layout_index])

	var near_limit: Dictionary = Rules.new_game(1)
	near_limit["moves"] = Rules.MAX_MOVES - 1
	var final_move: Dictionary = Rules.apply_action(near_limit, "push")
	_expect(bool(final_move.get("ok", false)) and str(final_move.get("state", {}).get("status", "")) == "failed", "unfinished yard fails when move limit is reached")
	var terminal: Dictionary = Rules.apply_action(final_move.get("state", {}), "direct")
	_expect(not bool(terminal.get("ok", false)) and terminal.get("reason") == "terminal", "terminal yard rejects further actions")

	if failures.is_empty():
		print("KROLL Rail Yard rules tests passed.")
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
