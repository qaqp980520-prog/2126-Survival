extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_scenario_count() == 3, "three authored imaging assignments exist")
	var solutions: Array[Dictionary] = [
		{"center": Vector2(320.0, 170.0), "zoom": 1},
		{"center": Vector2(205.0, 160.0), "zoom": 1},
		{"center": Vector2(475.0, 160.0), "zoom": 1}
	]
	for index in range(solutions.size()):
		var solution: Dictionary = solutions[index]
		var result: Dictionary = Rules.evaluate_capture(index, solution["center"], int(solution["zoom"]))
		_expect(bool(result.get("ok", false)), "authored solution frames every target without interference: scenario %d" % index)
		_expect(int(result.get("targets_inside", 0)) == 3 and int(result.get("hazards_inside", -1)) == 0, "solution contains three targets and zero hazards: scenario %d" % index)
	var wide_frame: Dictionary = Rules.evaluate_capture(0, Vector2(320.0, 170.0), 0)
	_expect(str(wide_frame.get("reason", "")) == "hazard_in_frame", "wide framing is rejected when interference enters the shot")
	var missed_targets: Dictionary = Rules.evaluate_capture(0, Vector2(20.0, 20.0), 3)
	_expect(str(missed_targets.get("reason", "")) == "targets_missing", "narrow framing is rejected when required targets are outside")
	var invalid_zoom: Dictionary = Rules.evaluate_capture(0, Vector2(320.0, 170.0), 99)
	_expect(str(invalid_zoom.get("reason", "")) == "invalid_camera", "unsupported zoom levels are rejected")
	var invalid_center: Dictionary = Rules.evaluate_capture(0, Vector2(INF, 0.0), 1)
	_expect(str(invalid_center.get("reason", "")) == "invalid_camera", "non-finite camera coordinates are rejected")
	_expect(Rules.frame_half_extents(1).x < Rules.frame_half_extents(0).x, "zooming in narrows the camera frame")
	_expect(not Rules.point_inside_frame(Vector2(640.0, 360.0), Vector2.ZERO, 1), "points outside the frame are excluded")
	if failures.is_empty():
		print("KROLL Orbital Imager rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
