extends RefCounted
class_name KrollCommandGridRules

const WIDTH: int = 8
const HEIGHT: int = 8
const EXIT_CELL := Vector2i(7, 7)
const MAX_TURNS: int = 32
const INITIAL_EMP: int = 3
const EMP_RADIUS: int = 2

static func wall_cells() -> Array[Vector2i]:
	return [
		Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
		Vector2i(5, 4), Vector2i(5, 5), Vector2i(5, 6),
		Vector2i(3, 5), Vector2i(4, 5)
	]

static func data_cells() -> Array[Vector2i]:
	return [Vector2i(1, 4), Vector2i(4, 1), Vector2i(6, 3), Vector2i(6, 6)]

static func initial_enemies() -> Array[Vector2i]:
	return [Vector2i(7, 0), Vector2i(0, 6), Vector2i(4, 4)]

static func create_state() -> Dictionary:
	return {
		"player": Vector2i(0, 0),
		"enemies": initial_enemies(),
		"data": data_cells(),
		"collected": 0,
		"emp": INITIAL_EMP,
		"turns_left": MAX_TURNS,
		"status": "playing"
	}

static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

static func is_wall_cell(cell: Vector2i) -> bool:
	return wall_cells().has(cell)

static func cell_label(state: Dictionary, cell: Vector2i) -> String:
	if Vector2i(state.get("player", Vector2i(-1, -1))) == cell:
		return "P"
	if (state.get("enemies", []) as Array).has(cell):
		return "B"
	if (state.get("data", []) as Array).has(cell):
		return "D"
	if cell == EXIT_CELL:
		return "X"
	if is_wall_cell(cell):
		return "#"
	return "·"

static func try_move(state: Dictionary, delta: Vector2i) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	if absi(delta.x) + absi(delta.y) != 1:
		return false
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	var target := player + delta
	if not is_inside(target) or is_wall_cell(target):
		return false
	var enemies: Array = state.get("enemies", [])
	if enemies.has(target):
		return false
	state["player"] = target
	var data: Array = state.get("data", [])
	if data.has(target):
		data.erase(target)
		state["data"] = data
		state["collected"] = int(state.get("collected", 0)) + 1
	_finish_turn(state)
	return true

static func use_emp(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	var charges := int(state.get("emp", 0))
	if charges <= 0:
		return false
	state["emp"] = charges - 1
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	var survivors: Array[Vector2i] = []
	for enemy_value in (state.get("enemies", []) as Array):
		var enemy: Vector2i = enemy_value
		var distance := absi(enemy.x - player.x) + absi(enemy.y - player.y)
		if distance > EMP_RADIUS:
			survivors.append(enemy)
	state["enemies"] = survivors
	_finish_turn(state)
	return true

static func _finish_turn(state: Dictionary) -> void:
	state["turns_left"] = maxi(0, int(state.get("turns_left", 0)) - 1)
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	var data: Array = state.get("data", [])
	if player == EXIT_CELL and data.is_empty():
		state["status"] = "won"
		return
	_advance_enemies(state)
	if str(state.get("status", "playing")) == "playing" and int(state.get("turns_left", 0)) <= 0:
		state["status"] = "lost"

static func _advance_enemies(state: Dictionary) -> void:
	var enemies: Array = state.get("enemies", [])
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	for index in range(enemies.size()):
		if str(state.get("status", "playing")) != "playing":
			return
		var current: Vector2i = enemies[index]
		var occupied: Array[Vector2i] = []
		for other_index in range(enemies.size()):
			if other_index != index:
				occupied.append(enemies[other_index])
		var next_cell := _next_step(current, player, occupied)
		if next_cell == player:
			state["status"] = "lost"
			state["enemies"] = enemies
			return
		enemies[index] = next_cell
	state["enemies"] = enemies

static func _next_step(start: Vector2i, goal: Vector2i, occupied: Array[Vector2i]) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var first_step: Dictionary = {start: start}
	var visited: Dictionary = {start: true}
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			var answer: Vector2i = first_step[current]
			return answer
		for direction in directions:
			var candidate := current + direction
			if not is_inside(candidate) or is_wall_cell(candidate) or visited.has(candidate):
				continue
			if occupied.has(candidate) and candidate != goal:
				continue
			visited[candidate] = true
			first_step[candidate] = candidate if current == start else first_step[current]
			queue.append(candidate)
	return start
