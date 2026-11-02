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
	_expect(game.call("get_title_text") == "KROLL // TITRATION BENCH", "game displays its title")
	_expect(game.call("get_sample_count") == 3, "game initializes three unknown samples")
	_expect(game.call("get_control_button_count") == 7, "game builds seven measured-action controls")
	var rules: RefCounted = RulesScript.new()
	for sample_index in range(3):
		var endpoint: float = float(rules.get_reference_endpoint_ml(sample_index))
		while float(game.call("get_current_state").get("volume_added_ml", 0.0)) < endpoint:
			_expect(bool(game.call("add_titrant", 2.5)), "runtime accepts a measured titrant addition")
		_expect(bool(game.call("submit_endpoint")), "runtime captures sample %d at its endpoint" % sample_index)
		var state: Dictionary = game.call("get_current_state")
		_expect(int(state.get("score", 0)) == (sample_index + 1) * 100, "runtime awards sample %d exactly once" % sample_index)
		if sample_index < 2:
			_expect(bool(game.call("advance_sample")), "runtime advances to sample %d" % (sample_index + 1))
	_expect(str(game.call("get_current_state").get("status", "")) == "campaign_complete", "runtime completes the three-sample campaign")
	_expect(not bool(game.call("submit_endpoint")), "runtime rejects repeated campaign scoring")
	_expect(bool(game.call("restart_campaign")), "runtime can start a fresh campaign")
	_expect(int(game.call("get_current_state").get("score", -1)) == 0, "fresh campaign clears the prior score")
	_expect(not bool(game.call("add_titrant", 0.25)), "runtime rejects an uncalibrated addition")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Titration Bench runtime smoke test passed.")
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
