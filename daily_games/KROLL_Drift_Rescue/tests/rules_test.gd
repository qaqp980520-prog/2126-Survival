extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_test_all_authored_rescue_routes()
	_test_momentum_and_braking()
	_test_collision_and_bounds()
	_test_fuel_and_turn_budget()
	_test_undo_and_reward_once()
	_test_campaign_completion()
	if failures.is_empty():
		print("KROLL Drift Rescue rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Drift Rescue rules failures: " + str(failures))
		quit(1)

func _test_all_authored_rescue_routes() -> void:
	var routes: Array[Array] = [
		["thrust_right","thrust_right","coast","thrust_left","thrust_left"],
		["thrust_up","coast","thrust_right","thrust_right","thrust_down","thrust_left","thrust_left"],
		["thrust_down","thrust_down","thrust_up","thrust_right","thrust_right","thrust_up","thrust_left","thrust_left"]
	]
	for level_index in range(Rules.level_count()):
		var state: Dictionary = _apply_route(Rules.new_state(level_index), routes[level_index])
		_expect(str(state.get("status", "")) == "completed", "authored route %d docks safely" % (level_index + 1))
		_expect(state.get("position", Vector2i.ZERO) == Rules.mission_at(level_index)["goal"], "authored route %d reaches its target" % (level_index + 1))
		_expect(state.get("velocity", Vector2i.ONE) == Vector2i.ZERO, "authored route %d brakes to zero velocity" % (level_index + 1))
		_expect(int(state.get("campaign_score", 0)) == 100, "authored route %d earns its one-time perfect award" % (level_index + 1))

func _test_momentum_and_braking() -> void:
	var state: Dictionary = Rules.new_state()
	state = _apply(state, "thrust_right")
	_expect(state.get("position") == Vector2i(2, 4) and state.get("velocity") == Vector2i(1, 0), "first thrust creates one cell of velocity")
	state = _apply(state, "thrust_right")
	_expect(state.get("position") == Vector2i(4, 4) and state.get("velocity") == Vector2i(2, 0), "second thrust accelerates to the speed cap")
	state = _apply(state, "coast")
	_expect(state.get("position") == Vector2i(6, 4) and state.get("velocity") == Vector2i(2, 0), "coasting preserves momentum without fuel cost")
	state = _apply(state, "thrust_left")
	_expect(state.get("position") == Vector2i(7, 4) and state.get("velocity") == Vector2i(1, 0), "counter-thrust reduces forward speed")
	state = _apply(state, "thrust_left")
	_expect(state.get("position") == Vector2i(7, 4) and state.get("velocity") == Vector2i.ZERO, "second counter-thrust stops the rescue craft")
	_expect(str(state.get("status", "")) == "completed", "zero-velocity arrival docks the craft")

func _test_collision_and_bounds() -> void:
	var state: Dictionary = Rules.new_state(1)
	state["position"] = Vector2i(3, 5)
	state["velocity"] = Vector2i(1, 0)
	var collision: Dictionary = Rules.perform_action(state, "thrust_right")
	_expect(bool(collision.get("accepted", false)), "collision is a resolved flight action")
	_expect(str(collision.get("reason", "")) == "collision", "intermediate debris cell is detected")
	_expect(str(collision.get("state", {}).get("status", "")) == "failed", "debris impact fails the mission")
	_expect(collision.get("state", {}).get("position") == Vector2i(3, 5), "impact does not move the craft through debris")

	state = Rules.new_state()
	state["position"] = Vector2i(8, 4)
	state["velocity"] = Vector2i(1, 0)
	var boundary: Dictionary = Rules.perform_action(state, "coast")
	_expect(str(boundary.get("reason", "")) == "out_of_bounds", "out-of-bounds flight is rejected safely")
	_expect(str(boundary.get("state", {}).get("status", "")) == "failed", "leaving the flight deck fails the mission")

func _test_fuel_and_turn_budget() -> void:
	var state: Dictionary = Rules.new_state()
	state["fuel"] = 0
	var before: Dictionary = state.duplicate(true)
	var empty: Dictionary = Rules.perform_action(state, "thrust_right")
	_expect(not bool(empty.get("accepted", false)), "empty fuel rejects thrust")
	_expect(empty.get("state", {}) == before, "rejected thrust leaves all state unchanged")
	var coast: Dictionary = Rules.perform_action(state, "coast")
	_expect(bool(coast.get("accepted", false)), "coasting remains available without fuel")

	state = Rules.new_state()
	state["max_turns"] = 1
	var exhausted: Dictionary = Rules.perform_action(state, "coast")
	_expect(str(exhausted.get("reason", "")) == "turn_limit", "turn budget fails an undocked craft")
	_expect(str(exhausted.get("state", {}).get("status", "")) == "failed", "turn-limit state is terminal")

func _test_undo_and_reward_once() -> void:
	var state: Dictionary = _apply(Rules.new_state(), "thrust_right")
	var undone: Dictionary = Rules.perform_action(state, "undo")
	state = undone.get("state", {})
	_expect(bool(undone.get("accepted", false)), "undo restores the previous flight step")
	_expect(state.get("position") == Vector2i(1, 4) and state.get("velocity") == Vector2i.ZERO, "undo restores position and velocity")
	_expect(int(state.get("fuel", -1)) == 6 and int(state.get("turns", -1)) == 0, "undo restores fuel and turn budget")

	var route := ["thrust_right","thrust_right","coast","thrust_left","thrust_left"]
	state = _apply_route(Rules.new_state(), route)
	state = Rules.restart_level(state)
	state = _apply_route(state, route)
	_expect(int(state.get("campaign_score", 0)) == 100, "replaying a completed mission cannot duplicate its reward")

func _test_campaign_completion() -> void:
	var routes: Array[Array] = [
		["thrust_right","thrust_right","coast","thrust_left","thrust_left"],
		["thrust_up","coast","thrust_right","thrust_right","thrust_down","thrust_left","thrust_left"],
		["thrust_down","thrust_down","thrust_up","thrust_right","thrust_right","thrust_up","thrust_left","thrust_left"]
	]
	var state: Dictionary = Rules.new_state()
	for level_index in range(Rules.level_count()):
		state = _apply_route(state, routes[level_index])
		if level_index < Rules.level_count() - 1:
			var next: Dictionary = Rules.advance(state)
			_expect(bool(next.get("accepted", false)), "next mission advances after docking")
			state = next.get("state", {})
	var complete: Dictionary = Rules.advance(state)
	_expect(str(complete.get("state", {}).get("status", "")) == "campaign_complete", "final mission closes the campaign")
	_expect(int(complete.get("state", {}).get("campaign_score", 0)) == 300, "campaign score is capped at 300")

func _apply_route(state: Dictionary, route: Array) -> Dictionary:
	for action in route:
		state = _apply(state, str(action))
	return state

func _apply(state: Dictionary, action: String) -> Dictionary:
	var result: Dictionary = Rules.perform_action(state, action)
	_expect(bool(result.get("accepted", false)), "action %s is accepted" % action)
	return result.get("state", state)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
