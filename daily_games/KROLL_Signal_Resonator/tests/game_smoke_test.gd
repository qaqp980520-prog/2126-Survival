extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // SIGNAL RESONATOR", "game displays its title")
	_expect(game.call("get_level_count") == 3, "game provides three stages")
	_expect(game.call("get_lane_button_count") == 3, "game builds three playable lane buttons")
	_expect(str(game.call("get_current_state").get("status", "")) == "playing", "game starts in the playing state")
	_expect(bool(game.call("submit_lane_hit", 0, 900)), "game accepts an on-beat lane hit")
	var state: Dictionary = game.call("get_current_state")
	_expect(int(state.get("hits", 0)) == 1 and int(state.get("note_index", 0)) == 1, "runtime hit updates score state")
	_expect(not bool(game.call("submit_lane_hit", 1, 1000)), "runtime rejects a hit before the next timing window")
	_expect(bool(game.call("restart_level")), "runtime can restart the active stage")
	state = game.call("get_current_state")
	_expect(int(state.get("note_index", -1)) == 0 and int(state.get("hits", -1)) == 0, "restart resets stage progress")
	_expect(bool(game.call("submit_lane_hit", 0, 900)), "restarted stage accepts a fresh first hit")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Signal Resonator runtime smoke test passed.")
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
