extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	var state: Dictionary = game.get("state")
	_expect(str(state.get("status", "")) == "playing", "scene starts in playable state")
	_expect((game.get("platforms") as Array).size() >= 5, "scene builds multiple platforms")
	_expect((game.get("cell_positions") as Array).size() == Rules.REQUIRED_CELLS, "scene places the required number of power cells")
	_expect((game.get("vents") as Array).size() >= 1, "scene includes vent boost surfaces")
	var cells: Array = game.get("cell_positions")
	for cell in cells:
		game.set("player_position", cell)
		game.call("_collect_nearby_cells")
	state = game.get("state")
	_expect(int(state.get("cells_collected", 0)) == Rules.REQUIRED_CELLS, "scene collects all cells through its proximity handler")
	game.set("player_position", Vector2(910.0, 540.0))
	game.call("_try_exit")
	state = game.get("state")
	_expect(str(state.get("status", "")) == "won", "scene extraction wins after collecting all cells")
	game.call("_restart_game")
	state = game.get("state")
	_expect(str(state.get("status", "")) == "playing", "restart returns to playable state")
	_expect(int(state.get("cells_collected", -1)) == 0 and int(state.get("lives", -1)) == Rules.STARTING_LIVES, "restart resets collection and lives")
	_expect((game.get("cell_active") as Array).all(func(active): return bool(active)), "restart reactivates every power cell")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Vent Runner runtime smoke test passed.")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
