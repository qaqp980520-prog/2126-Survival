extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.has_method("get_current_state"))
	assert(game.has_method("apply_mark"))
	assert(game.get_cell_button_count() == 36)
	var rules := Rules.new()
	for puzzle_index in range(rules.get_puzzle_count()):
		var puzzle: Dictionary = rules.get_puzzle(puzzle_index)
		var rows: Array = puzzle["rows"]
		for y in range(6):
			for x in range(6):
				var mark: int = 1 if str(rows[y]).substr(x, 1) == "1" else 2
				assert(game.apply_mark(x, y, mark))
		assert(str(game.get_current_state()["status"]) == "solved")
		assert(game.advance_to_next_puzzle())
		if puzzle_index == rules.get_puzzle_count() - 1:
			assert(str(game.get_current_state()["status"]) == "campaign_complete")
	game.queue_free()
	await process_frame
	print("KROLL Raster Survey runtime smoke test passed.")
	quit(0)
