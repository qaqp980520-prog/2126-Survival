extends Node2D

const Rules = preload("res://rules.gd")
const BOARD_ORIGIN := Vector2(48.0, 112.0)
const TILE_SIZE: float = 64.0
const COLUMNS: int = 13
const ROWS: int = 8
const TOWER_RANGE: float = 148.0
const TOWER_FIRE_INTERVAL: float = 0.62
const INTERMISSION_SECONDS: float = 3.0
const MAX_WAVES: int = 3

var credits: int = 80
var base_health: int = 10
var wave: int = 1
var game_state: String = "playing"
var score: int = 0
var path_cells: Array[Vector2i] = []
var path_points: Array[Vector2] = []
var tower_cells: Array[Vector2i] = []
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var spawn_remaining: int = 0
var spawn_timer: float = 0.0
var intermission_timer: float = 0.0
var notice: String = "Click an empty tile to build a turret (35 credits)."
var notice_timer: float = 6.0

func _ready() -> void:
	_build_path()
	_start_wave()
	queue_redraw()

func _process(delta: float) -> void:
	if game_state != "playing":
		queue_redraw()
		return

	notice_timer = maxf(0.0, notice_timer - delta)
	_update_spawning(delta)
	_update_towers(delta)
	_update_enemies(delta)
	_check_wave_state(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_game()
			get_viewport().set_input_as_handled()
			return
	if game_state != "playing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _mouse_to_cell(event.position)
		if Rules.can_build(cell, path_cells, tower_cells, credits):
			_build_tower(cell)
			get_viewport().set_input_as_handled()
		elif Rules.is_inside_board(cell):
			notice = "Cannot build on the route or an occupied tile; need 35 credits."
			notice_timer = 2.5

func _build_path() -> void:
	path_cells.clear()
	path_points.clear()
	for x in range(0, 5):
		path_cells.append(Vector2i(x, 3))
	for y in range(4, 6):
		path_cells.append(Vector2i(4, y))
	for x in range(5, 9):
		path_cells.append(Vector2i(x, 5))
	for y in range(4, 2, -1):
		path_cells.append(Vector2i(8, y))
	for x in range(9, COLUMNS):
		path_cells.append(Vector2i(x, 3))
	for cell in path_cells:
		path_points.append(_cell_center(cell))

func _start_wave() -> void:
	spawn_remaining = Rules.wave_enemy_count(wave)
	spawn_timer = 0.25
	intermission_timer = 0.0
	notice = "WAVE %d — defend the KROLL core." % wave
	notice_timer = 3.0

func _update_spawning(delta: float) -> void:
	if spawn_remaining <= 0:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_remaining -= 1
		spawn_timer = 0.72

func _spawn_enemy() -> void:
	if path_points.size() < 2:
		return
	enemies.append({
		"position": path_points[0],
		"path_index": 1,
		"health": Rules.enemy_health_for_wave(wave),
		"speed": Rules.enemy_speed_for_wave(wave)
	})

func _update_towers(delta: float) -> void:
	for i in range(towers.size()):
		var tower: Dictionary = towers[i]
		tower["cooldown"] = maxf(0.0, float(tower.get("cooldown", 0.0)) - delta)
		tower["flash"] = maxf(0.0, float(tower.get("flash", 0.0)) - delta)
		if float(tower["cooldown"]) <= 0.0 and not enemies.is_empty():
			var target_index := _find_target(_cell_center(tower["cell"]))
			if target_index >= 0:
				var target: Dictionary = enemies[target_index]
				target["health"] = int(target["health"]) - 1
				enemies[target_index] = target
				tower["cooldown"] = TOWER_FIRE_INTERVAL
				tower["flash"] = 0.15
				if int(target["health"]) <= 0:
					enemies.remove_at(target_index)
					credits += 10
					score += 1
		towers[i] = tower

func _find_target(origin: Vector2) -> int:
	var best_index := -1
	var best_distance := TOWER_RANGE
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var distance := origin.distance_to(enemy["position"])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var path_index := int(enemy["path_index"])
		if path_index >= path_points.size():
			base_health -= 1
			enemies.remove_at(i)
			continue
		var position: Vector2 = enemy["position"]
		var target: Vector2 = path_points[path_index]
		var step := float(enemy["speed"]) * delta
		var distance := position.distance_to(target)
		if distance <= step:
			enemy["position"] = target
			path_index += 1
			if path_index >= path_points.size():
				base_health -= 1
				enemies.remove_at(i)
				if base_health <= 0:
					game_state = "defeat"
				continue
			enemy["path_index"] = path_index
		else:
			enemy["position"] = position + (target - position).normalized() * step
		enemies[i] = enemy
		if base_health <= 0:
			game_state = "defeat"

func _check_wave_state(delta: float) -> void:
	if game_state != "playing" or spawn_remaining > 0 or not enemies.is_empty():
		return
	if wave >= MAX_WAVES:
		game_state = "victory"
		notice = "CORE SECURED — press R to run another defense."
		notice_timer = 999.0
		return
	if intermission_timer <= 0.0:
		intermission_timer = INTERMISSION_SECONDS
		notice = "Wave cleared. Next wave incoming..."
		notice_timer = INTERMISSION_SECONDS
	intermission_timer -= delta
	if intermission_timer <= 0.0:
		wave += 1
		_start_wave()

func _build_tower(cell: Vector2i) -> void:
	credits -= Rules.TOWER_COST
	tower_cells.append(cell)
	towers.append({"cell": cell, "cooldown": 0.25, "flash": 0.0})
	notice = "Turret deployed. Each neutralized drone returns 10 credits."
	notice_timer = 3.0

func _mouse_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori((position.x - BOARD_ORIGIN.x) / TILE_SIZE),
		floori((position.y - BOARD_ORIGIN.y) / TILE_SIZE)
	)

