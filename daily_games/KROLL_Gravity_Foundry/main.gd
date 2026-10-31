extends Control

const Rules = preload("res://rules.gd")
const CELL_SIZE: float = 64.0

var state: Dictionary = {}
var status_label: Label
var message_label: Label
var buttons: Dictionary = {}

func _ready() -> void:
	state = Rules.new_game(0)
	_build_ui()
	_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_W, KEY_UP:
			_act("up")
		KEY_D, KEY_RIGHT:
			_act("right")
		KEY_S, KEY_DOWN:
			_act("down")
		KEY_A, KEY_LEFT:
			_act("left")
		KEY_Q:
			_act("rotate_left")
		KEY_E:
			_act("rotate_right")
		KEY_R:
			restart_game()
		KEY_N:
			next_level()

func _build_ui() -> void:
	var header := VBoxContainer.new()
	header.position = Vector2(24.0, 14.0)
	header.size = Vector2(912.0, 104.0)
	header.add_theme_constant_override("separation", 4)
	add_child(header)

	var title := Label.new()
	title.text = "KROLL // GRAVITY FOUNDRY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	header.add_child(title)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 17)
	header.add_child(status_label)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.9))
	header.add_child(message_label)

	var controls := GridContainer.new()
	controls.name = "TouchControls"
	controls.columns = 4
	controls.position = Vector2(60.0, 594.0)
	controls.size = Vector2(840.0, 112.0)
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 6)
	add_child(controls)

	_add_button(controls, "UP (W)", "up", func(): _act("up"))
	_add_button(controls, "LEFT (A)", "left", func(): _act("left"))
	_add_button(controls, "DOWN (S)", "down", func(): _act("down"))
	_add_button(controls, "RIGHT (D)", "right", func(): _act("right"))
	_add_button(controls, "ROTATE LEFT (Q)", "rotate_left", func(): _act("rotate_left"))
	_add_button(controls, "ROTATE RIGHT (E)", "rotate_right", func(): _act("rotate_right"))
	_add_button(controls, "RESTART (R)", "restart", restart_game)
	_add_button(controls, "NEXT (N)", "next", next_level)

func _add_button(parent: Container, label: String, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = "%sButton" % key.capitalize()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	buttons[key] = button

func _act(action: String) -> void:
	var result: Dictionary = Rules.apply_action(state, action)
	if bool(result.get("ok", false)):
		state = result.get("state", state)
	_render()

func restart_game() -> void:
	state = Rules.new_game(int(state.get("level_index", 0)))
	_render()

func next_level() -> void:
	if str(state.get("status", "")) != "won":
		return
	var next_index: int = (int(state.get("level_index", 0)) + 1) % Rules.get_level_count()
	state = Rules.new_game(next_index)
	_render()

func get_current_state() -> Dictionary:
	return state.duplicate(true)

func _render() -> void:
	if state.is_empty() or status_label == null:
		return
	status_label.text = "LEVEL %d/%d  %s  TURN %d/%d  GRAVITY %s" % [
		int(state.get("level_index", 0)) + 1,
		Rules.get_level_count(),
		Rules.get_level_title(int(state.get("level_index", 0))).to_upper(),
		int(state.get("turns", 0)),
		Rules.MAX_TURNS,
		Rules.get_gravity_name(int(state.get("gravity", 0)))
	]
	message_label.text = str(state.get("message", ""))
	buttons["next"].disabled = str(state.get("status", "")) != "won"
	queue_redraw()

func _draw() -> void:
	# Headless CI verifies the state model and controls; avoid issuing draw commands
	# against a zero-sized dummy viewport. The desktop/mobile build uses the full board.
	if DisplayServer.get_name() == "headless" or size.x < 320.0 or size.y < 320.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07111c"), true)
	if state.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var cell_size: float = maxf(24.0, minf(CELL_SIZE, minf((size.x - 220.0) / Rules.GRID_SIZE, (size.y - 250.0) / Rules.GRID_SIZE)))
	var board_size: float = cell_size * Rules.GRID_SIZE
	var origin := Vector2((size.x - board_size) * 0.5, 132.0)
	var walls: Array = state.get("walls", [])
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	var crate: Vector2i = state.get("crate", Vector2i.ZERO)
	var plate: Vector2i = state.get("plate", Vector2i.ZERO)
	var exit_cell: Vector2i = state.get("exit", Vector2i.ZERO)
	for y in range(Rules.GRID_SIZE):
		for x in range(Rules.GRID_SIZE):
			var cell := Vector2i(x, y)
			var cell_origin := origin + Vector2(float(x), float(y)) * cell_size
			var rect := Rect2(cell_origin + Vector2(2.0, 2.0), Vector2(cell_size - 4.0, cell_size - 4.0))
			var fill := Color("#182a3a") if walls.has(cell) else Color("#203b4d")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color("#314e60"), false, 1.0)
			if cell == plate:
				draw_circle(rect.get_center(), cell_size * 0.22, Color("#4bd49a"))
				draw_string(font, cell_origin + Vector2(9.0, cell_size - 7.0), "PLATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#06261b"))
			if cell == exit_cell:
				draw_rect(rect.grow(-10.0), Color("#f1b75c"), false, 3.0)
				draw_string(font, cell_origin + Vector2(13.0, cell_size - 8.0), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f1b75c"))
			if cell == crate:
				draw_rect(rect.grow(-13.0), Color("#d48c48"), true)
				draw_rect(rect.grow(-13.0), Color("#f2c17d"), false, 2.0)
			if cell == player:
				draw_circle(rect.get_center(), cell_size * 0.24, Color("#57d9ff"))
				draw_circle(rect.get_center(), cell_size * 0.11, Color("#e7fbff"))
	draw_string(font, Vector2(38.0, 246.0), "OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#57d9ff"))
	draw_string(font, Vector2(38.0, 272.0), "MOVE + PUSH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8bdca"))
	draw_string(font, Vector2(38.0, 294.0), "Q / E ROTATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8bdca"))
	draw_string(font, Vector2(size.x - 174.0, 246.0), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e7b26d"))
	draw_string(font, Vector2(size.x - 174.0, 272.0), "GRAVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8bdca"))
	draw_string(font, Vector2(size.x - 174.0, 294.0), Rules.get_gravity_name(int(state.get("gravity", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#4bd49a"))
