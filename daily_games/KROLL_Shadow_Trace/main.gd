extends Control

const Rules = preload("res://rules.gd")
const TILE_SIZE := 62.0
const BOARD_ORIGIN := Vector2(56.0, 112.0)

var seed_index: int = 30
var game_state: Dictionary = {}

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	restart_game()

func restart_game() -> void:
	game_state = Rules.new_game(seed_index)
	queue_redraw()

func next_layout() -> void:
	seed_index += 1
	restart_game()

func try_move(direction: Vector2i) -> bool:
	var result: Dictionary = Rules.step(game_state, direction)
	if not bool(result.get("ok", false)):
		return false
	game_state = result["state"]
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_W or key_event.keycode == KEY_UP:
			try_move(Vector2i(0, -1))
		elif key_event.keycode == KEY_S or key_event.keycode == KEY_DOWN:
			try_move(Vector2i(0, 1))
		elif key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
			try_move(Vector2i(-1, 0))
		elif key_event.keycode == KEY_D or key_event.keycode == KEY_RIGHT:
			try_move(Vector2i(1, 0))
		elif key_event.keycode == KEY_SPACE:
			try_move(Vector2i.ZERO)
		elif key_event.keycode == KEY_R:
			restart_game()
		elif key_event.keycode == KEY_N:
			next_layout()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_try_click(event.position)

func _try_click(position: Vector2) -> void:
	var local_position: Vector2 = position - BOARD_ORIGIN
	if local_position.x < 0.0 or local_position.y < 0.0:
		return
	var cell := Vector2i(int(local_position.x / TILE_SIZE), int(local_position.y / TILE_SIZE))
	if not Rules.is_inside(cell):
		return
	var current: Vector2i = game_state.get("player", Rules.START)
	var direction: Vector2i = cell - current
	if abs(direction.x) + abs(direction.y) == 1:
		try_move(direction)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.07), true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(28, 38), "KROLL // SHADOW TRACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.35, 0.9, 1.0))
	var collected: Array = game_state.get("collected", [])
	var intel: Array = game_state.get("intel", [])
	var status_text := "STATUS %s   INTEL %d/%d   ALERT %d/%d   TURNS %d/%d" % [
		str(game_state.get("status", "playing")).to_upper(),
		collected.size(), intel.size(),
		int(game_state.get("alert", 0)), Rules.MAX_ALERT,
		int(game_state.get("turns", 0)), Rules.MAX_TURNS
	]
	draw_string(font, Vector2(28, 72), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.9, 0.96))

	for y in range(Rules.BOARD_SIZE):
		for x in range(Rules.BOARD_SIZE):
			var cell := Vector2i(x, y)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE - 3, TILE_SIZE - 3))
			var fill := Color(0.08, 0.14, 0.19)
			if Rules.is_wall(cell):
				fill = Color(0.19, 0.25, 0.3)
			elif cell == Rules.EXIT:
				fill = Color(0.08, 0.34, 0.24) if collected.size() == intel.size() else Color(0.12, 0.22, 0.2)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.18, 0.29, 0.35), false, 1.0)
			if cell == Rules.EXIT:
				draw_string(font, rect.position + Vector2(12, 38), "OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 1.0, 0.65))
			if intel.has(cell) and not collected.has(cell):
				draw_circle(rect.position + rect.size * 0.5, 10.0, Color(1.0, 0.72, 0.24))

	var guards: Array = game_state.get("guards", [])
	for guard_value in guards:
		var guard: Dictionary = guard_value
		var path: Array = guard.get("path", [])
		if path.is_empty():
			continue
		var guard_cell: Vector2i = path[(int(guard.get("index", 0)) % path.size())]
		var center: Vector2 = BOARD_ORIGIN + Vector2(guard_cell.x * TILE_SIZE + (TILE_SIZE - 3) * 0.5, guard_cell.y * TILE_SIZE + (TILE_SIZE - 3) * 0.5)
		draw_circle(center, 15.0, Color(0.92, 0.22, 0.3))
		draw_circle(center, 5.0, Color(1.0, 0.8, 0.8))

	var player: Vector2i = game_state.get("player", Rules.START)
	var player_center: Vector2 = BOARD_ORIGIN + Vector2(player.x * TILE_SIZE + (TILE_SIZE - 3) * 0.5, player.y * TILE_SIZE + (TILE_SIZE - 3) * 0.5)
	draw_circle(player_center, 17.0, Color(0.2, 0.9, 1.0))
	draw_circle(player_center, 6.0, Color(0.95, 1.0, 1.0))

	var hint := "WASD / ARROWS move   SPACE wait   R restart   N next layout"
	if str(game_state.get("status", "playing")) == "won":
		hint = "EXTRACTION COMPLETE // Press R to retry or N for another layout"
	elif str(game_state.get("status", "playing")) == "caught":
		hint = "SECURITY ALERT // Press R to retry or N for another layout"
	elif str(game_state.get("status", "playing")) == "failed":
		hint = "TURN LIMIT REACHED // Press R to retry or N for another layout"
	draw_string(font, Vector2(28, 650), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.76, 0.86, 0.92))
