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
	var next_button: Button = buttons.get("next") as Button
	_expect(next_button != null, "next-layout action resolves to a real Button")
	if next_button != null:
		next_button.emit_signal("pressed")
	var state_after: Dictionary = scene.get("state")
	_expect(int(scene.get("layout_index")) == 1, "wired NEXT button changes to the second survey")
	_expect(state_after != state_before and is_equal_approx(float(state_after.get("oxygen", 0.0)), 100.0), "layout change resets the survey state")
	var right_button: Button = buttons.get("right") as Button
	_expect(right_button != null, "right-thrust control resolves to a real Button")
	if right_button != null:
		right_button.emit_signal("button_down")
	_expect((scene.get("touch_directions") as Dictionary).has("right"), "touch button_down signal records a thrust direction")
	if right_button != null:
		right_button.emit_signal("button_up")
	_expect(not (scene.get("touch_directions") as Dictionary).has("right"), "touch button_up signal clears the thrust direction")
	var restart_button: Button = buttons.get("restart") as Button
	if restart_button != null:
		restart_button.emit_signal("pressed")
	_expect(int(scene.get("layout_index")) == 1 and is_equal_approx(float((scene.get("state") as Dictionary).get("oxygen", 0.0)), 100.0), "wired RESTART button resets the active survey")
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
