extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
	var packed_scene: PackedScene = load("res://Main.tscn")
	assert(packed_scene != null, "Main.tscn should load")
	var game: Control = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	assert(game.grid != null, "Grid should be initialized")
	assert(game.grid.get_child_count() == 64, "The board should contain 64 cells")
	assert(game.target_count == 3, "Normal difficulty should use 3 cores")
	assert(game.scan_limit == 22, "Normal difficulty should allow 22 scans")
	assert(game.cache_cells.size() == game.target_count, "Targets should be placed")

	var first_button: Button = game.grid.get_child(0)
	first_button.emit_signal("pressed")
	await process_frame
	assert(game.scan_count == 1, "A cell scan should increment the scan count")
	assert(game.scanned_cells.size() == 1, "A scanned cell should be recorded")

	first_button.emit_signal("pressed")
	await process_frame
	assert(game.scan_count == 1, "Scanning the same cell twice should not spend another scan")

	var second_button: Button = game.grid.get_child(1)
	second_button.emit_signal("pressed")
	await process_frame
	assert(game.scan_count == 2, "A second distinct cell should spend one scan")

	print("KROLL Signal Sweep runtime smoke test passed.")
	quit()
