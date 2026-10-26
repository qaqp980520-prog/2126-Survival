extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "Main scene must load")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	var beds: Array = game.get("beds")
	assert(beds.size() == 3)
	assert(is_equal_approx(float(game.get("seconds_left")), 90.0))
	assert(bool(game.get("playing")))
	game.call("_water_bed", 0)
	beds = game.get("beds")
	assert(is_equal_approx(float(beds[0]["moisture"]), 93.0), "Calling the watering control should update the selected bed")
	game.call("reset_game")
	assert(is_equal_approx(float(game.get("seconds_left")), 90.0))
	assert(is_equal_approx(float(game.get("credits")), 0.0))
	print("KROLL Hydroponics Shift runtime smoke test passed.")
	quit(0)
