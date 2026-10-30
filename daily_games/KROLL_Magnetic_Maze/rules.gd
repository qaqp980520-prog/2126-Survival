extends RefCounted
class_name MagneticMazeRules

const BOARD_SIZE: int = 7
const MOVE_LIMIT: int = 40
const LEVEL_COUNT: int = 3

static func create_state(level_index: int) -> Dictionary:
	var index: int = posmod(level_index, LEVEL_COUNT)
	var player_position: Vector2i
	var crate_position: Vector2i
	var goal_position: Vector2i
	var walls: Array[Vector2i] = []
	var charges: int = 3
	match index:
		0:
			player_position = Vector2i(0, 3)
			crate_position = Vector2i(2, 3)
			goal_position = Vector2i(5, 3)
			walls = [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 4), Vector2i(3, 5)]
			charges = 3
		1:
			player_position = Vector2i(1, 5)
			crate_position = Vector2i(3, 3)
			goal_position = Vector2i(5, 1)
			walls = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 5)]
			charges = 4
		_:
			player_position = Vector2i(0, 1)
			crate_position = Vector2i(1, 1)
			goal_position = Vector2i(5, 5)
			walls = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]
			charges = 8
	return {
		"level_index": index,
		"player": player_position,
		"crate": crate_position,
		"goal": goal_position,
		"walls": walls,
		"facing": Vector2i.RIGHT,
		"mode": "push",
		"charges": charges,
		"moves": 0,
		"move_limit": MOVE_LIMIT
	}


static func get_level_name(level_index: int) -> String:
	match posmod(level_index, LEVEL_COUNT):
		0:
			return "DOCKSIDE STRAIGHT"
		1:
			return "CORNER TRANSFER"
		_:
			return "SPLIT-LEVEL ROUTE"


static func get_status(state: Dictionary) -> String:
	if state.get("crate", Vector2i(-1, -1)) == state.get("goal", Vector2i(-2, -2)):
		return "won"
	if int(state.get("charges", 0)) <= 0:
		return "out_of_charges"
	if int(state.get("moves", 0)) >= int(state.get("move_limit", MOVE_LIMIT)):
		return "out_of_moves"
	return "active"


static func move_player(state: Dictionary, direction: Vector2i) -> Dictionary:
	if get_status(state) != "active":
		return _result(false, false, "terminal", state)
	if not _is_cardinal(direction):
		return _result(false, false, "invalid_direction", state)
	var next_state: Dictionary = state.duplicate(true)
	next_state["facing"] = direction
	var destination: Vector2i = Vector2i(state["player"]) + direction
	if not _in_bounds(destination) or _walls(state).has(destination) or destination == Vector2i(state["crate"]):
		return _result(true, false, "blocked_turn", next_state)
	next_state["player"] = destination
	next_state["moves"] = int(state["moves"]) + 1
	return _result(true, true, "moved", next_state)


static func toggle_mode(state: Dictionary) -> Dictionary:
	if get_status(state) != "active":
		return _result(false, false, "terminal", state)
	var next_state: Dictionary = state.duplicate(true)
	next_state["mode"] = "pull" if str(state.get("mode", "push")) == "push" else "push"
	return _result(true, false, "mode_changed", next_state)


static func pulse(state: Dictionary) -> Dictionary:
	if get_status(state) != "active":
		return _result(false, false, "terminal", state)
	var direction: Vector2i = Vector2i(state.get("facing", Vector2i.ZERO))
	if not _is_cardinal(direction):
		return _result(false, false, "invalid_facing", state)
	var player_position: Vector2i = Vector2i(state["player"])
	var crate_position: Vector2i = Vector2i(state["crate"])
	var cursor: Vector2i = player_position + direction
	var found_crate: bool = false
	while _in_bounds(cursor):
		if _walls(state).has(cursor):
			break
		if cursor == crate_position:
			found_crate = true
			break
		cursor += direction
	if not found_crate:
		return _result(false, false, "no_target", state)
	var destination: Vector2i = crate_position + direction if str(state.get("mode", "push")) == "push" else crate_position - direction
	if not _in_bounds(destination) or _walls(state).has(destination) or destination == player_position:
		return _result(false, false, "blocked", state)
	var next_state: Dictionary = state.duplicate(true)
	next_state["crate"] = destination
	next_state["charges"] = int(state["charges"]) - 1
	next_state["moves"] = int(state["moves"]) + 1
	return _result(true, true, "pulsed", next_state)


static func _result(ok: bool, moved: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "moved": moved, "reason": reason, "state": state.duplicate(true)}


static func _walls(state: Dictionary) -> Array:
	var value: Variant = state.get("walls", [])
	return value if value is Array else []


static func _in_bounds(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < BOARD_SIZE and position.y >= 0 and position.y < BOARD_SIZE


static func _is_cardinal(direction: Vector2i) -> bool:
	return abs(direction.x) + abs(direction.y) == 1
