extends RefCounted
class_name PrismBeamRules

const GRID_SIZE := 7
const MAX_TRACE_STEPS := 196
const LEVELS := [
	{
		"name": "Service Bend",
		"emitter": Vector2i(0, 3),
		"direction": Vector2i(1, 0),
		"receiver": Vector2i(6, 3),
		"mirror_positions": [Vector2i(2, 3), Vector2i(2, 1), Vector2i(4, 1), Vector2i(4, 3)],
		"initial_orientations": [1, 0, 0, 1],
		"solution_orientations": [0, 0, 1, 1],
		"walls": [Vector2i(3, 3), Vector2i(3, 2), Vector2i(5, 4), Vector2i(1, 5)],
		"par": 2
	},
	{
		"name": "Coolant Bypass",
		"emitter": Vector2i(0, 5),
		"direction": Vector2i(1, 0),
		"receiver": Vector2i(6, 5),
		"mirror_positions": [Vector2i(1, 5), Vector2i(1, 2), Vector2i(5, 2), Vector2i(5, 5)],
		"initial_orientations": [0, 1, 1, 1],
		"solution_orientations": [0, 0, 1, 1],
		"walls": [Vector2i(3, 5), Vector2i(3, 4), Vector2i(4, 6), Vector2i(2, 0)],
		"par": 1
	},
	{
		"name": "Vertical Relay",
		"emitter": Vector2i(3, 6),
		"direction": Vector2i(0, -1),
		"receiver": Vector2i(3, 0),
		"mirror_positions": [Vector2i(3, 4), Vector2i(1, 4), Vector2i(1, 2), Vector2i(3, 2)],
		"initial_orientations": [0, 1, 1, 0],
		"solution_orientations": [1, 1, 0, 0],
		"walls": [Vector2i(3, 3), Vector2i(5, 4), Vector2i(0, 1)],
		"par": 2
	}
]

static func level_count() -> int:
	return LEVELS.size()

static func get_level(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

static func get_initial_orientations(level: Dictionary) -> Array:
	return level.get("initial_orientations", []).duplicate()

static func get_solution_orientations(level: Dictionary) -> Array:
	return level.get("solution_orientations", []).duplicate()

static func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE and cell.y < GRID_SIZE

static func is_valid_orientations(level: Dictionary, orientations: Array) -> bool:
	var mirror_positions: Array = level.get("mirror_positions", [])
	if mirror_positions.is_empty() or orientations.size() != mirror_positions.size():
		return false
	for orientation in orientations:
		if int(orientation) != 0 and int(orientation) != 1:
			return false
	return true

static func rotate_orientation(orientation: int) -> int:
	if orientation != 0 and orientation != 1:
		return -1
	return 1 - orientation

static func reflect_direction(direction: Vector2i, orientation: int) -> Vector2i:
	if orientation == 0:
		return Vector2i(-direction.y, -direction.x)
	if orientation == 1:
		return Vector2i(direction.y, direction.x)
	return Vector2i.ZERO

static func direction_glyph(direction: Vector2i) -> String:
	if direction == Vector2i(1, 0):
		return "→"
	if direction == Vector2i(-1, 0):
		return "←"
	if direction == Vector2i(0, 1):
		return "↓"
	if direction == Vector2i(0, -1):
		return "↑"
	return "?"

static func trace(level: Dictionary, orientations: Array) -> Dictionary:
	if level.is_empty() or not is_valid_orientations(level, orientations):
		return {"success": false, "reason": "invalid_state", "steps": 0, "path": []}
	var position: Vector2i = level.get("emitter", Vector2i(-1, -1))
	var direction: Vector2i = level.get("direction", Vector2i.ZERO)
	var receiver: Vector2i = level.get("receiver", Vector2i(-1, -1))
	if not is_valid_cell(position) or not is_valid_cell(receiver) or direction == Vector2i.ZERO:
		return {"success": false, "reason": "invalid_layout", "steps": 0, "path": []}
	var walls: Array = level.get("walls", [])
	var mirror_positions: Array = level.get("mirror_positions", [])
	var path: Array = [position]
	var visited_states: Dictionary = {}
	for step in range(MAX_TRACE_STEPS):
		position += direction
		if position == receiver:
			path.append(position)
			return {"success": true, "reason": "receiver", "steps": step + 1, "path": path}
		if not is_valid_cell(position):
			path.append(position)
			return {"success": false, "reason": "out_of_bounds", "steps": step + 1, "path": path}
		path.append(position)
		if walls.has(position):
			return {"success": false, "reason": "wall", "steps": step + 1, "path": path}
		var mirror_index: int = mirror_positions.find(position)
		if mirror_index >= 0:
			var orientation: int = int(orientations[mirror_index])
			var state_key := "%d,%d:%d,%d:%d" % [position.x, position.y, direction.x, direction.y, orientation]
			if visited_states.has(state_key):
				return {"success": false, "reason": "loop", "steps": step + 1, "path": path}
			visited_states[state_key] = true
			direction = reflect_direction(direction, orientation)
	return {"success": false, "reason": "step_limit", "steps": MAX_TRACE_STEPS, "path": path}

static func has_unique_solution(level: Dictionary) -> bool:
	var mirror_positions: Array = level.get("mirror_positions", [])
	if mirror_positions.is_empty() or mirror_positions.size() > 12:
		return false
	var solution_count := 0
	for mask in range(1 << mirror_positions.size()):
		var candidate: Array = []
		for index in range(mirror_positions.size()):
			candidate.append((mask >> index) & 1)
		if bool(trace(level, candidate).get("success", false)):
			solution_count += 1
			if solution_count > 1:
				return false
	return solution_count == 1

static func score_for_moves(moves: int, par: int) -> int:
	if moves < 0 or par < 0:
		return 0
	return 100 if moves <= par else 75
