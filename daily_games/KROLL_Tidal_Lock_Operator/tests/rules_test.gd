extends SceneTree

const Rules = preload("res://rules.gd")
const ACTIONS: Array[String] = ["pump_up", "pump_down", "toggle_lower_gate", "toggle_upper_gate", "move_ship"]

var failures: Array[String] = []

func _initialize() -> void:
	_test_three_authored_solutions()
	_test_gate_interlocks_and_level_matching()
	_test_water_bounds_and_ship_movement()
	_test_action_budget_and_terminal_state()
	_test_unique_shortest_solutions()
	if failures.is_empty():
		print("KROLL Tidal Lock Operator rules tests passed.")
		quit(0)
	else:
		push_error("Tidal Lock rules failures: " + str(failures))
		quit(1)

func _test_three_authored_solutions() -> void:
	var solutions: Array = [
		["toggle_lower_gate", "move_ship", "toggle_lower_gate", "pump_up", "pump_up", "toggle_upper_gate", "move_ship"],
		["pump_up", "pump_up", "toggle_lower_gate", "move_ship", "toggle_lower_gate", "pump_down", "pump_down", "pump_down", "toggle_upper_gate", "move_ship"],
		["pump_down", "pump_down", "pump_down", "toggle_lower_gate", "move_ship", "toggle_lower_gate", "pump_up", "pump_up", "pump_up", "pump_up", "pump_up", "toggle_upper_gate", "move_ship"]
	]
	for index in range(solutions.size()):
		var state: Dictionary = _play_sequence(index, solutions[index])
		_expect(str(state["status"]) == "won", "authored lock " + str(index + 1) + " reaches the upper basin")
		_expect(str(state["ship_position"]) == "upper", "authored lock " + str(index + 1) + " finishes with ship in upper basin")
		_expect(int(state["actions"]) == int(Rules.get_level(index)["par_actions"]), "authored lock " + str(index + 1) + " matches par")
		_expect(Rules.reward_for_clear(state) == 100, "authored lock " + str(index + 1) + " earns full reward")

func _test_gate_interlocks_and_level_matching() -> void:
	var state: Dictionary = Rules.new_state(0)
	var rejected_upper: Dictionary = Rules.perform_action(state, "toggle_upper_gate")
	_expect(not bool(rejected_upper["accepted"]), "upper gate rejects mismatched chamber level")
	_expect(int(rejected_upper["state"]["actions"]) == 0, "rejected gate action consumes no action")
	_expect(not bool(rejected_upper["state"]["upper_gate_open"]), "rejected upper gate remains closed")

	var opened_lower: Dictionary = Rules.perform_action(state, "toggle_lower_gate")
	_expect(bool(opened_lower["accepted"]), "matching lower gate opens")
	state = opened_lower["state"]
	var pump_while_open: Dictionary = Rules.perform_action(state, "pump_up")
	_expect(not bool(pump_while_open["accepted"]), "pumping is blocked while a gate is open")
	_expect(int(pump_while_open["state"]["actions"]) == int(state["actions"]), "blocked pump consumes no action")
	var second_gate: Dictionary = Rules.perform_action(state, "toggle_upper_gate")
	_expect(not bool(second_gate["accepted"]), "both gates cannot be opened simultaneously")
	_expect(not bool(second_gate["state"]["upper_gate_open"]), "upper gate remains closed while lower gate is open")

