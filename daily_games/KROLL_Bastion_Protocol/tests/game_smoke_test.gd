extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	var state: Dictionary = game.get("state")
	_expect(not state.is_empty(), "main scene initializes game state")
	_expect(bool(game.call("place_tower_at", Vector2i(1, 2)), ""))
	_expect(not bool(game.call("place_tower_at", Vector2i(1, 3))), "scene rejects placing a turret on the route")
	_expect(bool(game.call("start_wave")), "scene starts a wave")
	await process_frame
	state = game.get("state")
	_expect(str(state["phase"]) == "wave", "active wave state is preserved by the scene")
	game.call("restart_game")
	state = game.get("state")
	_expect(int(state["credits"]) == 100, "restart restores the initial economy")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Bastion Protocol runtime smoke test passed.")
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
