extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_initial_state_and_commands()
	_test_hold_and_wall()
	_test_collision_resolution()
	_test_all_authored_solutions()
	_test_terminal_and_budget_rules()
	if failures.is_empty():
		print("KROLL Drone Relay rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func _test_initial_state_and_commands() -> void:
	var state: Dictionary = Rules.create_state(0)
	_expect(state.get("drones", []).size() == Rules.DRONE_COUNT, "each layout creates exactly three drones")
	_expect(Rules.get_status(state) == "active", "new layout begins active")
	var invalid: Dictionary = Rules.set_command(state, 0, Vector2i(1, 1))
	_expect(not bool(invalid.get("ok", false)), "diagonal command is rejected")
	_expect(state.get("commands", [])[0] == Vector2i.ZERO, "invalid command leaves original state unchanged")
	var configured: Dictionary = Rules.set_command(state, 1, Vector2i.RIGHT)
	_expect(bool(configured.get("ok", false)), "cardinal command is accepted")
	_expect(configured.get("state", {}).get("commands", [])[1] == Vector2i.RIGHT, "command is assigned to the selected drone")


func _test_hold_and_wall() -> void:
	var state: Dictionary = Rules.create_state(1)
	state = Rules.set_command(state, 0, Vector2i.RIGHT).get("state", state)
	state = Rules.set_command(state, 1, Vector2i.RIGHT).get("state", state)
	state = Rules.set_command(state, 2, Vector2i.RIGHT).get("state", state)
	var first: Dictionary = Rules.step(state)
	state = first.get("state", state)
	var drones: Array = state.get("drones", [])
	_expect(Vector2i(drones[0].get("position")) == Vector2i(1, 0), "drone A moves one cell in a committed tick")
	_expect(Vector2i(drones[1].get("position")) == Vector2i(1, 2), "drone B moves in the same tick")
	_expect(Vector2i(drones[2].get("position")) == Vector2i(1, 4), "drone C moves in the same tick")
	_expect(int(drones[0].get("battery")) == Rules.INITIAL_BATTERY - 1, "successful movement consumes one battery unit")
	state = Rules.set_command(state, 0, Vector2i.RIGHT).get("state", state)
	var blocked: Dictionary = Rules.step(state)
	state = blocked.get("state", state)
	drones = state.get("drones", [])
	_expect(Vector2i(drones[0].get("position")) == Vector2i(1, 0), "wall blocks a drone without moving it")
	_expect(int(drones[0].get("battery")) == Rules.INITIAL_BATTERY - 1, "blocked movement does not consume battery")
	_expect(int(state.get("ticks", 0)) == 2, "a committed blocked tick still advances the simulation clock")


func _test_collision_resolution() -> void:
	var state: Dictionary = Rules.create_state(0)
	var drones: Array = state.get("drones", []).duplicate(true)
	drones[0]["position"] = Vector2i(1, 5)
	drones[1]["position"] = Vector2i(3, 5)
	drones[2]["position"] = Vector2i(0, 3)
	state["drones"] = drones
	state = Rules.set_command(state, 0, Vector2i.RIGHT).get("state", state)
	state = Rules.set_command(state, 1, Vector2i.LEFT).get("state", state)
	var result: Dictionary = Rules.step(state)
	var next_state: Dictionary = result.get("state", {})
	var next_drones: Array = next_state.get("drones", [])
	_expect(Vector2i(next_drones[0].get("position")) == Vector2i(1, 5), "same-destination collision blocks drone A")
	_expect(Vector2i(next_drones[1].get("position")) == Vector2i(3, 5), "same-destination collision blocks drone B")
	_expect(int(next_state.get("collisions", 0)) == 2, "collision diagnostics count both blocked drones")
	_expect(int(next_drones[0].get("battery", 0)) == Rules.INITIAL_BATTERY, "collision does not consume battery")

	var occupied_state: Dictionary = Rules.create_state(0)
	var occupied_drones: Array = occupied_state.get("drones", []).duplicate(true)
	occupied_drones[0]["position"] = Vector2i(0, 5)
	occupied_drones[1]["position"] = Vector2i(1, 5)
	occupied_state["drones"] = occupied_drones
	occupied_state = Rules.set_command(occupied_state, 0, Vector2i.RIGHT).get("state", occupied_state)
	var occupied_result: Dictionary = Rules.step(occupied_state)
	var occupied_next: Dictionary = occupied_result.get("state", {})
	_expect(Vector2i(occupied_next.get("drones", [])[0].get("position")) == Vector2i(0, 5), "moving into a stationary drone's cell is blocked")
	_expect(int(occupied_next.get("collisions", 0)) == 1, "stationary-cell conflict is recorded")


func _test_all_authored_solutions() -> void:
	var level_zero: Dictionary = Rules.create_state(0)
	for tick in range(5):
		for drone_index in range(Rules.DRONE_COUNT):
			level_zero = Rules.set_command(level_zero, drone_index, Vector2i.RIGHT).get("state", level_zero)
		level_zero = Rules.step(level_zero).get("state", level_zero)
	_expect(Rules.get_status(level_zero) == "won", "parallel approach layout has a valid five-tick solution")

	var level_one: Dictionary = Rules.create_state(1)
	var detour_solution: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP]
	for direction in detour_solution:
		for drone_index in range(Rules.DRONE_COUNT):
			level_one = Rules.set_command(level_one, drone_index, direction).get("state", level_one)
		level_one = Rules.step(level_one).get("state", level_one)
	_expect(Rules.get_status(level_one) == "won", "cargo detours layout reaches all goals within seven ticks")

	var level_two: Dictionary = Rules.create_state(2)
	var solution_a: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT]
	var solution_b: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT]
	var solution_c: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT]
	for tick in range(6):
		level_two = Rules.set_command(level_two, 0, solution_a[tick]).get("state", level_two)
		level_two = Rules.set_command(level_two, 1, solution_b[tick]).get("state", level_two)
		level_two = Rules.set_command(level_two, 2, solution_c[tick]).get("state", level_two)
		level_two = Rules.step(level_two).get("state", level_two)
	_expect(Rules.get_status(level_two) == "won", "offset landing layout requires distinct per-drone schedules and is solvable")


func _test_terminal_and_budget_rules() -> void:
	var state: Dictionary = Rules.create_state(0)
	state["ticks"] = Rules.MAX_TICKS
	_expect(Rules.get_status(state) == "out_of_ticks", "tick budget has a deterministic terminal state")
	var terminal: Dictionary = Rules.step(state)
	_expect(not bool(terminal.get("ok", false)), "terminal state rejects further simulation steps")
	state = Rules.create_state(0)
	var drones: Array = state.get("drones", []).duplicate(true)
	drones[0]["battery"] = 0
	state["drones"] = drones
	_expect(Rules.get_status(state) == "out_of_battery", "a drone without battery cannot remain active away from its goal")


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