func _cell_center(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2((float(cell.x) + 0.5) * TILE_SIZE, (float(cell.y) + 0.5) * TILE_SIZE)

func _reset_game() -> void:
	credits = 80
	base_health = 10
	wave = 1
	game_state = "playing"
	score = 0
	tower_cells.clear()
	towers.clear()
	enemies.clear()
	_build_path()
	_start_wave()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 720)), Color("#07111d"))
	draw_string(ThemeDB.fallback_font, Vector2(48, 42), "KROLL // CORE DEFENSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#7ef9ff"))
	draw_string(ThemeDB.fallback_font, Vector2(48, 72), "WAVE %d/%d   CORE %d HP   CREDITS %d   DRONES %d   NEUTRALIZED %d" % [wave, MAX_WAVES, base_health, credits, enemies.size() + spawn_remaining, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d7e8f5"))

	draw_rect(Rect2(BOARD_ORIGIN, Vector2(COLUMNS * TILE_SIZE, ROWS * TILE_SIZE)), Color("#0b1d2b"))
	for y in range(ROWS):
		for x in range(COLUMNS):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE - 2.0, TILE_SIZE - 2.0))
			var tile_color := Color("#102a3a")
			if path_cells.has(cell):
				tile_color = Color("#3c3425")
			draw_rect(rect, tile_color)
			if path_cells.has(cell):
				draw_rect(rect.grow(-22.0), Color("#c5a86b"))

	for tower in towers:
		var center := _cell_center(tower["cell"])
		draw_circle(center, TOWER_RANGE, Color(0.1, 0.8, 0.8, 0.045))
		draw_circle(center, 19.0, Color("#123f51"))
		draw_circle(center, 10.0, Color("#72f5ee"))
		if float(tower.get("flash", 0.0)) > 0.0:
			var target_index := _find_target(center)
			if target_index >= 0:
				draw_line(center, enemies[target_index]["position"], Color("#b9ffb2"), 3.0, true)

	for enemy in enemies:
		var center: Vector2 = enemy["position"]
		draw_circle(center, 14.0, Color("#ff536b"))
		draw_circle(center, 6.0, Color("#ffd6dc"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-7, -18), str(enemy["health"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	draw_string(ThemeDB.fallback_font, Vector2(48, 660), "CLICK EMPTY TILE: BUILD TURRET (35)   |   DRONE KILL: +10   |   R: RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9bb6c8"))
	if notice_timer > 0.0 and not notice.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(48, 696), notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f6d78b"))
	if game_state == "victory" or game_state == "defeat":
		draw_rect(Rect2(Vector2(230, 285), Vector2(500, 110)), Color(0.02, 0.06, 0.1, 0.94))
		var end_text := "CORE SECURED!" if game_state == "victory" else "CORE LOST"
		var end_color := Color("#7ef9ff") if game_state == "victory" else Color("#ff536b")
		draw_string(ThemeDB.fallback_font, Vector2(360, 335), end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, end_color)
		draw_string(ThemeDB.fallback_font, Vector2(320, 372), "Score %d — press R to restart" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
