extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(is_instance_valid(game), "Prism Beam Lab scene instantiates")
	_expect(int(game.get("level_index")) == 0, "campaign starts at the first facility")
	_expect(int(game.get("score")) == 0, "campaign begins with zero points")
	_expect(not bool(game.call("_rotate_mirror", -1)), "invalid mirror index is ignored")

	for level_index in range(Rules.level_count()):
		_expect(int(game.get("level_index")) == level_index, "game advances to facility %d" % level_index)
		var level: Dictionary = game.get("level_data")
		var solution: Array = Rules.get_solution_orientations(level)
		var current: Array = game.get("orientations")
		for mirror_index in range(solution.size()):
			while int(current[mirror_index]) != int(solution[mirror_index]):
				_expect(bool(game.call("_rotate_mirror", mirror_index)), "mirror %d rotates in facility %d" % [mirror_index, level_index])
				current = game.get("orientations")
		_expect(bool(game.call("_fire_beam")), "facility %d beam reaches its receiver" % level_index)
		var completed: Dictionary = game.get("completed_levels")
		_expect(completed.has(level_index), "facility %d reward is recorded once" % level_index)
		if level_index < Rules.level_count() - 1:
			_expect(bool(game.call("_next_level")), "next facility opens after success")
		else:
			_expect(bool(game.call("_next_level")), "final next action completes the campaign")

	_expect(bool(game.get("campaign_finished")), "campaign reaches its terminal state")
	_expect(int(game.get("score")) == 300, "three one-time perfect rewards total three hundred")
	_expect(not bool(game.call("_fire_beam")), "completed campaign cannot be farmed for extra points")
	game.call("_restart_campaign")
	_expect(int(game.get("score")) == 0 and int(game.get("level_index")) == 0, "campaign restart resets score and progress")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Prism Beam Lab runtime smoke test passed.")
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
		push_error("FAIL: " + description)
