extends SceneTree

const MainScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	var grid: GridContainer = game.get_node_or_null("Layout/MirrorGrid") as GridContainer
	var failures: Array[String] = []
	_expect(grid != null, "Main scene creates the mirror grid", failures)
	_expect(grid != null and grid.get_child_count() == 49, "Grid contains 49 cells", failures)
	_expect(game.has_method("_on_cell_pressed"), "Scene exposes the mirror rotation action", failures)
	if grid != null and game.has_method("_on_cell_pressed"):
		game.call("_on_cell_pressed", 2, 5)
		_expect(str(game.get("game_state").get("status", "")) == "playing", "First tap updates the scene without ending the puzzle", failures)
		game.call("_on_cell_pressed", 5, 5)
		_expect(str(game.get("game_state").get("status", "")) == "won", "Second tap powers the receiver in the live scene", failures)
		var final_button := grid.get_node_or_null("Cell_5_5") as Button
		_expect(final_button != null and final_button.disabled, "Terminal puzzle locks mirror controls", failures)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Prism Relay runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
