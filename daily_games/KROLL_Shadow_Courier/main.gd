extends Control

const Rules = preload("res://rules.gd")
const BOARD_ORIGIN: Vector2 = Vector2(90.0, 126.0)
const TILE_SIZE: float = 64.0

var state: Dictionary = {}
var buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state = Rules.create_state(0)
	_build_controls()
	queue_redraw()

func _build_controls() -> void:
	_add_button("up", "↑", Vector2(740.0, 166.0), Vector2(60.0, 44.0), func(): _move(Vector2i.UP))
	_add_button("left", "←", Vector2(675.0, 216.0), Vector2(60.0, 44.0), func(): _move(Vector2i.LEFT))
	_add_button("wait", "WAIT", Vector2(740.0, 216.0), Vector2(60.0, 44.0), _wait)
	_add_button("right", "→", Vector2(805.0, 216.0), Vector2(60.0, 44.0), func(): _move(Vector2i.RIGHT))
	_add_button("down", "↓", Vector2(740.0, 266.0), Vector2(60.0, 44.0), func(): _move(Vector2i.DOWN))
	_add_button("decoy", "DEPLOY DECOY", Vector2(675.0, 344.0), Vector2(190.0, 48.0), _decoy)
	_add_button("reset", "RESET", Vector2(675.0, 408.0), Vector2(90.0, 48.0), _reset)
	_add_button("next", "NEXT", Vector2(775.0, 408.0), Vector2(90.0, 48.0), _next)

func _add_button(key: String, label_text: String, button_position: Vector2, button_size: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Button_" + key
	button.text = label_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 15)
	add_child(button)
	buttons[key] = button
	button.pressed.connect(callback)

func _move(direction: Vector2i) -> void:
	Rules.move_player(state, direction)
	queue_redraw()

func _wait() -> void:
	Rules.wait_turn(state)
	queue_redraw()

func _decoy() -> void:
	Rules.use_decoy(state)
	queue_redraw()

func _reset() -> void:
	state = Rules.reset(state)
	queue_redraw()

func _next() -> void:
	state = Rules.next_level(state)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_W, KEY_UP:
			_move(Vector2i.UP)
		KEY_A, KEY_LEFT:
			_move(Vector2i.LEFT)
		KEY_S, KEY_DOWN:
			_move(Vector2i.DOWN)
		KEY_D, KEY_RIGHT:
			_move(Vector2i.RIGHT)
		KEY_SPACE:
			_wait()
		KEY_E:
			_decoy()
		KEY_R:
			_reset()
		KEY_N:
			_next()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.022, 0.038), true)
	draw_string(ThemeDB.fallback_font, Vector2(90.0, 42.0), "KROLL SHADOW COURIER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 27, Color(0.38, 0.88, 1.0))
	var shards: Array = state.get("shards", [])
	var collected: Array = state.get("collected_shards", [])
	draw_string(ThemeDB.fallback_font, Vector2(90.0, 78.0), "MISSION %02d   DATA %d/%d   DECOYS %d   TURNS %d" % [
		int(state.get("level_index", 0)) + 1,
		collected.size(),
		shards.size(),
		int(state.get("decoys", 0)),
		int(state.get("turn", 0))
	], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.82, 0.91, 0.96))

	var sight_tiles: Array[Vector2i] = Rules.get_guard_sight_tiles(state)
	var walls: Array = state.get("walls", [])
	var exit_tile: Vector2i = state.get("exit", Vector2i(7, 7))
	for y in range(Rules.GRID_SIZE):
		for x in range(Rules.GRID_SIZE):
			var tile := Vector2i(x, y)
			var rect := _tile_rect(tile)
			var fill := Color(0.055, 0.095, 0.13)
			if sight_tiles.has(tile):
				fill = Color(0.28, 0.16, 0.08)
			if walls.has(tile):
				fill = Color(0.16, 0.21, 0.27)
			if tile == exit_tile:
				fill = Color(0.08, 0.27, 0.19)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.13, 0.22, 0.29), false, 1.0)
			if walls.has(tile):
				draw_line(rect.position + Vector2(12.0, 12.0), rect.position + rect.size - Vector2(12.0, 12.0), Color(0.29, 0.38, 0.46), 3.0)
				draw_line(rect.position + Vector2(rect.size.x - 12.0, 12.0), rect.position + Vector2(12.0, rect.size.y - 12.0), Color(0.29, 0.38, 0.46), 3.0)

	for shard in shards:
		var shard_tile: Vector2i = shard
		if collected.has(shard_tile):
			continue
		var center := _tile_center(shard_tile)
		draw_circle(center, 12.0, Color(0.15, 0.72, 1.0))
		draw_circle(center, 5.0, Color(0.85, 0.98, 1.0))

	var guards: Array = state.get("guards", [])
	for guard_value in guards:
		var guard: Dictionary = guard_value
		var guard_position: Vector2i = guard.get("position", Vector2i.ZERO)
		var center := _tile_center(guard_position)
		var disabled: bool = int(guard.get("disabled_turns", 0)) > 0
		draw_circle(center, 20.0, Color(0.22, 0.24, 0.3) if disabled else Color(0.55, 0.12, 0.14))
		draw_circle(center, 13.0, Color(0.55, 0.72, 0.8) if disabled else Color(1.0, 0.36, 0.31))
		var facing: Vector2i = guard.get("facing", Vector2i.UP)
		draw_line(center, center + Vector2(facing) * 22.0, Color(0.96, 0.98, 1.0), 4.0)
		if disabled:
			draw_string(ThemeDB.fallback_font, center + Vector2(-6.0, 5.0), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.05, 0.1, 0.15))

	var player_tile: Vector2i = state.get("player_pos", Vector2i.ZERO)
	var player_center := _tile_center(player_tile)
	draw_circle(player_center, 23.0, Color(0.05, 0.29, 0.38))
	draw_circle(player_center, 15.0, Color(0.36, 0.92, 1.0))
	draw_circle(player_center, 5.0, Color(0.95, 1.0, 1.0))

	draw_string(ThemeDB.fallback_font, Vector2(675.0, 126.0), "PATROL SIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 0.68, 0.28))
	draw_string(ThemeDB.fallback_font, Vector2(675.0, 148.0), "Amber tiles are watched.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.72, 0.79, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(675.0, 500.0), "WASD / ARROWS  MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.75, 0.83, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(675.0, 522.0), "SPACE  WAIT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.75, 0.83, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(675.0, 544.0), "E  DECOY   R  RESET", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.75, 0.83, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(90.0, 665.0), str(state.get("message", "")), HORIZONTAL_ALIGNMENT_LEFT, 760.0, 15, Color(0.84, 0.91, 0.95))
	var status: String = str(state.get("status", "active"))
	if status != "active":
		draw_rect(Rect2(Vector2(240.0, 300.0), Vector2(220.0, 82.0)), Color(0.02, 0.05, 0.08, 0.92), true)
		draw_string(ThemeDB.fallback_font, Vector2(266.0, 348.0), status.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(0.42, 0.92, 1.0) if status == "complete" else Color(1.0, 0.42, 0.35))

func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(tile) * TILE_SIZE, Vector2(TILE_SIZE - 2.0, TILE_SIZE - 2.0))

func _tile_center(tile: Vector2i) -> Vector2:
	return BOARD_ORIGIN + (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE
