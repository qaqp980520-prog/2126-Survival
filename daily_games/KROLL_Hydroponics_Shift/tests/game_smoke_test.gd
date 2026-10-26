extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 8.0
	watchdog.timeout.connect(_on_watchdog_timeout)
	root.add_child(watchdog)
	watchdog.start()

	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "Main scene must load")
	var game: Node2D = packed.instantiate() as Node2D
	assert(game != null, "Main scene must instantiate as Node2D")
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var beds: Array = game.get("beds")
	assert(beds.size() == 3)
	assert(is_equal_approx(float(game.get("seconds_left")), 90.0))
	assert(bool(game.get("playing")))
	game.call("_water_bed", 0)
	beds = game.get("beds")
	assert(is_equal_approx(float(beds[0]["moisture"]), 93.0), "Watering should add 28 moisture points")
	game.call("reset_game")
	assert(is_equal_approx(float(game.get("seconds_left")), 90.0))
	assert(is_equal_approx(float(game.get("credits")), 0.0))
	watchdog.stop()
	print("KROLL Hydroponics Shift runtime smoke test passed.")
	quit(0)

func _on_watchdog_timeout() -> void:
	push_error("KROLL Hydroponics Shift runtime smoke test timed out.")
	quit(1)
