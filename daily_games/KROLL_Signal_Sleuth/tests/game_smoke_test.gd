extends SceneTree

const GameScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = GameScene.instantiate()
	root.add_child(scene)
	await process_frame
	var buttons_value: Variant = scene.get("_cell_buttons")
	assert(buttons_value is Array and buttons_value.size() == 25, "runtime scene builds all 25 cells")
	var state: Dictionary = scene.get("game_state")
	assert(str(state.get("status", "")) == "playing", "runtime game starts in playing state")
	scene.call("_on_cell_pressed", 0)
	state = scene.get("game_state")
	assert(int(state.get("moves", 0)) == 1, "runtime click routes through the rules module")
	scene.call("_next_puzzle")
	state = scene.get("game_state")
	assert(int(state.get("puzzle_index", -1)) == 1, "next-grid button selects a new deterministic puzzle")
	scene.queue_free()
	await process_frame
	print("KROLL Signal Sleuth runtime smoke test passed.")
	quit(0)
