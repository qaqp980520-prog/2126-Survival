extends RefCounted
class_name StarChartRules

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 7
const START: Vector2i = Vector2i(0, 3)
const EXIT: Vector2i = Vector2i(6, 3)
const FUEL_START: int = 34
const TIME_LIMIT: float = 90.0
const BEACONS: Array[Vector2i] = [Vector2i(2, 1), Vector2i(5, 1), Vector2i(4, 5)]
const ASTEROIDS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 5),
	Vector2i(2, 5), Vector2i(3, 1), Vector2i(3, 2),
	Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 4)
]

static func new_state() -> Dictionary:
	return {
		"position": START,
		"fuel": FUEL_START,
		"collected": [],
		"status": "playing",
		"moves": 0,
		"last_action": "start"
	}

static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

static func is_blocked(cell: Vector2i) -> bool:
	return not is_inside(cell) or ASTEROIDS.has(cell)

static func step(state: Dictionary, direction: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) != "playing":
		return next
	if absi(direction.x) + absi(direction.y) != 1:
		next["last_action"] = "invalid_direction"
		return next
	var current: Vector2i = next.get("position", START)
	var target: Vector2i = current + direction
	if is_blocked(target) or int(next.get("fuel", 0)) <= 0:
		next["last_action"] = "blocked"
		return next

	next["position"] = target
	next["fuel"] = int(next.get("fuel", 0)) - 1
	next["moves"] = int(next.get("moves", 0)) + 1
	var collected: Array = next.get("collected", [])
	if BEACONS.has(target) and not collected.has(target):
		collected.append(target)
		next["collected"] = collected
	if target == EXIT and collected.size() == BEACONS.size():
		next["status"] = "won"
	elif int(next.get("fuel", 0)) <= 0:
		next["status"] = "failed"
	next["last_action"] = "move"
	return next

static func expire(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) == "playing":
		next["status"] = "failed"
		next["last_action"] = "timeout"
	return next
