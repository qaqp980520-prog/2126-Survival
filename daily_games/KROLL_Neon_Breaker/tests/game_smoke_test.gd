extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(str(game.get("state")) == "ready", "scene starts ready to launch")
	var bricks: Array = game.get("bricks")
	_expect(bricks.size() == 40, "scene builds a five by eight brick field")
	_expect(int(game.get("lives")) == 3, "round starts with three lives")
	_expect(bool(game.call("launch_ball")), "space-equivalent launch starts the ball")
	_expect(str(game.get("state")) == "playing" and (game.get("ball_velocity") as Vector2).y < 0.0, "launch moves ball upward")

	bricks = game.get("bricks")
	var first_brick: Dictionary = bricks[0]
	var brick_rect: Rect2 = first_brick["rect"]
	game.set("state", "playing")
	game.set("ball_position", Vector2(brick_rect.position.x + brick_rect.size.x * 0.5, brick_rect.end.y + 12.0))
	game.set("ball_velocity", Vector2(0.0, -400.0))
	game.call("_advance_ball", 0.04)
	var after_hit: Array = game.get("bricks")
	_expect(after_hit.size() == 39, "ball collision removes one brick")
	_expect(int(game.get("score")) == 10, "brick collision awards ten points")

	game.set("lives", 3)
	game.set("state", "playing")
	game.set("ball_position", Vector2(420.0, 700.0))
	game.set("ball_velocity", Vector2(0.0, 200.0))
	game.call("_advance_ball", 0.01)
	_expect(int(game.get("lives")) == 2, "lost ball consumes one life")
	_expect(str(game.get("state")) == "ready", "remaining life resets ball for next launch")

	game.call("restart_game")
	_expect(str(game.get("state")) == "ready", "restart returns to ready state")
	_expect(int(game.get("score")) == 0 and int(game.get("lives")) == 3, "restart resets score and lives")
	_expect((game.get("bricks") as Array).size() == 40, "restart rebuilds all bricks")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Neon Breaker runtime smoke test passed.")
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
