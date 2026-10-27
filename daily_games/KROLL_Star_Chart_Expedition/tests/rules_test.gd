extends SceneTree

const Rules = preload("res://rules.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var state: Dictionary = Rules.new_state()
	_check(state["position"] == Rules.START and int(state["fuel"]) == Rules.FUEL_START, "Initial state should start at the launch pad with full fuel.")
	var fuel_before: int = int(state["fuel"])
	state = Rules.step(state, Vector2i.LEFT)
	_check(state["last_action"] == "blocked" and int(state["fuel"]) == fuel_before, "Leaving the board must not spend fuel.")
	state = Rules.step(state, Vector2i.UP)
	_check(state["last_action"] == "blocked" and int(state["fuel"]) == fuel_before, "Asteroid collision must not spend fuel.")
	state = Rules.step(state, Vector2i(1, 1))
	_check(state["last_action"] == "invalid_direction" and int(state["fuel"]) == fuel_before, "Diagonal movement must be rejected without fuel cost.")

	# Deterministic 32-step route that visits all three beacons and exits with two fuel.
	var route: Array[Vector2i] = [
		Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1),
		Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1),
		Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5), Vector2i(5, 5), Vector2i(4, 5),
		Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1),
		Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3)
	]
	var previous: Vector2i = Rules.START
	for target in route:
		var direction: Vector2i = target - previous
		state = Rules.step(state, direction)
		_check(state["last_action"] == "move", "Authored route should only contain legal cardinal moves.")
		previous = target
	_check(state["status"] == "won", "Collecting all beacons and reaching the exit should win.")
	_check(int(state["fuel"]) == 2, "The winning route should leave two fuel.")
	var collected: Array = state["collected"]
	_check(collected.size() == 3, "All three beacons should be collected exactly once.")

	var expired: Dictionary = Rules.expire(Rules.new_state())
	_check(expired["status"] == "failed" and expired["last_action"] == "timeout", "Timeout should fail a running mission.")
	var after_terminal: Dictionary = Rules.step(expired, Vector2i.RIGHT)
	_check(after_terminal["position"] == Rules.START, "Terminal states must not accept movement.")
	if _failed:
		print("Star Chart Expedition rules tests failed.")
		quit(1)
	else:
		print("Star Chart Expedition rules tests passed.")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
