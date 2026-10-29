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
	_test_layout_reachability()
	print("KROLL Rotor Rescue rules tests passed.")
	quit(0)

func _test_layout_reachability() -> void:
	for seed_value in [1, 2, 3]:
		var targets: Array[Vector2] = Rules.survivor_positions(seed_value)
		targets.append(Rules.PAD_POSITION)
		var current := Vector2(70.0, 250.0)
		for target in targets:
			assert(_grid_reachable(current, target, seed_value), "Seed %d must have a grid path to each survivor and the extraction pad" % seed_value)
			current = target

func _grid_reachable(start: Vector2, goal: Vector2, seed_value: int) -> bool:
	const GRID_STEP: int = 20
	var start_cell := Vector2i(roundi(start.x / GRID_STEP), roundi(start.y / GRID_STEP))
	var goal_cell := Vector2i(roundi(goal.x / GRID_STEP), roundi(goal.y / GRID_STEP))
	var queue: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {}
	visited[start_cell] = true
	var cursor: int = 0
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var point := Vector2(float(cell.x * GRID_STEP), float(cell.y * GRID_STEP))
		if point.distance_to(goal) <= float(GRID_STEP) * 1.5:
			return true
		for direction in directions:
			var next_cell := cell + direction
			if visited.has(next_cell):
				continue
			var next_point := Vector2(float(next_cell.x * GRID_STEP), float(next_cell.y * GRID_STEP))
			if not _grid_point_is_free(next_point, seed_value):
				continue
			if direction.x != 0 and direction.y != 0:
				var horizontal := Vector2(float((cell.x + direction.x) * GRID_STEP), float(cell.y * GRID_STEP))
				var vertical := Vector2(float(cell.x * GRID_STEP), float((cell.y + direction.y) * GRID_STEP))
				if not _grid_point_is_free(horizontal, seed_value) or not _grid_point_is_free(vertical, seed_value):
					continue
			visited[next_cell] = true
			queue.append(next_cell)
	return false

func _grid_point_is_free(point: Vector2, seed_value: int) -> bool:
	const MARGIN: float = 18.0
	if point.x < Rules.WORLD_MIN.x + MARGIN or point.y < Rules.WORLD_MIN.y + MARGIN or point.x > Rules.WORLD_MAX.x - MARGIN or point.y > Rules.WORLD_MAX.y - MARGIN:
		return false
	for obstacle: Rect2 in Rules.obstacle_rects(seed_value):
		var inflated := Rect2(obstacle.position - Vector2(MARGIN, MARGIN), obstacle.size + Vector2(MARGIN * 2.0, MARGIN * 2.0))
		if inflated.has_point(point):
			return false
	return true
