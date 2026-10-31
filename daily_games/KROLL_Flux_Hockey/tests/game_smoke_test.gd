extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = GameScene.instantiate() as Node2D
	_expect(game != null, "Flux Hockey main scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	var initial: Dictionary = game.call("get_game_state")
	_expect(int(initial.get("arena_index", -1)) == 0, "game starts with Dock Ring")
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(650.0, 520.0)
	game.call("_input", drag)
	await process_frame
	var moved: Dictionary = game.call("get_game_state")
	_expect(float(moved.get("player_x", 0.0)) > float(initial.get("player_x", 0.0)), "touch drag updates the lower paddle target")
	game.call("_next_arena")
	var next: Dictionary = game.call("get_game_state")
	_expect(int(next.get("arena_index", -1)) == 1, "runtime next-arena action changes the bumper layout")
	game.call("_reset_match")
	var reset: Dictionary = game.call("get_game_state")
	_expect(int(reset.get("arena_index", -1)) == 1 and int(reset.get("player_score", -1)) == 0, "runtime reset preserves arena and clears the score")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Flux Hockey runtime smoke test passed.")
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
		push_error("FAIL: " + message)
