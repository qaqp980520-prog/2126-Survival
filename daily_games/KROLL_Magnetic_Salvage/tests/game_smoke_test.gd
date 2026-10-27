extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(str(game.get("state")) == "playing", "scene starts in playing state")
	_expect(int(game.get("scraps").size()) == 8, "scene starts with eight scrap parts")
	game.set("player_position", Vector2(190, 160))
	_expect(bool(game.call("apply_magnet_pulse")), "magnet pulse activates with available charge")
	_expect(int(game.get("parts_collected")) == 1, "scrap at the drone is collected")
	_expect(int(game.get("charge")) == 6, "collecting metal restores the consumed charge")
	game.set("parts_collected", 6)
	game.set("player_position", Vector2(880, 300))
	_expect(bool(game.call("try_extract")), "drone extracts after collecting target parts")
	_expect(str(game.get("state")) == "won", "successful extraction ends the round")
	game.call("restart_game")
	_expect(str(game.get("state")) == "playing" and int(game.get("parts_collected")) == 0, "restart resets round state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Magnetic Salvage runtime smoke test passed.")
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
