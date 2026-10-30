extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Control = MainScene.instantiate() as Control
	_expect(scene != null, "Tidal Survey main scene instantiates")
	if scene == null:
		_finish(1)
		return
	root.add_child(scene)
	await process_frame
	_expect(scene.has_method("_start_layout"), "main scene exposes layout initialization")
	var buttons: Dictionary = scene.get("touch_buttons")
	_expect(buttons.has("up") and buttons.has("left") and buttons.has("down") and buttons.has("right"), "touch thrust controls are present")
	_expect(buttons.has("restart") and buttons.has("next"), "restart and next-layout controls are present")
	var state_before: Dictionary = scene.get("state")
	scene.call("_start_layout", 1)
	var state_after: Dictionary = scene.get("state")
	_expect(int(scene.get("layout_index")) == 1, "layout selector changes to the second survey")
	_expect(state_after != state_before and is_equal_approx(float(state_after.get("oxygen", 0.0)), 100.0), "layout change resets the survey state")
	scene.call("_set_touch_direction", "right")
	_expect((scene.get("touch_directions") as Dictionary).has("right"), "touch button down records a thrust direction")
	scene.call("_clear_touch_direction", "right")
	_expect(not (scene.get("touch_directions") as Dictionary).has("right"), "touch button up clears the thrust direction")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Tidal Survey runtime smoke test passed.")
		quit(0)
	else:
		_finish(1)

func _finish(exit_code: int) -> void:
	if exit_code == 0 and failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: " + failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
