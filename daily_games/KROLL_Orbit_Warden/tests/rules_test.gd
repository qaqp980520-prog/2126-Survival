extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := Rules.new_state()
	_expect(int(state["lives"]) == 3 and int(state["asteroids_destroyed"]) == 0, "new game initializes lives and target counter")
	_expect(is_equal_approx(float(state["time_left"]), 75.0), "new game initializes the time limit")
	for index in range(Rules.TARGET_DESTROYS - 1):
		_expect(Rules.register_destroy(state), "playing state accepts an asteroid hit")
	_expect(str(state["status"]) == "playing", "eleven destroys do not finish the sector")
	_expect(Rules.register_destroy(state), "twelfth destroy is accepted")
	_expect(str(state["status"]) == "won" and str(state["reason"]) == "sector_cleared", "target count wins the sector")
	var score_after_win := int(state["score"])
	_expect(not Rules.register_destroy(state), "won state rejects additional scoring")
	_expect(int(state["score"]) == score_after_win, "rejected post-win hit does not alter score")

	var lives_state := Rules.new_state()
	for index in range(Rules.STARTING_LIVES):
		_expect(Rules.lose_life(lives_state), "playing state accepts a hull hit")
	_expect(int(lives_state["lives"]) == 0 and str(lives_state["status"]) == "lost", "last life ends the run")
	_expect(not Rules.lose_life(lives_state), "lost state rejects additional life loss")
	_expect(int(lives_state["lives"]) == 0, "life count never becomes negative")

	var timer_state := Rules.new_state()
	Rules.tick(timer_state, 74.5)
	_expect(is_equal_approx(float(timer_state["time_left"]), 0.5), "timer subtracts finite positive delta")
	Rules.tick(timer_state, 1.0)
	_expect(str(timer_state["status"]) == "lost" and str(timer_state["reason"]) == "time_expired", "timer expiry ends the run")
	var invalid_delta_state := Rules.new_state()
	Rules.tick(invalid_delta_state, -1.0)
	Rules.tick(invalid_delta_state, INF)
	_expect(is_equal_approx(float(invalid_delta_state["time_left"]), Rules.TIME_LIMIT), "negative and infinite deltas are ignored")
	print("KROLL Orbit Warden rules tests passed." if failures.is_empty() else "KROLL Orbit Warden rules tests failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
