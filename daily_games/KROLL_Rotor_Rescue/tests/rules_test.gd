extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.new_game(1)
	var same: Dictionary = Rules.new_game(1)
	assert(first["survivor_positions"] == same["survivor_positions"], "Same seed must produce the same rescue layout")
	assert(Rules.new_game(1)["survivor_positions"] != Rules.new_game(2)["survivor_positions"], "Different seeds must change the rescue layout")

	var moved: Dictionary = Rules.step(first, Vector2.RIGHT, 0.1)
	var moved_position: Vector2 = moved["position"]
	var start_position: Vector2 = first["position"]
	assert(moved_position.x > start_position.x, "Right thrust moves the helicopter")
	assert(float(moved["fuel"]) < float(first["fuel"]), "Thrust consumes fuel")

	var capped: Dictionary = Rules.new_game(1)
	for index in range(200):
		capped = Rules.step(capped, Vector2.RIGHT, 0.1)
		if bool(capped.get("failed", false)):
			break
	var capped_velocity: Vector2 = capped["velocity"]
	assert(capped_velocity.length() <= Rules.MAX_SPEED + 0.001, "Velocity remains under the flight speed cap")

	var rescue: Dictionary = Rules.new_game(1)
	rescue["position"] = Rules.survivor_positions(1)[0]
	rescue["velocity"] = Vector2.ZERO
	rescue = Rules.step(rescue, Vector2.ZERO, 0.016)
	assert(bool(rescue["rescued"][0]), "Slow helicopter rescues a nearby survivor")

	var unsafe: Dictionary = Rules.new_game(1)
	unsafe["position"] = Rules.survivor_positions(1)[0]
	unsafe["velocity"] = Vector2(100.0, 0.0)
	unsafe = Rules.step(unsafe, Vector2.ZERO, 0.016)
	assert(not bool(unsafe["rescued"][0]), "Fast approach cannot rescue a survivor")

	var collision: Dictionary = Rules.new_game(1)
	collision["position"] = Rules.obstacle_rects(1)[0].get_center()
	collision = Rules.step(collision, Vector2.ZERO, 0.016)
	assert(bool(collision["failed"]) and str(collision["reason"]) == "obstacle", "Obstacle collision fails the mission")

	var victory: Dictionary = Rules.new_game(1)
	victory["position"] = Rules.PAD_POSITION
	victory["velocity"] = Vector2.ZERO
	victory["rescued"] = [true, true, true]
	victory = Rules.step(victory, Vector2.ZERO, 0.016)
	assert(bool(victory["won"]), "All survivors plus a safe landing wins the mission")

	var locked: Dictionary = Rules.step(victory, Vector2.RIGHT, 0.1)
	var locked_position: Vector2 = locked["position"]
	assert(locked_position.is_equal_approx(Rules.PAD_POSITION), "Terminal state ignores further input")
	print("KROLL Rotor Rescue rules tests passed.")
	quit(0)
