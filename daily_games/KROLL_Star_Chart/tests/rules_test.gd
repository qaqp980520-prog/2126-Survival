extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.MISSION_COUNT == 3, "three authored observatory missions are available")
	for mission_index in range(Rules.MISSION_COUNT):
		var mission: Dictionary = Rules.get_mission(mission_index)
		var targets: Array = mission.get("targets", [])
		_expect(targets.size() == Rules.TARGETS_PER_MISSION, "mission %d has four survey stars" % mission_index)
		_expect(not str(mission.get("id", "")).is_empty(), "mission %d has a stable ID" % mission_index)
		for target in targets:
			_expect(Rules.is_valid_target(target), "mission %d target is inside normalized sky bounds" % mission_index)
	var target := Vector2(0.25, 0.75)
	_expect(Rules.can_lock(target, target, 0), "exact reticle alignment always locks")
	_expect(not Rules.can_lock(target + Vector2(0.2, 0.0), target, 0), "a distant reticle cannot lock the target")
	_expect(Rules.get_lock_tolerance(4) < Rules.get_lock_tolerance(0), "higher zoom requires more precise alignment")
	_expect(Rules.advance_target(0, 4) == 1, "successful lock advances one target")
	_expect(Rules.advance_target(4, 4) == 4, "target progress is capped at mission length")
	_expect(not Rules.is_mission_complete(3, 4), "three of four stars is not a complete mission")
	_expect(Rules.is_mission_complete(4, 4), "all four stars complete the mission")
	_expect(Rules.clamp_aim(Vector2(-0.5, 1.5)) == Vector2(0.0, 1.0), "aim coordinates clamp to the visible sky")
	if failures.is_empty():
		print("KROLL Star Chart rules tests passed.")
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
