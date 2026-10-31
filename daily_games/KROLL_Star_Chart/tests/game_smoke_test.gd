extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = MainScene.instantiate() as Node2D
	_expect(game != null, "Star Chart main scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("attempt_lock"), "scene exposes the target-lock action")
	_expect(game.has_method("next_mission"), "scene exposes mission progression")
	var mission: Dictionary = game.call("get_current_mission")
	var targets: Array = mission.get("targets", [])
	_expect(targets.size() == 4, "first mission loads four target stars")
	if not targets.is_empty():
		game.call("set_aim", targets[0])
		_expect(bool(game.call("attempt_lock")), "exact first-star alignment succeeds")
		_expect(int(game.get("target_index")) == 1, "successful lock advances mission progress")
		game.call("set_aim", targets[0])
		_expect(not bool(game.call("attempt_lock")), "the previous star cannot be locked twice")
	game.call("restart_mission")
	_expect(int(game.get("target_index")) == 0, "restart resets the target sequence")
	_expect(not bool(game.call("next_mission")), "mission cannot be skipped before completion")
	var previous_aim: Vector2 = game.get("aim")
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(30.0, -20.0)
	game.call("_unhandled_input", drag)
	_expect(game.get("aim") != previous_aim, "touch dragging adjusts telescope aim")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Star Chart runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
