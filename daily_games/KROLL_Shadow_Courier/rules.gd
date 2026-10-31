extends RefCounted

const GRID_SIZE: int = 8
const MAX_DECOYS: int = 2
const GUARD_SIGHT_RANGE: int = 2
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func get_level_count() -> int:
	return 3

static func create_state(level_index: int = 0) -> Dictionary:
	var safe_level: int = posmod(level_index, get_level_count())
	var data: Dictionary = _level_data(safe_level)
	var guards: Array[Dictionary] = []
	for guard_data in data.get("guards", []):
		guards.append({
			"position": guard_data.get("position", Vector2i.ZERO),
			"facing": guard_data.get("facing", Vector2i.UP),
			"disabled_turns": 0
		})
	return {
		"level_index": safe_level,
		"walls": data.get("walls", []).duplicate(),
		"start": data.get("start", Vector2i.ZERO),
		"exit": data.get("exit", Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)),
		"shards": data.get("shards", []).duplicate(),
		"collected_shards": [],
		"guards": guards,
		"player_pos": data.get("start", Vector2i.ZERO),
		"decoys": MAX_DECOYS,
		"turn": 0,
		"status": "active",
		"message": "Collect every data shard, then reach the extraction point."
	}

static func move_player(state: Dictionary, direction: Vector2i) -> bool:
	if str(state.get("status", "active")) != "active" or not DIRECTIONS.has(direction):
		return false
	var target: Vector2i = state.get("player_pos", Vector2i.ZERO) + direction
	if not is_inside(target) or is_wall(state, target):
		state["message"] = "Blocked. Find another route."
		return false
	state["player_pos"] = target
	var shards: Array = state.get("shards", [])
	var collected: Array = state.get("collected_shards", [])
	if shards.has(target) and not collected.has(target):
		collected.append(target)
		state["collected_shards"] = collected
		state["message"] = "Data shard recovered."
	else:
		state["message"] = "Move complete."
	_advance_turn(state)
	return true

static func wait_turn(state: Dictionary) -> bool:
	if str(state.get("status", "active")) != "active":
		return false
	state["message"] = "You wait and watch the patrols."
	_advance_turn(state)
	return true

