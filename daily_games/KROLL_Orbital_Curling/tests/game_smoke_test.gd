extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "scene exposes a defensive campaign snapshot")
	_expect(game.has_method("throw_from_aim"), "scene exposes a live throw action")
	_expect(game.find_child("GameTitle", true, false) != null, "scene builds its title")
	_expect(game.find_child("NextRoundButton", true, false) != null, "scene builds its next-round button")
	_expect(game.find_child("RestartButton", true, false) != null, "scene builds its restart button")
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("status", "")) == "playing" and int(initial.get("shots_left", -1)) == 3, "scene starts a fresh round")
	_expect(bool(game.call("throw_from_aim", Vector2.RIGHT, 300.0)), "live scene accepts a valid throw")
	_expect(int(game.call("get_current_state").get("shots_left", -1)) == 2, "live scene consumes one throw")
	game.call("restart_campaign")
	_expect(int(game.call("get_current_state").get("round_index", -1)) == 0, "live restart returns to round one")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Orbital Curling runtime smoke test passed.")
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
