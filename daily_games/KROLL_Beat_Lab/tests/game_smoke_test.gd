extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.lane_buttons.size() == 4, "four lane buttons are created")
	_expect(game.find_child("RestartButton", true, false) != null, "restart button exists")
	_expect(game.find_child("NextChartButton", true, false) != null, "next chart button exists")
	var lane: int = game.rules.get_note_lane(0)
	game.elapsed_seconds = game.rules.get_note_time(0)
	game.lane_buttons[lane].pressed.emit()
	var status: Dictionary = game.rules.get_status()
	_expect(int(status["hits"]) == 1 and int(status["score"]) == 100, "actual lane button signal registers a hit")
	game.next_chart()
	_expect(game.chart_index == 1 and game.elapsed_seconds == 0.0, "next chart resets timer and advances")
	game.next_chart()
	game.next_chart()
	_expect(game.chart_index == 0, "chart selection wraps from last to first")
	game.restart_chart()
	_expect(int(game.rules.get_status()["score"]) == 0, "restart resets score")
	if failures.is_empty():
		print("KROLL Beat Lab runtime smoke test passed.")
		game.queue_free()
		await process_frame
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		game.queue_free()
		await process_frame
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
