extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var instance := MainScene.instantiate()
	root.add_child(instance)
	await process_frame

	var grid := instance.get_node_or_null("Layout/BoardGrid") as GridContainer
	var run_button := instance.get_node_or_null("Layout/Controls/RunButton") as Button
	var restart_button := instance.get_node_or_null("Layout/Controls/RestartButton") as Button
	var next_button := instance.get_node_or_null("Layout/Controls/NextButton") as Button
	_expect(grid != null and grid.get_child_count() == 16, "scene creates a 4x4 board")
	_expect(run_button != null and restart_button != null and next_button != null, "scene creates stable action controls")

	if grid != null and grid.get_child_count() > 5:
		var first_pipe := grid.get_child(5) as Button
		_expect(first_pipe != null, "first layout exposes a clickable pipe tile")
		if first_pipe != null:
			first_pipe.emit_signal("pressed")
			await process_frame
			var state_after_click: Dictionary = instance.get("game_state")
			_expect(int(state_after_click.get("moves", -1)) == 1, "real pipe button signal consumes one move")

	if restart_button != null:
		restart_button.emit_signal("pressed")
		await process_frame
		var restarted_state: Dictionary = instance.get("game_state")
		_expect(int(restarted_state.get("moves", -1)) == 0, "restart resets the move counter")

	if next_button != null:
		next_button.emit_signal("pressed")
		await process_frame
		_expect(int(instance.get("layout_index")) == 1, "next button advances to the next deterministic layout")

	if run_button != null:
		run_button.emit_signal("pressed")
		await process_frame
		var status_label := instance.get_node_or_null("Layout/StatusLabel") as Label
		_expect(status_label != null and not status_label.text.is_empty(), "test-network button updates visible feedback")

	instance.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Pipe Relay runtime smoke test passed.")
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
