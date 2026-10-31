extends RefCounted
class_name ConveyorArchitectRules

const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 6
const DIRECTION_UP: int = 0
const DIRECTION_RIGHT: int = 1
const DIRECTION_DOWN: int = 2
const DIRECTION_LEFT: int = 3
const DIRECTION_VECTORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const DIRECTION_GLYPHS: Array[String] = ["↑", "→", "↓", "←"]

const LEVELS := [
	{
		"id": "dock_line",
		"title": "Dock Line",
		"start": Vector2i(0, 2),
		"goal": Vector2i(5, 2),
		"walls": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)],
		"solution": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(5, 2)]
	},
	{
		"id": "coolant_bend",
		"title": "Coolant Bend",
		"start": Vector2i(0, 5),
		"goal": Vector2i(5, 0),
		"walls": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(3, 4), Vector2i(3, 2), Vector2i(4, 0)],
		"solution": [Vector2i(0, 5), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 0)]
	},
	{
		"id": "core_archive",
		"title": "Core Archive",
		"start": Vector2i(5, 5),
		"goal": Vector2i(0, 0),
		"walls": [Vector2i(4, 5), Vector2i(3, 5), Vector2i(2, 4), Vector2i(2, 2), Vector2i(0, 2), Vector2i(4, 2), Vector2i(5, 2)],
		"solution": [Vector2i(5, 5), Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)]
	}
]

static func get_level_count() -> int:
	return LEVELS.size()

static func get_level_data(level_index: int) -> Dictionary:
	if level_index < 0 or level_index >= LEVELS.size():
		return {}
	return LEVELS[level_index].duplicate(true)

static func create_state(level_index: int) -> Dictionary:
	var level: Dictionary = get_level_data(level_index)
	if level.is_empty():
		return {}
	var path: Array = level.get("solution", [])
	var start: Vector2i = level.get("start", Vector2i.ZERO)
	var walls: Array = level.get("walls", [])
	return {
		"level_index": level_index,
		"level_id": str(level.get("id", "")),
		"title": str(level.get("title", "")),
		"start": start,
		"goal": level.get("goal", Vector2i.ZERO),
		"walls": walls.duplicate(true),
		"position": start,
		"conveyors": {},
		"visited": [start],
		"placements_used": 0,
		"placement_budget": maxi(0, path.size() - 1),
		"steps": 0,
		"max_steps": path.size() + 1,
		"status": "planning",
		"message": "Select a cell and set its conveyor direction."
	}

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func direction_between(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var delta: Vector2i = to_cell - from_cell
	for direction in range(DIRECTION_VECTORS.size()):
		if DIRECTION_VECTORS[direction] == delta:
			return direction
	return -1

static func get_solution_path(level_index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var level: Dictionary = get_level_data(level_index)
	for cell_value in level.get("solution", []):
		var cell: Vector2i = cell_value
		result.append(cell)
	return result

static func get_conveyor_direction(state: Dictionary, cell: Vector2i) -> int:
	var conveyors: Dictionary = state.get("conveyors", {})
	return int(conveyors.get(cell_key(cell), -1))

static func place_conveyor(state: Dictionary, cell: Vector2i, direction: int) -> Dictionary:
	if state.is_empty():
		return {"ok": false, "reason": "invalid_state"}
	if str(state.get("status", "")) in ["delivered", "jammed"]:
		return {"ok": false, "reason": "round_finished"}
	if not _is_inside(cell):
		return {"ok": false, "reason": "out_of_bounds"}
	var walls: Array = state.get("walls", [])
	if walls.has(cell):
		return {"ok": false, "reason": "blocked_cell"}
	if cell == state.get("goal", Vector2i(-1, -1)):
		return {"ok": false, "reason": "goal_cell"}
	if direction < 0 or direction >= DIRECTION_VECTORS.size():
		return {"ok": false, "reason": "invalid_direction"}
	var conveyors: Dictionary = state.get("conveyors", {})
	var key: String = cell_key(cell)
	if not conveyors.has(key):
		var used: int = int(state.get("placements_used", 0))
		var budget: int = int(state.get("placement_budget", 0))
		if used >= budget:
			return {"ok": false, "reason": "placement_budget_exhausted"}
		state["placements_used"] = used + 1
	conveyors[key] = direction
	state["conveyors"] = conveyors
	if str(state.get("status", "")) == "stalled":
		state["status"] = "planning"
	state["message"] = "Conveyor set at (%d, %d)." % [cell.x, cell.y]
	return {"ok": true, "reason": "placed", "direction": direction}

static func advance(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {"ok": false, "reason": "invalid_state"}
	if str(state.get("status", "")) in ["delivered", "jammed"]:
		return {"ok": false, "reason": "round_finished"}
	var current: Vector2i = state.get("position", Vector2i.ZERO)
	var direction: int = get_conveyor_direction(state, current)
	if direction < 0:
		state["status"] = "stalled"
		state["message"] = "Cargo is waiting: place a conveyor under its current cell."
		return {"ok": false, "reason": "missing_conveyor"}
	var next_cell: Vector2i = current + DIRECTION_VECTORS[direction]
	state["steps"] = int(state.get("steps", 0)) + 1
	if int(state["steps"]) > int(state.get("max_steps", 0)):
		state["status"] = "jammed"
		state["message"] = "JAM: route exceeded its step limit."
		return {"ok": false, "reason": "step_limit"}
	if not _is_inside(next_cell):
		state["status"] = "jammed"
		state["message"] = "JAM: cargo left the factory grid."
		return {"ok": false, "reason": "out_of_bounds"}
	var walls: Array = state.get("walls", [])
	if walls.has(next_cell):
		state["status"] = "jammed"
		state["message"] = "JAM: cargo hit a blocked cell."
		return {"ok": false, "reason": "wall_collision"}
	var visited: Array = state.get("visited", [])
	if visited.has(next_cell):
		state["status"] = "jammed"
		state["message"] = "JAM: conveyor loop detected."
		return {"ok": false, "reason": "route_loop"}
	state["position"] = next_cell
	visited.append(next_cell)
	state["visited"] = visited
	if next_cell == state.get("goal", Vector2i(-1, -1)):
		state["status"] = "delivered"
		state["message"] = "DELIVERED: cargo reached the receiving dock."
	else:
		state["status"] = "running"
		state["message"] = "Cargo advanced to (%d, %d)." % [next_cell.x, next_cell.y]
	return {"ok": true, "reason": "delivered" if str(state["status"]) == "delivered" else "advanced", "position": next_cell}

static func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT
