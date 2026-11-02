extends SceneTree

const GameScene = preload("res://main.tscn")
const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // PENDULUM ARRAY", "game title")
	_expect(game.call("get_stage_count") == 3, "three playable chambers")
	_expect(is_equal_approx(float(game.call("get_length")), 1.5), "initial pendulum length")
	_expect(bool(game.call("run_test")), "test can be started")
	_expect(bool(game.call("get_current_state").get("testing", false)), "running state is exposed")
	game.call("reset_stage")
	_expect(not bool(game.call("get_current_state").get("testing", true)), "reset cancels an active test")
	var rules: RefCounted = RulesScript.new()
	for stage_index in range(3):
		var stage: Dictionary = rules.get_stage(stage_index)
		game.set("_length", float(stage["target_length"]))
		_expect(bool(game.call("run_test")), "chamber %d starts calibration" % stage_index)
		game.call("finish_test_now")
		var state: Dictionary = game.call("get_current_state")
		_expect(bool(state.get("result", {}).get("passed", false)), "chamber %d locks at its reference length" % stage_index)
		_expect(int(state.get("score", 0)) == (stage_index + 1) * 100, "chamber %d updates campaign score" % stage_index)
		if stage_index == 0:
			_expect(not bool(game.call("run_test")), "a completed calibration cannot be submitted twice")
			game.call("reset_stage")
			game.set("_length", float(stage["target_length"]))
			_expect(bool(game.call("run_test")), "a reset chamber can be recalibrated")
			game.call("finish_test_now")
			state = game.call("get_current_state")
			_expect(int(state.get("score", 0)) == 100, "resetting a completed chamber cannot farm duplicate score")
		_expect(bool(game.call("advance_stage")), "chamber %d advances" % stage_index)
	_expect(bool(game.call("get_current_state").get("campaign_complete", false)), "campaign completes after three locks")
	_expect(not bool(game.call("advance_stage")), "completed campaign rejects repeated next-stage actions")
	game.call("reset_campaign")
	var restarted: Dictionary = game.call("get_current_state")
	_expect(int(restarted.get("stage_index", -1)) == 0 and int(restarted.get("score", -1)) == 0, "campaign reset restores first chamber and zero score")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Pendulum Array runtime smoke test passed.")
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
		push_error("FAIL: " + message)
