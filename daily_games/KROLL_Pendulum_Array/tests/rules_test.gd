extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(rules.get_stage_count() == 3, "three calibration chambers")
	_expect(rules.period_for_length(1.8) > rules.period_for_length(1.0), "longer pendulum has a longer period")
	_expect(rules.period_for_length(0.0) < 0.0, "zero length is rejected")
	_expect(rules.period_for_length(INF) < 0.0, "infinite length is rejected")
	_expect(is_equal_approx(rules.length_for_period(rules.period_for_length(2.25)), 2.25), "period and length formulas are inverse")
	_expect(is_equal_approx(rules.snap_length(1.823), 1.8), "length snaps to five-centimetre increments")
	_expect(is_equal_approx(rules.snap_length(-4.0), RulesScript.MIN_LENGTH), "length clamps to the minimum")
	_expect(is_equal_approx(rules.snap_length(9.0), RulesScript.MAX_LENGTH), "length clamps to the maximum")
	for stage_index in range(rules.get_stage_count()):
		var stage: Dictionary = rules.get_stage(stage_index)
		var target_length: float = float(stage["target_length"])
		var exact: Dictionary = rules.evaluate(target_length, stage_index)
		_expect(bool(exact.get("ok", false)) and bool(exact.get("passed", false)), "exact target length passes chamber %d" % stage_index)
		_expect(int(exact.get("score", 0)) == 100, "correct calibration awards one hundred points")
		var adjacent: Dictionary = rules.evaluate(target_length + RulesScript.LENGTH_STEP, stage_index)
		_expect(bool(adjacent.get("ok", false)) and not bool(adjacent.get("passed", true)), "one-step length error fails chamber %d" % stage_index)
		_expect(float(stage.get("target_period", 0.0)) > 0.0, "chamber %d publishes a positive reference period" % stage_index)
	_expect(not bool(rules.evaluate(1.0, 99).get("ok", true)), "unknown chamber is rejected")
	_expect(not bool(rules.evaluate(0.2, 0).get("ok", true)), "out-of-range length is rejected")
	if failures.is_empty():
		print("KROLL Pendulum Array rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
