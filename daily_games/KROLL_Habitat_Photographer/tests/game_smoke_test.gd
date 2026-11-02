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
		state = game.call("get_current_state")
		_expect(int(state.get("target_focus", 0)) == int(stage["focus"]), "habitat %d exposes its focus field brief" % stage_index)
		_expect(int(state.get("target_zoom", 0)) == int(stage["zoom"]), "habitat %d exposes its zoom field brief" % stage_index)
		_expect(int(state.get("target_exposure", 99)) == int(stage["exposure"]), "habitat %d exposes its exposure field brief" % stage_index)
		var current_focus: int = int(state.get("focus", 3))
		var current_zoom: int = int(state.get("zoom", 2))
		var current_exposure: int = int(state.get("exposure", 0))
		while current_focus < int(stage["focus"]):
			_expect(bool(game.call("adjust_setting", "focus", 1)), "habitat %d accepts focus calibration" % stage_index)
			current_focus += 1
		while current_focus > int(stage["focus"]):
			_expect(bool(game.call("adjust_setting", "focus", -1)), "habitat %d accepts focus calibration" % stage_index)
			current_focus -= 1
		while current_zoom < int(stage["zoom"]):
			_expect(bool(game.call("adjust_setting", "zoom", 1)), "habitat %d accepts zoom calibration" % stage_index)
			current_zoom += 1
		while current_zoom > int(stage["zoom"]):
			_expect(bool(game.call("adjust_setting", "zoom", -1)), "habitat %d accepts zoom calibration" % stage_index)
			current_zoom -= 1
		while current_exposure < int(stage["exposure"]):
			_expect(bool(game.call("adjust_setting", "exposure", 1)), "habitat %d accepts exposure calibration" % stage_index)
			current_exposure += 1
		while current_exposure > int(stage["exposure"]):
			_expect(bool(game.call("adjust_setting", "exposure", -1)), "habitat %d accepts exposure calibration" % stage_index)
			current_exposure -= 1
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
	_expect(bool(game.call("reset_stage")), "reset control restarts a completed expedition")
	state = game.call("get_current_state")
	_expect(int(state.get("stage_index", -1)) == 0 and int(state.get("score", -1)) == 0, "completed expedition restart clears score and returns to the first habitat")
	_expect(not bool(state.get("campaign_complete", true)), "restarted expedition is playable again")
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