static func use_decoy(state: Dictionary) -> bool:
	if str(state.get("status", "active")) != "active" or int(state.get("decoys", 0)) <= 0:
		return false
	var player_position: Vector2i = state.get("player_pos", Vector2i.ZERO)
	var guards: Array = state.get("guards", [])
	var nearest_index: int = -1
	var nearest_distance: int = 6
	for index in range(guards.size()):
		var guard: Dictionary = guards[index]
		if int(guard.get("disabled_turns", 0)) > 0:
			continue
		var guard_position: Vector2i = guard.get("position", Vector2i.ZERO)
		var distance: int = absi(player_position.x - guard_position.x) + absi(player_position.y - guard_position.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0:
		state["message"] = "No patrol is close enough to distract."
		return false
	var selected_guard: Dictionary = guards[nearest_index]
	selected_guard["disabled_turns"] = 2
	state["decoys"] = int(state.get("decoys", 0)) - 1
	state["message"] = "Decoy deployed. The nearest patrol is distracted."
	_advance_turn(state)
	return true

static func get_guard_sight_tiles(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for guard_value in state.get("guards", []):
		if not (guard_value is Dictionary) or int(guard_value.get("disabled_turns", 0)) > 0:
			continue
		var guard: Dictionary = guard_value
		var position: Vector2i = guard.get("position", Vector2i.ZERO)
		var facing: Vector2i = guard.get("facing", Vector2i.UP)
		for distance in range(1, GUARD_SIGHT_RANGE + 1):
			var tile: Vector2i = position + facing * distance
			if not is_inside(tile) or is_wall(state, tile):
				break
			if not result.has(tile):
				result.append(tile)
	return result

static func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < GRID_SIZE and tile.y < GRID_SIZE

static func is_wall(state: Dictionary, tile: Vector2i) -> bool:
	return (state.get("walls", []) as Array).has(tile)

static func reset(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("level_index", 0)))

static func next_level(state: Dictionary) -> Dictionary:
	return create_state(int(state.get("level_index", 0)) + 1)

static func _advance_turn(state: Dictionary) -> void:
	state["turn"] = int(state.get("turn", 0)) + 1
	var guards: Array = state.get("guards", [])
	var disabled_at_start: Array[bool] = []
	for guard_value in guards:
		var guard: Dictionary = guard_value
		var disabled: bool = int(guard.get("disabled_turns", 0)) > 0
		disabled_at_start.append(disabled)
		if not disabled:
			guard["facing"] = _rotate_clockwise(guard.get("facing", Vector2i.UP))
	_check_status(state)
	for index in range(mini(guards.size(), disabled_at_start.size())):
		if disabled_at_start[index]:
			var guard: Dictionary = guards[index]
			guard["disabled_turns"] = maxi(0, int(guard.get("disabled_turns", 0)) - 1)

static func _check_status(state: Dictionary) -> void:
	if str(state.get("status", "active")) != "active":
		return
	var player_position: Vector2i = state.get("player_pos", Vector2i.ZERO)
	for guard_value in state.get("guards", []):
		var guard: Dictionary = guard_value
		var guard_position: Vector2i = guard.get("position", Vector2i.ZERO)
		if player_position == guard_position:
			state["status"] = "detected"
			state["message"] = "A patrol caught you. Reset and try a different route."
			return
		if int(guard.get("disabled_turns", 0)) > 0:
			continue
		var facing: Vector2i = guard.get("facing", Vector2i.UP)
		for distance in range(1, GUARD_SIGHT_RANGE + 1):
			var sight_tile: Vector2i = guard_position + facing * distance
			if not is_inside(sight_tile) or is_wall(state, sight_tile):
				break
			if sight_tile == player_position:
				state["status"] = "detected"
				state["message"] = "You entered a patrol's line of sight."
				return
	var shards: Array = state.get("shards", [])
	var collected: Array = state.get("collected_shards", [])
	if player_position == state.get("exit", Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)) and collected.size() == shards.size():
		state["status"] = "complete"
		state["message"] = "Extraction successful. All intelligence recovered."

static func _rotate_clockwise(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)

static func _level_data(level_index: int) -> Dictionary:
	match level_index:
		0:
			return {
				"start": Vector2i(0, 0),
				"exit": Vector2i(7, 7),
				"shards": [Vector2i(1, 3), Vector2i(4, 2), Vector2i(6, 6)],
				"walls": [
					Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 4), Vector2i(2, 5),
					Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 5), Vector2i(5, 6),
					Vector2i(3, 5), Vector2i(4, 5)
				],
				"guards": [
					{"position": Vector2i(4, 0), "facing": Vector2i.DOWN},
					{"position": Vector2i(6, 4), "facing": Vector2i.LEFT}
				]
			}
		1:
			return {
				"start": Vector2i(0, 7),
				"exit": Vector2i(7, 0),
				"shards": [Vector2i(1, 4), Vector2i(4, 3), Vector2i(6, 1)],
				"walls": [
					Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
					Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4),
					Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)
				],
				"guards": [
					{"position": Vector2i(3, 3), "facing": Vector2i.RIGHT},
					{"position": Vector2i(6, 5), "facing": Vector2i.UP}
				]
			}
		_:
			return {
				"start": Vector2i(0, 0),
				"exit": Vector2i(7, 7),
				"shards": [Vector2i(1, 6), Vector2i(4, 4), Vector2i(6, 6)],
				"walls": [
					Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5),
					Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
					Vector2i(4, 5), Vector2i(5, 5)
				],
				"guards": [
					{"position": Vector2i(3, 1), "facing": Vector2i.DOWN},
					{"position": Vector2i(6, 4), "facing": Vector2i.LEFT},
					{"position": Vector2i(3, 6), "facing": Vector2i.UP}
				]
			}
