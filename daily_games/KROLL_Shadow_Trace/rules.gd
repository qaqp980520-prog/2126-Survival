extends RefCounted

const BOARD_SIZE := 8
const MAX_TURNS := 40
const MAX_ALERT := 3
const START := Vector2i(0, 0)
const EXIT := Vector2i(7, 7)
const CARDINAL_DIRECTIONS := [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)
]
const WALLS := [
	Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
	Vector2i(5, 2), Vector2i(6, 2),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
	Vector2i(5, 5),
	Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)
]
const INTEL_LAYOUTS := [
	[Vector2i(0, 3), Vector2i(4, 5), Vector2i(7, 5)],
	[Vector2i(1, 3), Vector2i(4, 3), Vector2i(7, 4)],
	[Vector2i(0, 5), Vector2i(4, 1), Vector2i(6, 5)]
]
const GUARD_PATHS := [
	[Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1), Vector2i(4, 1), Vector2i(3, 1)],
	[Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 4)]
]

static func new_game(seed_value: int = 30) -> Dictionary:
	var layout_index: int = posmod(seed_value, INTEL_LAYOUTS.size())
	var guards: Array = []
	for path_value in GUARD_PATHS:
		var path: Array = path_value.duplicate(true)
		guards.append({"path": path, "index": 0})
	return {
		"seed": seed_value,
		"player": START,
		"exit": EXIT,
		"intel": INTEL_LAYOUTS[layout_index].duplicate(true),
		"collected": [],
		"guards": guards,
		"turns": 0,
		"alert": 0,
		"status": "playing"
	}

static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE and cell.y < BOARD_SIZE

static func is_wall(cell: Vector2i) -> bool:
	return WALLS.has(cell)

static func step(state: Dictionary, direction: Vector2i) -> Dictionary:
	var unchanged: Dictionary = state.duplicate(true)
	if str(state.get("status", "")) != "playing":
		return {"ok": false, "reason": "terminal", "state": unchanged}
	var waiting: bool = direction == Vector2i.ZERO
	if not waiting and not CARDINAL_DIRECTIONS.has(direction):
		return {"ok": false, "reason": "invalid_direction", "state": unchanged}

	var current: Vector2i = state.get("player", START)
	var target: Vector2i = current + direction
	if not is_inside(target):
		return {"ok": false, "reason": "outside_board", "state": unchanged}
	if not waiting and is_wall(target):
		return {"ok": false, "reason": "wall", "state": unchanged}

	var next: Dictionary = state.duplicate(true)
	next["player"] = target
	next["turns"] = int(state.get("turns", 0)) + 1
	var intel: Array = next.get("intel", [])
	var collected: Array = next.get("collected", [])
	if intel.has(target) and not collected.has(target):
		collected.append(target)
	next["collected"] = collected

	var guards: Array = next.get("guards", [])
	for i in range(guards.size()):
		var guard: Dictionary = guards[i].duplicate(true)
		var path: Array = guard.get("path", [])
		if not path.is_empty():
			guard["index"] = posmod(int(guard.get("index", 0)) + 1, path.size())
			guards[i] = guard
	next["guards"] = guards

	var alert: int = int(next.get("alert", 0))
	for guard_value in guards:
		var guard: Dictionary = guard_value
		var path: Array = guard.get("path", [])
		if path.is_empty():
			continue
		var guard_position: Vector2i = path[posmod(int(guard.get("index", 0)), path.size())]
		if guard_position == target:
			next["status"] = "caught"
			alert = MAX_ALERT
			break
		if guard_can_see_player(guard_position, target):
			alert += 1
	next["alert"] = mini(alert, MAX_ALERT)
	if alert >= MAX_ALERT:
		next["status"] = "caught"
	elif target == EXIT and collected.size() == intel.size():
		next["status"] = "won"
	elif int(next.get("turns", 0)) >= MAX_TURNS:
		next["status"] = "failed"

	return {"ok": true, "reason": "waited" if waiting else "moved", "state": next}

static func guard_can_see_player(guard_position: Vector2i, player_position: Vector2i) -> bool:
	var delta: Vector2i = player_position - guard_position
	if delta == Vector2i.ZERO:
		return true
	if delta.x != 0 and delta.y != 0:
		return false
	var distance: int = absi(delta.x) + absi(delta.y)
	if distance > 3:
		return false
	var direction := Vector2i(sign(delta.x), sign(delta.y))
	var cursor: Vector2i = guard_position + direction
	while cursor != player_position:
		if is_wall(cursor):
			return false
		cursor += direction
	return true
