extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // PLANETARY CLIMATE LAB", "game displays its title")
	_expect(game.call("get_planet_count") == 3, "game initializes three planets")
	_expect(game.call("get_slider_count") == 2, "game builds albedo and greenhouse sliders")
	_expect(game.call("get_control_button_count") == 4, "game builds four action buttons")
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("planet_id", "")) == "nysa", "campaign starts at Nysa")

	var references: Array[Dictionary] = [
		{"albedo": 0.30, "greenhouse": 0.40},
		{"albedo": 0.25, "greenhouse": 0.15},
		{"albedo": 0.50, "greenhouse": 0.45}
	]
	for planet_index in range(3):
		var reference: Dictionary = references[planet_index]
		_expect(bool(game.call("set_albedo", float(reference["albedo"])), "runtime sets albedo for planet %d" % planet_index)
		_expect(bool(game.call("set_greenhouse", float(reference["greenhouse"])), "runtime sets greenhouse for planet %d" % planet_index)
		_expect(bool(game.call("simulate")), "runtime stabilizes planet %d" % planet_index)
		var state: Dictionary = game.call("get_current_state")
		_expect(int(state.get("score", 0)) == (planet_index + 1) * 100, "runtime awards planet %d exactly once" % planet_index)
		if planet_index < 2:
			_expect(bool(game.call("advance_planet")), "runtime advances to planet %d" % (planet_index + 1))
	_expect(str(game.call("get_current_state").get("status", "")) == "campaign_complete", "runtime completes the three-planet campaign")
	_expect(not bool(game.call("simulate")), "runtime rejects repeated campaign scoring")
	_expect(bool(game.call("restart_campaign")), "runtime starts a fresh campaign")
	_expect(int(game.call("get_current_state").get("score", -1)) == 0, "fresh campaign clears the previous score")
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("KROLL Planetary Climate Lab runtime smoke test passed.")
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