func _test_water_bounds_and_ship_movement() -> void:
	var state: Dictionary = Rules.new_state(2)
	var closed_move: Dictionary = Rules.perform_action(state, "move_ship")
	_expect(not bool(closed_move["accepted"]), "ship cannot move through a closed gate")
	for step in range(3):
		var down: Dictionary = Rules.perform_action(state, "pump_down")
		_expect(bool(down["accepted"]), "chamber drains within water bounds")
		state = down["state"]
	var underflow: Dictionary = Rules.perform_action(state, "pump_down")
	_expect(not bool(underflow["accepted"]), "chamber cannot drain below zero")
	_expect(int(underflow["state"]["chamber_level"]) == 0, "underflow leaves chamber at zero")
	_expect(int(underflow["state"]["actions"]) == int(state["actions"]), "underflow consumes no action")

	var max_state: Dictionary = Rules.new_state(0)
	for step in range(4):
		var up: Dictionary = Rules.perform_action(max_state, "pump_up")
		_expect(bool(up["accepted"]), "chamber fills within water bounds")
		max_state = up["state"]
	var overflow: Dictionary = Rules.perform_action(max_state, "pump_up")
	_expect(not bool(overflow["accepted"]), "chamber cannot fill above maximum")
	_expect(int(overflow["state"]["chamber_level"]) == Rules.MAX_WATER_LEVEL, "overflow leaves chamber at maximum")

func _test_action_budget_and_terminal_state() -> void:
	var state: Dictionary = Rules.new_state(0)
	for step in range(11):
		var action: String = "pump_down" if step % 2 == 0 else "pump_up"
		var result: Dictionary = Rules.perform_action(state, action)
		_expect(bool(result["accepted"]), "budget probe action " + str(step + 1) + " is accepted")
		state = result["state"]
	_expect(str(state["status"]) == "failed", "action budget failure is terminal")
	var after_failure: Dictionary = Rules.perform_action(state, "pump_up")
	_expect(not bool(after_failure["accepted"]), "failed lock rejects further actions")
	_expect(int(after_failure["state"]["actions"]) == int(state["actions"]), "terminal rejection does not change action count")

func _test_unique_shortest_solutions() -> void:
	for index in range(Rules.level_count()):
		var result: Dictionary = _shortest_solution(index)
		_expect(int(result["distance"]) == int(Rules.get_level(index)["par_actions"]), "lock " + str(index + 1) + " par equals shortest solution")
		_expect(int(result["ways"]) == 1, "lock " + str(index + 1) + " has exactly one shortest solution")

func _play_sequence(index: int, actions: Array) -> Dictionary:
	var state: Dictionary = Rules.new_state(index)
	for action in actions:
		var result: Dictionary = Rules.perform_action(state, str(action))
		_expect(bool(result["accepted"]), "lock " + str(index + 1) + " accepts " + str(action))
		state = result["state"]
	return state

func _shortest_solution(index: int) -> Dictionary:
	var start: Dictionary = Rules.new_state(index)
	var queue: Array[Dictionary] = []
	queue.append(start)
	var start_key: String = _state_key(start)
	var distances: Dictionary = {}
	distances[start_key] = 0
	var ways: Dictionary = {}
	ways[start_key] = 1
	var cursor: int = 0
	var best_distance: int = -1
	var solution_count: int = 0

	while cursor < queue.size():
		var current: Dictionary = queue[cursor]
		cursor += 1
		var key: String = _state_key(current)
		var distance: int = int(distances[key])
		if best_distance >= 0 and distance > best_distance:
			break
		if str(current["status"]) == "won":
			if best_distance < 0:
				best_distance = distance
			if distance == best_distance:
				solution_count += int(ways[key])
			continue
		for action in ACTIONS:
			var result: Dictionary = Rules.perform_action(current, action)
			if not bool(result["accepted"]):
				continue
			var next_state: Dictionary = result["state"]
			if str(next_state["status"]) == "failed":
				continue
			var next_key: String = _state_key(next_state)
			if not distances.has(next_key):
				distances[next_key] = distance + 1
				ways[next_key] = int(ways[key])
				queue.append(next_state)
			elif int(distances[next_key]) == distance + 1:
				ways[next_key] = int(ways[next_key]) + int(ways[key])
	return {"distance": best_distance, "ways": solution_count}

func _state_key(state: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [
		str(state["chamber_level"]),
		str(state["ship_position"]),
		str(state["lower_gate_open"]),
		str(state["upper_gate_open"]),
		str(state["status"])
	]

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
