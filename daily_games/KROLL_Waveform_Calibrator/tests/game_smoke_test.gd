extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.has_method("_adjust_knob") and game.has_method("_submit_signal"), "main scene exposes playable calibration actions")
	_expect(game.get_node_or_null("WaveformGraph") != null, "main scene creates the waveform display")
	var level: Dictionary = Rules.get_level(0)
	var start: Dictionary = level["start"]
	var target: Dictionary = level["target"]
	for knob in ["frequency", "amplitude", "phase", "offset"]:
		var difference: int = int(target[knob]) - int(start[knob])
		while difference > 0:
			game.call("_adjust_knob", knob, 1)
			difference -= 1
		while difference < 0:
			game.call("_adjust_knob", knob, -1)
			difference += 1
	game.call("_submit_signal")
	await process_frame
	var solved: Array = game.get("_solved")
	_expect(solved.size() == 3 and bool(solved[0]), "first relay can be calibrated through the game controls")
	_expect(int(game.get("_score")) == 100, "first relay awards its one-time at-par score")
	game.call("_next_level")
	_expect(int(game.get("_level_index")) == 1, "successful relay advances the campaign")
	game.call("_restart_campaign")
	_expect(int(game.get("_level_index")) == 0 and int(game.get("_score")) == 0, "campaign restart resets progress and score")
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("KROLL Waveform Calibrator runtime smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
