extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_expect(game.get_child_count() > 0, "game builds its interface")
	var grids := game.find_children("*", "GridContainer", true, false)
	_expect(grids.size() == 1, "game creates the tactical grid")
	if not grids.is_empty():
		var grid := grids[0] as GridContainer
		_expect(grid.get_child_count() == 64, "grid contains 64 cells")
	var state: Dictionary = game.get("state")
	_expect(not state.is_empty(), "game initializes deterministic state")
	_expect(bool(game.call("attempt_move", Vector2i(1, 0))), "UI action entry point moves the player")
	var moved_state: Dictionary = game.get("state")
	_expect(moved_state.get("player", Vector2i.ZERO) == Vector2i(1, 0), "UI action updates the same game state")
	game.call("restart_game")
	var reset_state: Dictionary = game.get("state")
	_expect(reset_state.get("player", Vector2i.ZERO) == Vector2i(0, 0), "restart restores the initial player position")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Command Grid runtime smoke test passed.")
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
