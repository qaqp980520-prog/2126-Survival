extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.active_crate is Dictionary and not game.active_crate.is_empty(), "Game should spawn an opening crate")
	assert(game.lives == 3 and game.score == 0, "Game should initialize with three lives and zero score")
	var crate_type := str(game.active_crate["type"])
	var action := "bay_data"
	if crate_type == "HAZARD":
		action = "quarantine"
	elif crate_type == "ORE":
		action = "bay_ore"
	elif crate_type == "MEDICAL":
		action = "bay_medical"
	game._submit_action(action)
	assert(game.score > 0 and game.lives == 3, "Correctly routed crate should score without losing a life")
	game.restart_game()
	assert(not game.ended and game.score == 0 and game.lives == 3, "Restart should reset round state")
	print("KROLL Freight Sorter runtime smoke test passed.")
	quit(0)
