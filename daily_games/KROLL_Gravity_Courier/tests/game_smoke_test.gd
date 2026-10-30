extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("player") is CharacterBody2D, "scene creates the courier CharacterBody2D")
	_expect((game.get("cargo_areas") as Dictionary).size() == 4, "scene creates four collectible cargo cells")
	var buttons: Dictionary = game.get("touch_buttons")
	_expect(buttons.has("left") and buttons.has("right") and buttons.has("jump") and buttons.has("flip"), "scene creates all touch controls")
	var initial_gravity: int = int(game.get("state").get("gravity_sign", 0))
	(buttons["flip"] as Button).emit_signal("pressed")
	_expect(int(game.get("state").get("gravity_sign", 0)) == -initial_gravity, "real touch flip button reverses gravity")
	var goal: Area2D = game.get("goal_area")
	goal.body_entered.emit(game.get("player"))
	_expect(str(game.get("state").get("result", "")) == "playing", "exit rejects the courier before all cargo is collected")
	var cargo_areas: Dictionary = game.get("cargo_areas")
	for cargo_id in ["cargo_1", "cargo_2", "cargo_3", "cargo_4"]:
		(cargo_areas[cargo_id] as Area2D).body_entered.emit(game.get("player"))
	_expect((game.get("state").get("collected", []) as Array).size() == 4, "scene cargo signals collect all four cells")
	goal.body_entered.emit(game.get("player"))
	_expect(str(game.get("state").get("result", "")) == "won", "goal signal completes the mission after all cargo is collected")
	game.call("_restart")
	_expect(str(game.get("state").get("result", "")) == "playing" and (game.get("state").get("collected", []) as Array).is_empty(), "restart resets mission state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Gravity Courier runtime smoke test passed.")
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
