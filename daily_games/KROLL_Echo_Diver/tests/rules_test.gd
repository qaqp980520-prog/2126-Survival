extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_test_initial_state_and_bounds()
	_test_blocked_and_invalid_moves()
	_test_sonar_charges_and_reveal_radius()
	_test_hazard_fuel_penalty()
	_test_beacon_and_extraction()
	_test_timeout_and_terminal_state()
	if failures.is_empty():
		print("KROLL Echo Diver rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Echo Diver rule failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _test_initial_state_and_bounds() -> void:
	var state: Dictionary = Rules.new_state()
	_expect(state.get("position") == Rules.START, "initial position")
	_expect(int(state.get("fuel", -1)) == Rules.FUEL_START, "initial fuel")
	_expect(int(state.get("sonar_charges", -1)) == Rules.SONAR_CHARGES, "initial sonar charges")
	_expect(not Rules.is_inside(Vector2i(-1, 0)), "negative board coordinate rejected")
	_expect(not Rules.is_inside(Vector2i(Rules.GRID_WIDTH, 0)), "right board boundary rejected")

func _test_blocked_and_invalid_moves() -> void:
	var state: Dictionary = Rules.new_state()
	var invalid: Dictionary = Rules.step(state, Vector2i(1, 1))
	_expect(invalid.get("last_action") == "invalid_direction", "diagonal movement rejected")
	_expect(invalid.get("position") == Rules.START, "invalid move preserves position")
	var blocked: Dictionary = Rules.step(state, Vector2i.UP)
	_expect(blocked.get("last_action") == "blocked", "wall blocks movement")
	_expect(blocked.get("fuel") == Rules.FUEL_START, "blocked movement costs no fuel")

func _test_sonar_charges_and_reveal_radius() -> void:
	var state: Dictionary = Rules.new_state()
	var pulsed: Dictionary = Rules.pulse_sonar(state)
	_expect(int(pulsed.get("sonar_charges", -1)) == Rules.SONAR_CHARGES - 1, "sonar consumes one charge")
	_expect(Rules.visible_hazards(Rules.START).has(Vector2i(2, 3)), "nearby hazard appears in sonar return")
	var empty: Dictionary = pulsed.duplicate(true)
	empty["sonar_charges"] = 0
	var unavailable: Dictionary = Rules.pulse_sonar(empty)
	_expect(int(unavailable.get("sonar_charges", -1)) == 0, "empty sonar does not go negative")
	_expect(unavailable.get("last_action") == "sonar_unavailable", "empty sonar reports unavailable")

func _test_hazard_fuel_penalty() -> void:
	var state: Dictionary = Rules.new_state()
	state = Rules.step(state, Vector2i.RIGHT)
	state = Rules.step(state, Vector2i.RIGHT)
	_expect(state.get("position") == Vector2i(2, 3), "diver can enter a hidden hazard")
	_expect(int(state.get("fuel", -1)) == Rules.FUEL_START - 6, "hazard costs one move plus four extra fuel")
	_expect(state.get("last_action") == "hazard", "hazard event is reported")

func _test_beacon_and_extraction() -> void:
	var state: Dictionary = Rules.new_state()
	state["position"] = Vector2i(2, 0)
	state = Rules.step(state, Vector2i.DOWN)
	_expect((state.get("collected", []) as Array).has(Vector2i(2, 1)), "beacon collected on entry")
	state["position"] = Vector2i(6, 3)
	state["collected"] = Rules.BEACONS.duplicate()
	state = Rules.step(state, Vector2i.RIGHT)
	_expect(state.get("status") == "won", "extraction succeeds after all beacons")

func _test_timeout_and_terminal_state() -> void:
	var state: Dictionary = Rules.expire(Rules.new_state())
	_expect(state.get("status") == "failed", "timer expiry fails active dive")
	var after: Dictionary = Rules.step(state, Vector2i.RIGHT)
	_expect(after.get("position") == Rules.START, "terminal state cannot move")
