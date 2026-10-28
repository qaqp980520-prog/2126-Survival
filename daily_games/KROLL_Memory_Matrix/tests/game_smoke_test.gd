extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	var buttons: Array = game.get("tile_buttons")
	_expect(buttons.size() == 9, "runtime scene creates all nine signal tiles")
	await create_timer(1.8).timeout
	var state: Dictionary = game.get("state")
	_expect(str(state.get("status", "")) == "input", "opening sequence playback unlocks player input")
	if str(state.get("status", "")) == "input":
		var sequence: Array = state.get("sequence", [])
		game.call("_on_tile_pressed", int(sequence[0]))
		await process_frame
		state = game.get("state")
		_expect(int(state.get("input_index", 0)) == 1, "scene accepts a correct first signal through its button handler")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Memory Matrix runtime smoke test passed.")
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
