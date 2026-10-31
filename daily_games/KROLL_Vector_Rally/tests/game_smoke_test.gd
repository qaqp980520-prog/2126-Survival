extends SceneTree
const GameScene = preload("res://main.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Vector Rally scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its deterministic race state")
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("track_id", "")) == "dock_loop", "game starts on Dock Loop")
	_expect(str(initial.get("status", "")) == "racing", "game starts in racing state")
	var throttle := game.get_node_or_null("ThrottleButton") as Button
	_expect(throttle != null, "touch throttle button exists")
	if throttle != null:
		throttle.emit_signal("button_down")
		game.call("_advance_simulation", 0.05)
		throttle.emit_signal("button_up")
	var accelerated: Dictionary = game.call("get_current_state")
	_expect(Vector2(accelerated.get("velocity", Vector2.ZERO)).length() > 0.0, "touch throttle signal drives the car")
	var steer_left := game.get_node_or_null("SteerLeftButton") as Button
	_expect(steer_left != null, "touch steering button exists")
	if steer_left != null:
		steer_left.emit_signal("button_down")
		game.call("_advance_simulation", 0.05)
		steer_left.emit_signal("button_up")
	var steered: Dictionary = game.call("get_current_state")
	_expect(not is_equal_approx(float(steered.get("heading", 0.0)), float(accelerated.get("heading", 0.0))), "touch steering signal changes the car heading")
	game.call("_restart")
	var restarted: Dictionary = game.call("get_current_state")
	_expect(float(restarted.get("elapsed", -1.0)) == 0.0, "restart resets the race timer")
	_expect(Vector2(restarted.get("velocity", Vector2.ONE)) == Vector2.ZERO, "restart resets the car velocity")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Vector Rally runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
