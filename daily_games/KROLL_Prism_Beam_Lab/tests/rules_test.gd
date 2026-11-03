extends SceneTree

const Rules = preload("res://rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_level_layouts_and_unique_solutions()
	_test_beam_paths()
	_test_invalid_states()
	_test_reflection()
	_test_scoring()
	if failures.is_empty():
		print("KROLL Prism Beam Lab rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_level_layouts_and_unique_solutions() -> void:
	_expect(Rules.level_count() == 3, "campaign contains three authored facilities")
	for index in range(Rules.level_count()):
		var level: Dictionary = Rules.get_level(index)
		_expect(not level.is_empty(), "level %d exists" % index)
		_expect(Rules.has_unique_solution(level), "level %d has exactly one beam solution" % index)
		_expect(Rules.is_valid_orientations(level, Rules.get_initial_orientations(level)), "level %d initial mirror state is valid" % index)
	_expect(Rules.get_level(-1).is_empty(), "negative level index is rejected")
	_expect(Rules.get_level(3).is_empty(), "out-of-range level index is rejected")

func _test_beam_paths() -> void:
	for index in range(Rules.level_count()):
		var level: Dictionary = Rules.get_level(index)
		var solution: Array = Rules.get_solution_orientations(level)
		var report: Dictionary = Rules.trace(level, solution)
		_expect(bool(report.get("success", false)), "level %d solution reaches its receiver" % index)
		_expect(str(report.get("reason", "")) == "receiver", "level %d ends at the receiver" % index)
		var path: Array = report.get("path", [])
		_expect(not path.is_empty() and path[path.size() - 1] == level.get("receiver"), "level %d path terminates at its receiver cell" % index)
		var initial_report: Dictionary = Rules.trace(level, Rules.get_initial_orientations(level))
		_expect(not bool(initial_report.get("success", false)), "level %d initial mirror state does not already solve the puzzle" % index)

func _test_invalid_states() -> void:
	var level: Dictionary = Rules.get_level(0)
	_expect(not Rules.is_valid_orientations(level, []), "missing mirror orientations are rejected")
	_expect(not Rules.is_valid_orientations(level, [0, 0, 2, 1]), "orientation outside zero/one is rejected")
	_expect(not bool(Rules.trace(level, []).get("success", false)), "beam tracer rejects invalid state")
	_expect(Rules.rotate_orientation(0) == 1 and Rules.rotate_orientation(1) == 0, "mirror rotation toggles both orientations")
	_expect(Rules.rotate_orientation(2) == -1, "invalid mirror orientation cannot be rotated")

func _test_reflection() -> void:
	_expect(Rules.reflect_direction(Vector2i(1, 0), 0) == Vector2i(0, -1), "slash mirror turns rightward beam upward")
	_expect(Rules.reflect_direction(Vector2i(0, -1), 0) == Vector2i(1, 0), "slash mirror turns upward beam right")
	_expect(Rules.reflect_direction(Vector2i(1, 0), 1) == Vector2i(0, 1), "backslash mirror turns rightward beam downward")
	_expect(Rules.reflect_direction(Vector2i(0, 1), 1) == Vector2i(1, 0), "backslash mirror turns downward beam right")
	_expect(Rules.reflect_direction(Vector2i(1, 0), 7) == Vector2i.ZERO, "invalid reflection orientation returns zero direction")

func _test_scoring() -> void:
	_expect(Rules.score_for_moves(2, 2) == 100, "solving within par awards one hundred points")
	_expect(Rules.score_for_moves(4, 2) == 75, "extra rotations reduce the level reward")
	_expect(Rules.score_for_moves(-1, 2) == 0, "negative move count cannot earn points")
	_expect(Rules.score_for_moves(1, -1) == 0, "invalid par cannot earn points")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
