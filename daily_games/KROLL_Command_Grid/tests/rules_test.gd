extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := Rules.create_state()
	_expect(state.player == Vector2i(0, 0), "player starts in the upper-left corner")
	_expect(state.data.size() == 4, "four data cores are required")
	_expect(state.enemies.size() == 3, "three security bots patrol the grid")

	_expect(Rules.try_move(state, Vector2i(1, 0)), "orthogonal movement succeeds")
	_expect(state.player == Vector2i(1, 0), "player moves exactly one cell")
	_expect(int(state.turns_left) == Rules.MAX_TURNS - 1, "a successful action consumes one turn")
	_expect(not Rules.try_move(state, Vector2i(1, 1)), "diagonal movement is rejected")

	var wall_state := Rules.create_state()
	wall_state.player = Vector2i(1, 1)
	wall_state.enemies = []
	_expect(not Rules.try_move(wall_state, Vector2i(1, 0)), "wall blocks movement")
	_expect(wall_state.player == Vector2i(1, 1), "blocked movement leaves player unchanged")

	var data_state := Rules.create_state()
	data_state.player = Vector2i(0, 4)
	data_state.data = [Vector2i(1, 4)]
	data_state.enemies = []
	data_state.turns_left = 5
	_expect(Rules.try_move(data_state, Vector2i(1, 0)), "movement onto a data core succeeds")
	_expect(data_state.data.is_empty() and int(data_state.collected) == 1, "data core is collected once")

	var emp_state := Rules.create_state()
	emp_state.player = Vector2i(2, 2)
	emp_state.enemies = [Vector2i(4, 2), Vector2i(7, 7)]
	emp_state.data = []
	emp_state.turns_left = 5
	_expect(Rules.use_emp(emp_state), "EMP activates when a charge is available")
	_expect(int(emp_state.emp) == Rules.INITIAL_EMP - 1, "EMP consumes exactly one charge")
	_expect(emp_state.enemies.size() == 1, "EMP disables enemies within Manhattan radius")
	_expect(Rules.use_emp(emp_state), "remaining EMP can be used when charged")

	var empty_emp := Rules.create_state()
	empty_emp.emp = 0
	var turns_before := int(empty_emp.turns_left)
	_expect(not Rules.use_emp(empty_emp), "EMP refuses to activate with zero charges")
	_expect(int(empty_emp.turns_left) == turns_before, "failed EMP does not consume a turn")

	var capture_state := Rules.create_state()
	capture_state.player = Vector2i(0, 0)
	capture_state.enemies = [Vector2i(2, 0)]
	capture_state.data = []
	capture_state.turns_left = 4
	_expect(Rules.try_move(capture_state, Vector2i(1, 0)), "player can move before the bot reaches them")
	_expect(str(capture_state.status) == "lost", "enemy captures the player after a turn")

	var win_state := Rules.create_state()
	win_state.player = Vector2i(6, 7)
	win_state.enemies = []
	win_state.data = []
	win_state.turns_left = 2
	_expect(Rules.try_move(win_state, Vector2i(1, 0)), "player can enter the exit cell")
	_expect(str(win_state.status) == "won", "exit wins only after all data is collected")

	var timeout_state := Rules.create_state()
	timeout_state.enemies = []
	timeout_state.turns_left = 1
	_expect(Rules.try_move(timeout_state, Vector2i(1, 0)), "last available action is accepted")
	_expect(str(timeout_state.status) == "lost", "turn exhaustion ends the mission")

	if failures.is_empty():
		print("KROLL Command Grid rules tests passed.")
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
