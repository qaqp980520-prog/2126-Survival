extends RefCounted
## Deterministic 5x5 knight's-tour puzzle rules.
const BOARD_SIZE: int = 5
const CELL_COUNT: int = BOARD_SIZE * BOARD_SIZE
const LEVELS: Array[Dictionary] = [
	{"id":"hangar_circuit","name":"Hangar Circuit","start":Vector2i(0,0),"solution":[Vector2i(0,0),Vector2i(2,1),Vector2i(4,0),Vector2i(3,2),Vector2i(4,4),Vector2i(2,3),Vector2i(0,4),Vector2i(1,2),Vector2i(3,3),Vector2i(1,4),Vector2i(0,2),Vector2i(1,0),Vector2i(3,1),Vector2i(4,3),Vector2i(2,4),Vector2i(0,3),Vector2i(1,1),Vector2i(3,0),Vector2i(4,2),Vector2i(3,4),Vector2i(1,3),Vector2i(0,1),Vector2i(2,0),Vector2i(4,1),Vector2i(2,2)]},
	{"id":"reactor_circuit","name":"Reactor Circuit","start":Vector2i(2,2),"solution":[Vector2i(2,2),Vector2i(3,0),Vector2i(1,1),Vector2i(0,3),Vector2i(2,4),Vector2i(4,3),Vector2i(3,1),Vector2i(1,0),Vector2i(0,2),Vector2i(1,4),Vector2i(3,3),Vector2i(4,1),Vector2i(2,0),Vector2i(0,1),Vector2i(1,3),Vector2i(3,4),Vector2i(4,2),Vector2i(2,3),Vector2i(4,4),Vector2i(3,2),Vector2i(4,0),Vector2i(2,1),Vector2i(0,0),Vector2i(1,2),Vector2i(0,4)]},
	{"id":"canyon_circuit","name":"Canyon Circuit","start":Vector2i(4,0),"solution":[Vector2i(4,0),Vector2i(3,2),Vector2i(4,4),Vector2i(2,3),Vector2i(0,4),Vector2i(1,2),Vector2i(0,0),Vector2i(2,1),Vector2i(4,2),Vector2i(3,4),Vector2i(1,3),Vector2i(0,1),Vector2i(2,0),Vector2i(4,1),Vector2i(3,3),Vector2i(1,4),Vector2i(0,2),Vector2i(1,0),Vector2i(3,1),Vector2i(4,3),Vector2i(2,4),Vector2i(0,3),Vector2i(1,1),Vector2i(3,0),Vector2i(2,2)]}
]
static func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)].duplicate(true)
static func new_game(level_index: int = 0) -> Dictionary:
	var safe_index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = get_level(safe_index)
	var start: Vector2i = level["start"]
	return {"level_index":safe_index,"level_id":str(level["id"]),"position":start,"visited":[start],"moves":0,"status":"playing"}
static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE and cell.y < BOARD_SIZE
static func is_knight_move(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var dx: int = absi(to_cell.x - from_cell.x)
	var dy: int = absi(to_cell.y - from_cell.y)
	return (dx == 1 and dy == 2) or (dx == 2 and dy == 1)
static func can_move(state: Dictionary, target: Vector2i) -> bool:
	if str(state.get("status", "")) != "playing" or not is_in_bounds(target):
		return false
	var current: Vector2i = state.get("position", Vector2i(-1,-1))
	if not is_knight_move(current, target):
		return false
	var visited: Array = state.get("visited", [])
	return not visited.has(target)
static func move(state: Dictionary, target: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if not can_move(next, target):
		return next
	var visited: Array = next.get("visited", []).duplicate()
	visited.append(target)
	next["visited"] = visited
	next["position"] = target
	next["moves"] = visited.size() - 1
	if visited.size() == CELL_COUNT:
		next["status"] = "complete"
	return next
static func undo(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var visited: Array = next.get("visited", []).duplicate()
	if visited.size() <= 1:
		return next
	visited.pop_back()
	next["visited"] = visited
	next["position"] = visited[visited.size() - 1]
	next["moves"] = visited.size() - 1
	next["status"] = "playing"
	return next
static func reset(state: Dictionary) -> Dictionary:
	return new_game(int(state.get("level_index", 0)))
static func next_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return state.duplicate(true)
	return new_game((int(state.get("level_index", 0)) + 1) % LEVELS.size())
static func solution_next_move(state: Dictionary) -> Vector2i:
	var level: Dictionary = get_level(int(state.get("level_index", 0)))
	var solution: Array = level.get("solution", [])
	var visited: Array = state.get("visited", [])
	if visited.size() >= solution.size():
		return Vector2i(-1, -1)
	for index in range(visited.size()):
		if visited[index] != solution[index]:
			return Vector2i(-1, -1)
	return solution[visited.size()]
static func validate_solution(solution: Array) -> bool:
	if solution.size() != CELL_COUNT:
		return false
	var seen: Dictionary = {}
	for index in range(solution.size()):
		var cell_value: Variant = solution[index]
		if not (cell_value is Vector2i) or not is_in_bounds(cell_value):
			return false
		var cell: Vector2i = cell_value
		if seen.has(cell):
			return false
		seen[cell] = true
		if index > 0 and not is_knight_move(solution[index - 1], cell):
			return false
	return seen.size() == CELL_COUNT
