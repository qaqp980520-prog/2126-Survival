extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := Rules.new_state()
	_expect(int(state["cells_collected"]) == 0 and int(state["lives"]) == 3, "new run starts with zero cells and three lives")
	_expect(not Rules.try_exit(state), "exit remains locked until all cells are collected")
	for index in range(Rules.REQUIRED_CELLS):
		_expect(Rules.collect_cell(state), "required power cell %d is accepted" % (index + 1))
	_expect(not Rules.collect_cell(state), "collection count cannot exceed the required cell count")
	_expect(int(state["score"]) == Rules.REQUIRED_CELLS * 100, "each power cell adds one hundred points")
	_expect(Rules.try_exit(state), "exit opens after all required cells are collected")
	_expect(str(state["status"]) == "won", "successful extraction wins the run")
	_expect(not Rules.hit_hazard(state), "terminal win state rejects hazard damage")

	var damaged := Rules.new_state()
	_expect(Rules.hit_hazard(damaged), "first hazard hit is accepted")
	_expect(int(damaged["lives"]) == 2, "hazard removes exactly one life")
	_expect(Rules.hit_hazard(damaged), "second hazard hit is accepted")
	_expect(Rules.hit_hazard(damaged), "third hazard hit is accepted")
	_expect(str(damaged["status"]) == "lost" and str(damaged["reason"]) == "hull_breach", "zero lives causes hull breach")
	_expect(not Rules.hit_hazard(damaged), "lost state rejects additional damage")

	var timeout := Rules.new_state()
	Rules.tick(timeout, 12.5)
	_expect(is_equal_approx(float(timeout["time_left"]), 77.5), "timer subtracts elapsed time")
	Rules.tick(timeout, 100.0)
	_expect(str(timeout["status"]) == "lost" and str(timeout["reason"]) == "time_expired", "timer expiration ends the run")
	_expect(is_equal_approx(float(timeout["time_left"]), 0.0), "timer clamps at zero")
	print("KROLL Vent Runner rules tests passed." if failures.is_empty() else "KROLL Vent Runner rules tests failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
