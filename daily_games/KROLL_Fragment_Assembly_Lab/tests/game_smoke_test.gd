extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // FRAGMENT ASSEMBLY LAB", "game scene exposes the expected title")
	_expect(int(game.call("get_level_count")) == 3, "game scene exposes three labs")
	_expect(int(game.call("get_fragment_button_count")) == 4, "first lab builds four fragment buttons")
	_expect(int(game.call("get_control_button_count")) == 2, "game scene exposes restart and next controls")
	var initial_state: Dictionary = game.call("get_state")
	_expect(str(initial_state.get("sequence", "")) == "ACGTAG", "first lab displays its seed sequence")
	game.call("perform_fragment", "A")
	await process_frame
	var after_first: Dictionary = game.call("get_state")
	_expect(str(after_first.get("sequence", "")) == "ACGTAGCTT", "valid fragment extends the sequence by its overlap")
	_expect(int(game.call("get_fragment_button_count")) == 3, "used fragment disappears from the selection grid")
	game.call("perform_fragment", "B")
	await process_frame
	var passed_state: Dictionary = game.call("get_state")
	_expect(str(passed_state.get("status", "")) == "level_passed", "scene reports the first lab as passed")
	game.call("advance_level")
	await process_frame
	var next_state: Dictionary = game.call("get_state")
	_expect(int(next_state.get("level_index", -1)) == 1, "next control advances to the second lab")
	_expect(str(next_state.get("sequence", "")) == "GATTA", "next lab loads its own seed sequence")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Fragment Assembly Lab runtime smoke test passed.")
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
