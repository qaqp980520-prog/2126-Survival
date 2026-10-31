extends RefCounted
class_name GravityFoundryRules

const GRID_SIZE: int = 7
const MAX_TURNS: int = 30
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const GRAVITY_NAMES: Array[String] = ["UP", "RIGHT", "DOWN", "LEFT"]
const LEVELS: Array[Dictionary] = [
	{
		"id": "reactor_bay",
		"title": "Reactor Bay",
		"player_start": Vector2i(1, 5),
		"crate_start": Vector2i(2, 2),
		"gravity": 2,
		"plate": Vector2i(5, 5),
		"exit": Vector2i(5, 1),
		"walls": [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]
	},
	{
		"id": "coolant_vault",
		"title": "Coolant Vault",
		"player_start": Vector2i(1, 1),
		"crate_start": Vector2i(5, 1),
		"gravity": 3,
		"plate": Vector2i(5, 5),
		"exit": Vector2i(1, 5),
		"walls": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	},
	{
		"id": "core_archive",
		"title": "Core Archive",
		"player_start": Vector2i(1, 5),
		"crate_start": Vector2i(5, 1),
		"gravity": 1,
		"plate": Vector2i(1, 1),
		"exit": Vector2i(5, 5),
		"walls": [
			Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3),
			Vector2i(5, 3), Vector2i(1, 4), Vector2i(5, 4), Vector2i(3, 5)
		]
	}
]

static func get_level_count() -> int:
	return LEVELS.size()

static func get_level_title(level_index: int) -> String:
	var index: int = clampi(level_index, 0, LEVELS.size() - 1)
	return str(LEVELS[index].get("title", "Unknown Sector"))

static func get_gravity_name(gravity: int) -> String:
	if gravity < 0 or gravity >= GRAVITY_NAMES.size():
		return "INVALID"
	return GRAVITY_NAMES[gravity]

static func new_game(level_index: int = 0) -> Dictionary:
	var index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = LEVELS[index]
	return {
		"level_index": index,
		"level_id": str(level["id"]),
		"player": level["player_start"],
		"crate": level["crate_start"],
		"gravity": int(level["gravity"]),
		"plate": level["plate"],
		"exit": level["exit"],
		"walls": _build_walls(level.get("walls", [])),
		"turns": 0,
		"status": "playing",
		"message": "Move the operator, rotate gravity, and settle the core on the pressure plate."
	}

static func apply_action(state: Dictionary, action: String) -> Dictionary:
	if state.is_empty() or not state.has("player") or not state.has("crate"):
		return _result(false, "invalid_state", state)
	if str(state.get("status", "")) != "playing":
		return _result(false, "terminal", state)

	var player: Vector2i = state.get("player", Vector2i(-1, -1))
	var crate: Vector2i = state.get("crate", Vector2i(-1, -1))
	var plate: Vector2i = state.get("plate", Vector2i(-1, -1))
	var walls: Array = state.get("walls", [])
	var gravity: int = int(state.get("gravity", -1))
	if gravity < 0 or gravity >= DIRECTIONS.size():
		return _result(false, "invalid_gravity", state)

	var next_player: Vector2i = player
	var next_crate: Vector2i = crate
	var next_gravity: int = gravity
	var direction_index: int = -1
	match action:
		"up":
			direction_index = 0
		"right":
			direction_index = 1
		"down":
			direction_index = 2
		"left":
			direction_index = 3
		"rotate_left":
			next_gravity = posmod(gravity - 1, DIRECTIONS.size())
		"rotate_right":
			next_gravity = posmod(gravity + 1, DIRECTIONS.size())
		_:
			return _result(false, "invalid_action", state)

	if direction_index >= 0:
		var direction: Vector2i = DIRECTIONS[direction_index]
		var destination: Vector2i = player + direction
		if _is_blocked(destination, walls):
			return _result(false, "blocked", state)
		if destination == crate:
			var pushed_destination: Vector2i = crate + direction
			if _is_blocked(pushed_destination, walls) or pushed_destination == player:
				return _result(false, "crate_blocked", state)
			next_crate = pushed_destination
		next_player = destination

	next_crate = _settle_crate(next_crate, next_player, walls, plate, next_gravity)
	if next_crate == next_player:
		return _result(false, "crate_collision", state)

	var next: Dictionary = state.duplicate(true)
	next["player"] = next_player
	next["crate"] = next_crate
	next["gravity"] = next_gravity
	next["turns"] = int(next.get("turns", 0)) + 1
	_resolve_terminal(next)
	return _result(true, action, next)

static func _resolve_terminal(state: Dictionary) -> void:
	if state.get("crate", Vector2i(-1, -1)) == state.get("plate", Vector2i(-2, -2)) and state.get("player", Vector2i(-1, -1)) == state.get("exit", Vector2i(-2, -2)):
		state["status"] = "won"
		state["message"] = "CORE SECURED. Operator reached the exit."
	elif int(state.get("turns", 0)) >= MAX_TURNS:
		state["status"] = "failed"
		state["message"] = "TURN LIMIT REACHED. Reset and plan a cleaner gravity route."
	else:
		state["status"] = "playing"
		state["message"] = "Gravity: %s. The exit unlocks when the core rests on the plate." % get_gravity_name(int(state.get("gravity", 0)))

static func _settle_crate(crate: Vector2i, player: Vector2i, walls: Array, plate: Vector2i, gravity: int) -> Vector2i:
	var direction: Vector2i = DIRECTIONS[gravity]
	var settled: Vector2i = crate
	while settled != plate:
		var destination: Vector2i = settled + direction
		if _is_blocked(destination, walls) or destination == player:
			break
		settled = destination
		if settled == plate:
			break
	return settled

static func _is_blocked(cell: Vector2i, walls: Array) -> bool:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
		return true
	return walls.has(cell)

static func _build_walls(interior_walls: Array) -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		walls.append(Vector2i(x, 0))
		walls.append(Vector2i(x, GRID_SIZE - 1))
	for y in range(1, GRID_SIZE - 1):
		walls.append(Vector2i(0, y))
		walls.append(Vector2i(GRID_SIZE - 1, y))
	for wall_value in interior_walls:
		if wall_value is Vector2i and not walls.has(wall_value):
			walls.append(wall_value)
	return walls

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}
