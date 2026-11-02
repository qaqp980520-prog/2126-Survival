extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(rules.get_stage_count() == 3, "three field habitats")
	for stage_index in range(rules.get_stage_count()):
		var stage: Dictionary = rules.get_stage(stage_index)
		_expect(not stage.is_empty(), "stage %d has data" % stage_index)
		var center_time: float = rules.get_center_capture_time(stage_index)
		_expect(center_time > 0.0, "stage %d has a valid center crossing time" % stage_index)
		var result: Dictionary = rules.evaluate_capture(stage_index, center_time, int(stage["focus"]), int(stage["zoom"]), int(stage["exposure"]))
		_expect(bool(result.get("passed", false)), "stage %d accepts its exact field settings" % stage_index)
		_expect(int(result.get("score", 0)) == 100, "stage %d awards one photo score" % stage_index)
	var first: Dictionary = rules.evaluate_capture(0, 0.5, 3, 2, 0)
	_expect(str(first.get("reason", "")) == "subject_obscured", "foliage blocks a shutter attempt")
	var off_center: Dictionary = rules.evaluate_capture(0, 0.1, 3, 2, 0)
	_expect(str(off_center.get("reason", "")) == "subject_not_centered", "subject must enter the central viewfinder")
	var wrong_focus: Dictionary = rules.evaluate_capture(0, rules.get_center_capture_time(0), 2, 2, 0)
	_expect(str(wrong_focus.get("reason", "")) == "focus_mismatch", "incorrect focus is rejected")
	var wrong_zoom: Dictionary = rules.evaluate_capture(0, rules.get_center_capture_time(0), 3, 1, 0)
	_expect(str(wrong_zoom.get("reason", "")) == "zoom_mismatch", "incorrect zoom is rejected")
	var wrong_exposure: Dictionary = rules.evaluate_capture(0, rules.get_center_capture_time(0), 3, 2, 1)
	_expect(str(wrong_exposure.get("reason", "")) == "exposure_mismatch", "incorrect exposure is rejected")
	_expect(not bool(rules.evaluate_capture(99, 1.0, 3, 2, 0).get("passed", true)), "invalid habitat is rejected")
	_expect(not bool(rules.evaluate_capture(0, NAN, 3, 2, 0).get("passed", true)), "non-finite shutter time is rejected")
	_expect(rules.get_animal_position(0, 0.0) > 0.0, "animal begins inside the field bounds")
	_expect(rules.get_animal_position(0, 100.0) >= 0.08, "long-running observation remains bounded")
	if failures.is_empty():
		print("KROLL Habitat Photographer rules tests passed.")
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
