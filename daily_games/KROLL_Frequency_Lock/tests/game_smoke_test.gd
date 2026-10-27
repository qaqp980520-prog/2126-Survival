extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	game.set("state", Rules.create_state([1, 2, 3, 4]))
	game.call("_clear_draft")
	for symbol in [1, 1, 2, 3, 4]:
		game.call("_handle_symbol", symbol)
	var draft: Array = game.get("draft")
	_expect(draft.size() == 4, "interactive input caps the draft at four unique symbols")
	_expect(draft == [1, 2, 3, 4], "duplicate selection is ignored by the interface")
	game.call("_submit_guess")
	var state: Dictionary = game.get("state")
	_expect(str(state.get("status", "")) == "won", "scene submission reaches the win state")
	_expect(int(state.get("attempts_left", -1)) == Rules.MAX_ATTEMPTS - 1, "successful submission consumes one attempt")
	game.call("_restart_game")
	state = game.get("state")
	_expect(str(state.get("status", "")) == "playing", "restart creates a new playable state")
	_expect((game.get("draft") as Array).is_empty(), "restart clears the draft")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Frequency Lock runtime smoke test passed.")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
		return
	quit(0)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
