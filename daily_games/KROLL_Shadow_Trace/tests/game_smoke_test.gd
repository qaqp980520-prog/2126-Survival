extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.has_method("try_move"), "scene exposes player movement")
	_expect(game.has_method("restart_game"), "scene exposes restart")
	_expect(game.get("game_state") is Dictionary, "scene initializes a game state")

	_expect(bool(game.call("try_move", Vector2i(1, 0))), "player can take a legal first step")
	_expect(int(game.get("game_state").get("turns", -1)) == 1, "successful step advances turn counter")
	_expect(not bool(game.call("try_move", Vector2i(1, 0))), "wall collision is rejected by the live scene")
	_expect(int(game.get("game_state").get("turns", -1)) == 1, "rejected wall move leaves turn counter unchanged")

	game.call("next_layout")
	_expect(int(game.get("game_state").get("turns", -1)) == 0, "next layout resets the turn counter")
	game.call("restart_game")
	_expect(int(game.get("game_state").get("turns", -1)) == 0, "restart resets the current layout")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Shadow Trace runtime smoke test passed.")
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
