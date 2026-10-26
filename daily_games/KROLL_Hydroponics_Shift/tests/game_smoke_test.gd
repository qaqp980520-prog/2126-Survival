extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "Main scene must load")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.get("beds").size() == 3)
	assert(is_equal_approx(float(game.get("seconds_left")), 90.0))
	assert(bool(game.get("playing")))
	game.call("reset_game")
	assert(is_equal_approx(float(game.get("seconds_left")), 90.0))
	game.queue_free()
	await process_frame
	print("KROLL Hydroponics Shift runtime smoke test passed.")
	quit(0)
