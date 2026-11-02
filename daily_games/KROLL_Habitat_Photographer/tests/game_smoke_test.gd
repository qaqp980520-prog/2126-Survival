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
	_expect(game.call("get_title_text") == "KROLL // HABITAT PHOTOGRAPHER", "game title")
	_expect(game.call("get_stage_count") == 3, "three habitats")
	_expect(game.call("get_control_button_count") == 9, "nine camera and expedition controls")
	var state: Dictionary = game.call("get_current_state")
	_expect(str(state.get("stage_id", "")) == "reed_marsh", "first habitat is Reed Marsh")
	var rules: RefCounted = RulesScript.new()
	for stage_index in range(3):
		var stage: Dictionary = rules.get_stage(stage_index)
		game.set("_elapsed", rules.get_center_capture_time(stage_index))
		_expect(bool(game.call("capture_photo")), "habitat %d captures a correctly prepared photo" % stage_index)
		state = game.call("get_current_state")
		_expect(bool(state.get("stage_awarded", false)), "habitat %d records its capture" % stage_index)
		_expect(int(state.get("score", 0)) == (stage_index + 1) * 100, "habitat %d awards exactly 100 points" % stage_index)
		_expect(not bool(game.call("capture_photo")), "habitat %d cannot award the same photo twice" % stage_index)
		_expect(not bool(game.call("reset_stage")), "captured habitat cannot be reset to farm score")
		if stage_index < 2:
			_expect(bool(game.call("advance_stage")), "habitat %d advances" % stage_index)
	state = game.call("get_current_state")
	_expect(bool(state.get("campaign_complete", false)), "third capture completes the expedition")
	_expect(not bool(game.call("advance_stage")), "completed expedition rejects repeated advancement")
	game.call("reset_campaign")
	state = game.call("get_current_state")
	_expect(int(state.get("stage_index", -1)) == 0 and int(state.get("score", -1)) == 0, "campaign reset starts a fresh expedition")
	_expect(bool(game.call("adjust_setting", "focus", 99)), "focus adjustment is accepted")
	state = game.call("get_current_state")
	_expect(int(state.get("focus", 0)) == 5, "focus remains within its upper bound")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Habitat Photographer runtime smoke test passed.")
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
