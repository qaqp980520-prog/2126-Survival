extends RefCounted

const BOARD_COLUMNS := 10
const BOARD_ROWS := 8
const TOWER_COST := 40
const SPAWN_INTERVAL := 0.72
const TOWER_RANGE := 2.6
const TOWER_COOLDOWN := 0.68
const KILL_REWARD := 12
const WAVE_COUNTS: Array[int] = [8, 10, 12]
const PATH_CELLS: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(3, 2), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1),
	Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
	Vector2i(7, 4), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)
]

static func create_state() -> Dictionary:
	return {
		"credits": 100,
		"lives": 10,
		"wave": 0,
		"phase": "build",
		"spawn_remaining": 0,
		"spawn_clock": 0.0,
		"next_enemy_id": 1,
		"kills": 0,
		"escaped": 0,
		"towers": [],
		"enemies": []
	}

static func is_path_cell(cell: Vector2i) -> bool:
	return PATH_CELLS.has(cell)

static func can_place_tower(state: Dictionary, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_COLUMNS or cell.y >= BOARD_ROWS:
		return false
	if str(state.get("phase", "lost")) in ["won", "lost"]:
		return false
	if is_path_cell(cell) or int(state.get("credits", 0)) < TOWER_COST:
		return false
	for tower_value in state.get("towers", []):
		var tower: Dictionary = tower_value
		if tower.get("cell", Vector2i(-1, -1)) == cell:
			return false
	return true

static func place_tower(state: Dictionary, cell: Vector2i) -> bool:
	if not can_place_tower(state, cell):
		return false
	state["credits"] = int(state["credits"]) - TOWER_COST
	state["towers"].append({
		"cell": cell,
		"cooldown": 0.0,
		"range": TOWER_RANGE,
		"damage": 1
	})
	return true

static func start_next_wave(state: Dictionary) -> bool:
	if str(state.get("phase", "")) != "build" or int(state.get("wave", 0)) >= WAVE_COUNTS.size():
		return false
	state["wave"] = int(state["wave"]) + 1
	state["spawn_remaining"] = WAVE_COUNTS[int(state["wave"]) - 1]
	state["spawn_clock"] = 0.0
	state["phase"] = "wave"
	return true

static func enemy_grid_position(enemy: Dictionary) -> Vector2:
	var path_index: int = clampi(int(enemy.get("path_index", 0)), 0, PATH_CELLS.size() - 1)
	var current: Vector2 = Vector2(PATH_CELLS[path_index])
	if path_index >= PATH_CELLS.size() - 1:
		return current
	var next_cell: Vector2 = Vector2(PATH_CELLS[path_index + 1])
	return current.lerp(next_cell, clampf(float(enemy.get("progress", 0.0)), 0.0, 1.0))

static func advance(state: Dictionary, delta: float) -> void:
	if delta <= 0.0 or str(state.get("phase", "")) in ["won", "lost"]:
		return
	if str(state.get("phase", "")) == "wave":
		state["spawn_clock"] = float(state["spawn_clock"]) + delta
		while int(state["spawn_remaining"]) > 0 and float(state["spawn_clock"]) >= SPAWN_INTERVAL:
			state["spawn_clock"] = float(state["spawn_clock"]) - SPAWN_INTERVAL
			var wave_number: int = int(state["wave"])
			var enemy_hp: int = wave_number + 1
			state["enemies"].append({
				"id": int(state["next_enemy_id"]),
				"path_index": 0,
				"progress": 0.0,
				"hp": enemy_hp,
				"max_hp": enemy_hp,
				"speed": 0.95 + float(wave_number) * 0.10
			})
			state["next_enemy_id"] = int(state["next_enemy_id"]) + 1
			state["spawn_remaining"] = int(state["spawn_remaining"]) - 1

		var enemies: Array = state["enemies"]
		for enemy_index in range(enemies.size() - 1, -1, -1):
			var enemy: Dictionary = enemies[enemy_index]
			enemy["progress"] = float(enemy["progress"]) + float(enemy["speed"]) * delta
			while float(enemy["progress"]) >= 1.0:
				enemy["progress"] = float(enemy["progress"]) - 1.0
				enemy["path_index"] = int(enemy["path_index"]) + 1
				if int(enemy["path_index"]) >= PATH_CELLS.size():
					state["lives"] = int(state["lives"]) - 1
					state["escaped"] = int(state["escaped"]) + 1
					enemies.remove_at(enemy_index)
					break

		for tower_value in state["towers"]:
			var tower: Dictionary = tower_value
			tower["cooldown"] = maxf(0.0, float(tower["cooldown"]) - delta)
			if float(tower["cooldown"]) > 0.0:
				continue
			var target_index := -1
			var nearest_distance := float(tower["range"])
			for enemy_index in range(enemies.size()):
				var enemy: Dictionary = enemies[enemy_index]
				var distance: float = Vector2(tower["cell"]).distance_to(enemy_grid_position(enemy))
				if distance <= nearest_distance:
					nearest_distance = distance
					target_index = enemy_index
			if target_index >= 0:
				var target: Dictionary = enemies[target_index]
				target["hp"] = int(target["hp"]) - int(tower["damage"])
				tower["cooldown"] = TOWER_COOLDOWN
				if int(target["hp"]) <= 0:
					enemies.remove_at(target_index)
					state["kills"] = int(state["kills"]) + 1
					state["credits"] = int(state["credits"]) + KILL_REWARD

		if int(state["lives"]) <= 0:
			state["phase"] = "lost"
		elif int(state["spawn_remaining"]) == 0 and enemies.is_empty():
			state["phase"] = "won" if int(state["wave"]) >= WAVE_COUNTS.size() else "build"
