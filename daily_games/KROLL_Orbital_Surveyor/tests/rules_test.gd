extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_boundaries_and_obstacles()
	_test_rough_terrain_cost()
	_test_scan_rules()
	_test_all_missions_and_one_time_rewards()
	_test_battery_depletion()
	if failures.is_empty():
		print("KROLL Orbital Surveyor rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Orbital Surveyor rules test failures: " + str(failures))
		quit(1)

func _test_boundaries_and_obstacles() -> void:
	var state: Dictionary = Rules.new_state()
	var initial_battery: int = int(state["mission_state"]["battery"])
	var outside: Dictionary = Rules.perform_action(state, "move_left")
	_expect(not bool(outside["accepted"]), "rover cannot leave the west map boundary")
	_expect(int(outside["state"]["mission_state"]["battery"]) == initial_battery, "rejected boundary move costs no battery")
	state = Rules.perform_action(state, "move_right")["state"]
	var blocked: Dictionary = Rules.perform_action(state, "move_down")
	_expect(not bool(blocked["accepted"]), "rock tile blocks movement")
	_expect(int(blocked["state"]["mission_state"]["battery"]) == int(state["mission_state"]["battery"]), "blocked move costs no battery")

func _test_rough_terrain_cost() -> void:
	var state: Dictionary = Rules.new_state()
	var route: Array[String] = ["move_down","move_down","move_right","move_right","move_right","scan","move_down"]
	for action in route:
		var result: Dictionary = Rules.perform_action(state, action)
		_expect(bool(result["accepted"]), "approach rough terrain: " + action)
		state = result["state"]
	var mission_state: Dictionary = state["mission_state"]
	_expect(int(mission_state["x"]) == 3 and int(mission_state["y"]) == 3, "rover enters the rough terrain tile")
	_expect(int(mission_state["battery"]) == 17, "rough terrain consumes two battery units")

func _test_scan_rules() -> void:
	var state: Dictionary = Rules.new_state()
	var base_scan: Dictionary = Rules.perform_action(state, "scan")
	_expect(not bool(base_scan["accepted"]), "scan is rejected away from a beacon")
	var route: Array[String] = ["move_down","move_down","move_right","move_right","move_right"]
	for action in route:
		state = Rules.perform_action(state, action)["state"]
	var before: int = int(state["mission_state"]["battery"])
	var scanned: Dictionary = Rules.perform_action(state, "scan")
	_expect(bool(scanned["accepted"]), "beacon scan succeeds at the correct tile")
	state = scanned["state"]
	_expect(bool(state["mission_state"]["scanned"]["A"]), "scan marks beacon A as recorded")
	_expect(int(state["mission_state"]["battery"]) == before - 1, "scan consumes one battery unit")
	var duplicate: Dictionary = Rules.perform_action(state, "scan")
	_expect(not bool(duplicate["accepted"]), "a recorded beacon cannot be scanned twice")
	_expect(int(duplicate["state"]["mission_state"]["battery"]) == before - 1, "duplicate scan consumes no battery")

func _test_all_missions_and_one_time_rewards() -> void:
	var state: Dictionary = Rules.new_state()
	var plans: Array[Array] = [
		["move_down","move_down","move_right","move_right","move_right","scan","move_down","move_down","move_down","move_right","scan","move_left","move_left","move_up","scan","move_left","move_left","move_up","move_up","move_up","move_up"],
		["move_right","move_right","move_down","move_down","move_down","move_right","move_right","move_up","scan","move_down","move_right","move_down","move_down","move_left","scan","move_down","move_left","move_left","move_up","move_up","scan","move_up","move_up","move_up","move_left","move_left","move_up"],
		["move_down","move_down","move_right","move_right","move_right","scan","move_left","move_down","move_down","move_down","move_right","scan","move_left","move_left","move_up","scan","move_left","move_up","move_up","move_up","move_up"]
	]
	for mission_index in range(Rules.mission_count()):
		for action in plans[mission_index]:
			var result: Dictionary = Rules.perform_action(state, str(action))
			_expect(bool(result["accepted"]), "mission %d accepts %s" % [mission_index + 1, str(action)])
			state = result["state"]
		_expect(bool(state["completed"][mission_index]), "mission %d awards completion once" % (mission_index + 1))
		_expect(int(state["score"]) == (mission_index + 1) * 100, "mission %d awards exactly 100 points" % (mission_index + 1))
		if mission_index < Rules.mission_count() - 1:
			var next: Dictionary = Rules.perform_action(state, "next")
			_expect(bool(next["accepted"]), "next mission unlocks after returning to base")
			state = next["state"]
	_expect(str(state["status"]) == "won", "three-mission campaign completes")
	_expect(int(state["score"]) == 300, "campaign score is capped at 300")
	var after_finish: Dictionary = Rules.perform_action(state, "move_up")
	_expect(not bool(after_finish["accepted"]), "completed campaign rejects additional actions")
	_expect(int(after_finish["state"]["score"]) == 300, "completed campaign cannot duplicate rewards")
	var restarted: Dictionary = Rules.new_state()
	_expect(int(restarted["score"]) == 0 and int(restarted["mission_index"]) == 0, "new campaign resets score and mission")

func _test_battery_depletion() -> void:
	var state: Dictionary = Rules.new_state()
	var mission_state: Dictionary = state["mission_state"]
	mission_state["x"] = 3
	mission_state["y"] = 2
	mission_state["battery"] = 1
	state["mission_state"] = mission_state
	var result: Dictionary = Rules.perform_action(state, "move_down")
	_expect(bool(result["accepted"]), "insufficient battery resolves as a mission failure")
	_expect(str(result["state"]["mission_state"]["status"]) == "lost", "insufficient battery aborts the mission")
	_expect(int(result["state"]["mission_state"]["battery"]) == 0, "depleted battery is clamped to zero")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
