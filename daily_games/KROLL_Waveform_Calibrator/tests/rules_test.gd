extends SceneTree

const Rules = preload("res://rules.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.level_count() == 3, "campaign contains three relays")
	for index in range(Rules.level_count()):
		var level: Dictionary = Rules.get_level(index)
		var target: Dictionary = level["target"]
		var start: Dictionary = level["start"]
		_expect(Rules.unique_solution_count(target) == 1, "%s has exactly one solution" % str(level["name"]))
		_expect(Rules.is_calibrated(target, target), "%s accepts its exact target" % str(level["name"]))
		_expect(not Rules.is_calibrated(start, target), "%s starting signal is not already solved" % str(level["name"]))
		_expect(Rules.root_mean_square_error(start, target, 128) > 0.001, "%s starting signal has measurable error" % str(level["name"]))
	var base := {"frequency": 4, "amplitude": 3, "phase": 7, "offset": 1}
	var clamped := Rules.adjust_setting(base, "frequency", 1)
	_expect(int(clamped["frequency"]) == 4, "frequency clamps at its upper bound")
	clamped = Rules.adjust_setting(base, "phase", 1)
	_expect(int(clamped["phase"]) == 7, "phase clamps at its upper bound")
	clamped = Rules.adjust_setting(base, "offset", 1)
	_expect(int(clamped["offset"]) == 1, "offset clamps at its upper bound")
	clamped = Rules.adjust_setting(base, "offset", -5)
	_expect(int(clamped["offset"]) == -1, "offset clamps at its lower bound")
	_expect(Rules.score_for_moves(8, 8) == 100, "at-par calibration earns 100")
	_expect(Rules.score_for_moves(9, 8) == 75, "over-par calibration earns 75")
	_expect(Rules.score_for_moves(-1, 8) == 0, "negative move counts cannot earn points")
	if _failures.is_empty():
		print("KROLL Waveform Calibrator rules tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
