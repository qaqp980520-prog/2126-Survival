extends RefCounted
class_name DroneRelayRules

const BOARD_SIZE: int = 6
const DRONE_COUNT: int = 3
const LEVEL_COUNT: int = 3
const INITIAL_BATTERY: int = 9
const MAX_TICKS: int = 9

static func create_state(level_index: int) -> Dictionary:
	var index: int = posmod(level_index, LEVEL_COUNT)
	var starts: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, 2),
		Vector2i(0, 4)
	]
	var goals: Array[Vector2i] = []
	var walls: Array[Vector2i] = []
	match index:
		0:
			goals = [Vector2i(5, 0), Vector2i(5, 2), Vector2i(5, 4)]
			walls = [Vector2i(2, 1), Vector2i(2, 3)]
		1:
			goals = [Vector2i(5, 0), Vector2i(5, 2), Vector2i(5, 4)]
			walls = [Vector2i(2, 0), Vector2i(2, 2), Vector2i(2, 4)]
		_:
			goals = [Vector2i(5, 1), Vector2i(5, 3), Vector2i(5, 5)]
			walls = [Vector2i(3, 0), Vector2i(2, 2), Vector2i(4, 4)]
	var drones: Array[Dictionary] = []
	for index_drone in range(DRONE_COUNT):
		drones.append({
			"id": ["A", "B", "C"][index_drone],
			"position": starts[index_drone],
			"goal": goals[index_drone],
			"battery": INITIAL_BATTERY
		})
	return {
		"level_index": index,
		"drones": drones,
		"walls": walls,
		"commands": [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO],
		"ticks": 0,
		"max_ticks": MAX_TICKS,
		"collisions": 0
	}


static func get_level_name(level_index: int) -> String:
	match posmod(level_index, LEVEL_COUNT):
		0:
			return "PARALLEL APPROACH"
		1:
			return "CARGO DETOURS"
		_:
			return "OFFSET LANDING"


static func get_status(state: Dictionary) -> String:
	var drones: Array = state.get("drones", [])
	if drones.size() != DRONE_COUNT:
		return "invalid_state"
	var all_reached: bool = true
	for drone_value in drones:
		if not (drone_value is Dictionary):
			return "invalid_state"
		var drone: Dictionary = drone_value
		if Vector2i(drone.get("position", Vector2i(-1, -1))) != Vector2i(drone.get("goal", Vector2i(-2, -2))):
			all_reached = false
			if int(drone.get("battery", 0)) <= 0:
				return "out_of_battery"
	if all_reached:
		return "won"
	if int(state.get("ticks", 0)) >= int(state.get("max_ticks", MAX_TICKS)):
		return "out_of_ticks"
	return "active"


static func set_command(state: Dictionary, drone_index: int, direction: Vector2i) -> Dictionary:
	if get_status(state) != "active":
		return _result(false, false, "terminal", state)
	if drone_index < 0 or drone_index >= DRONE_COUNT:
		return _result(false, false, "invalid_drone", state)
	if direction != Vector2i.ZERO and not _is_cardinal(direction):
		return _result(false, false, "invalid_direction", state)
	var drones: Array = state.get("drones", [])
	if drones.size() != DRONE_COUNT:
		return _result(false, false, "invalid_state", state)
	var selected: Dictionary = drones[drone_index]
	if Vector2i(selected.get("position", Vector2i.ZERO)) == Vector2i(selected.get("goal", Vector2i(-1, -1))) and direction != Vector2i.ZERO:
		return _result(false, false, "drone_landed", state)
	var next_state: Dictionary = state.duplicate(true)
	var commands: Array = next_state.get("commands", []).duplicate(true)
	if commands.size() != DRONE_COUNT:
		return _result(false, false, "invalid_state", state)
	commands[drone_index] = direction
	next_state["commands"] = commands
	return _result(true, false, "command_set", next_state)


static func step(state: Dictionary) -> Dictionary:
	if get_status(state) != "active":
		return _result(false, false, "terminal", state)
	var drones: Array = state.get("drones", [])
	var commands: Array = state.get("commands", [])
	if drones.size() != DRONE_COUNT or commands.size() != DRONE_COUNT:
		return _result(false, false, "invalid_state", state)
	var walls: Array = state.get("walls", [])
	var positions: Array[Vector2i] = []
	var destinations: Array[Vector2i] = []
	var moving: Array[bool] = []
	for index_drone in range(DRONE_COUNT):
		var drone: Dictionary = drones[index_drone]
		var position: Vector2i = Vector2i(drone.get("position", Vector2i.ZERO))
		var goal: Vector2i = Vector2i(drone.get("goal", Vector2i(-1, -1)))
		var command: Vector2i = Vector2i(commands[index_drone])
		var destination: Vector2i = position
		var will_move: bool = false
		if position != goal and command != Vector2i.ZERO and int(drone.get("battery", 0)) > 0:
			if not _is_cardinal(command):
				return _result(false, false, "invalid_command", state)
			var candidate: Vector2i = position + command
			if _in_bounds(candidate) and not walls.has(candidate):
				destination = candidate
				will_move = true
		positions.append(position)
		destinations.append(destination)
		moving.append(will_move)

	var collision_blocked: Array[bool] = [false, false, false]
	var changed: bool = true
	while changed:
		changed = false
		for first in range(DRONE_COUNT):
			for second in range(first + 1, DRONE_COUNT):
				var first_moves: bool = moving[first] and not collision_blocked[first]
				var second_moves: bool = moving[second] and not collision_blocked[second]
				if first_moves and second_moves:
					if destinations[first] == destinations[second] or (destinations[first] == positions[second] and destinations[second] == positions[first]):
						collision_blocked[first] = true
						collision_blocked[second] = true
						changed = true
				elif first_moves and destinations[first] == positions[second]:
					collision_blocked[first] = true
					changed = true
				elif second_moves and destinations[second] == positions[first]:
					collision_blocked[second] = true
					changed = true

	var next_state: Dictionary = state.duplicate(true)
	var next_drones: Array = next_state.get("drones", []).duplicate(true)
	var collision_count: int = int(next_state.get("collisions", 0))
	var moved_any: bool = false
	for index_drone in range(DRONE_COUNT):
		if collision_blocked[index_drone]:
			collision_count += 1
			continue
		if moving[index_drone]:
			var updated: Dictionary = next_drones[index_drone]
			updated["position"] = destinations[index_drone]
			updated["battery"] = int(updated.get("battery", 0)) - 1
			next_drones[index_drone] = updated
			moved_any = true
	next_state["drones"] = next_drones
	next_state["collisions"] = collision_count
	next_state["ticks"] = int(next_state.get("ticks", 0)) + 1
	next_state["commands"] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
	return _result(true, moved_any, "tick_committed", next_state)


static func command_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "UP"
	if direction == Vector2i.RIGHT:
		return "RIGHT"
	if direction == Vector2i.DOWN:
		return "DOWN"
	if direction == Vector2i.LEFT:
		return "LEFT"
	return "HOLD"


static func _result(ok: bool, moved: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "moved": moved, "reason": reason, "state": state.duplicate(true)}


static func _is_cardinal(direction: Vector2i) -> bool:
	return abs(direction.x) + abs(direction.y) == 1


static func _in_bounds(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < BOARD_SIZE and position.y >= 0 and position.y < BOARD_SIZE
