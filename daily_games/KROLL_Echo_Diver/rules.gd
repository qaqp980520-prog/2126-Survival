extends RefCounted
class_name EchoDiverRules

const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 7
const START: Vector2i = Vector2i(0, 3)
const EXIT: Vector2i = Vector2i(7, 3)
const FUEL_START: int = 32
const SONAR_CHARGES: int = 4
const TIME_LIMIT: float = 75.0
const BEACONS: Array[Vector2i] = [Vector2i(2, 1), Vector2i(5, 1), Vector2i(4, 5)]
const WALLS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 5),
	Vector2i(2, 5), Vector2i(3, 1), Vector2i(3, 2),
	Vector2i(3, 5), Vector2i(6, 5)
]
const HAZARDS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(5, 4), Vector2i(6, 2), Vector2i(2, 6)]
const SONAR_RADIUS: int = 3

static func new_state() -> Dictionary:
	return {"position": START, "fuel": FUEL_START, "sonar_charges": SONAR_CHARGES, "collected": [], "status": "playing", "moves": 0, "last_action": "start"}

static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

static func is_blocked(cell: Vector2i) -> bool:
	return not is_inside(cell) or WALLS.has(cell)

static func step(state: Dictionary, direction: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) != "playing":
		return next
	if absi(direction.x) + absi(direction.y) != 1:
		next["last_action"] = "invalid_direction"
		return next
	var fuel_before: int = int(next.get("fuel", 0))
	if fuel_before <= 0:
		next["status"] = "failed"
		next["last_action"] = "fuel_empty"
		return next
	var current: Vector2i = next.get("position", START)
	var target: Vector2i = current + direction
	if is_blocked(target):
		next["last_action"] = "blocked"
		return next
	next["position"] = target
	next["fuel"] = fuel_before - 1
	next["moves"] = int(next.get("moves", 0)) + 1
	var collected: Array = next.get("collected", [])
	if BEACONS.has(target) and not collected.has(target):
		collected.append(target)
		next["collected"] = collected
	if HAZARDS.has(target):
		next["fuel"] = maxi(0, int(next["fuel"]) - 4)
		next["last_action"] = "hazard"
	else:
		next["last_action"] = "move"
	if target == EXIT and collected.size() == BEACONS.size():
		next["status"] = "won"
	elif int(next.get("fuel", 0)) <= 0:
		next["status"] = "failed"
	return next

static func pulse_sonar(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) != "playing":
		return next
	var charges: int = int(next.get("sonar_charges", 0))
	if charges <= 0:
		next["last_action"] = "sonar_unavailable"
		return next
	next["sonar_charges"] = charges - 1
	next["last_action"] = "sonar"
	return next

static func visible_hazards(position: Vector2i, radius: int = SONAR_RADIUS) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	for hazard in HAZARDS:
		var distance: int = absi(hazard.x - position.x) + absi(hazard.y - position.y)
		if distance <= radius:
			visible.append(hazard)
	return visible

static func expire(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "playing")) == "playing":
		next["status"] = "failed"
		next["last_action"] = "timeout"
	return next
