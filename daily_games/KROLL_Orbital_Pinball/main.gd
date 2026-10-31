extends Control

const Rules = preload("res://rules.gd")
const BOARD_OFFSET: Vector2 = Vector2(250.0, 36.0)

var state: Dictionary = {}
var touch_buttons: Dictionary = {}
var left_flipper_active: bool = false
var right_flipper_active: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state = Rules.create_state(0)
	_build_controls()
	queue_redraw()

func _build_controls() -> void:
	_add_button("left", "LEFT FLIP", Vector2(36.0, 690.0), Vector2(150.0, 46.0))
	_add_button("launch", "LAUNCH", Vector2(204.0, 690.0), Vector2(150.0, 46.0))
	_add_button("right", "RIGHT FLIP", Vector2(372.0, 690.0), Vector2(150.0, 46.0))
	_add_button("reset", "RESET", Vector2(540.0, 690.0), Vector2(120.0, 46.0))
	_add_button("next", "NEXT TABLE", Vector2(676.0, 690.0), Vector2(180.0, 46.0))

func _add_button(key: String, label_text: String, button_position: Vector2, button_size: Vector2) -> void:
	var button := Button.new()
	button.name = "Button_" + key
	button.text = label_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 14)
	add_child(button)
	touch_buttons[key] = button
	match key:
		"left":
			button.button_down.connect(_set_left_flipper.bind(true))
			button.button_up.connect(_set_left_flipper.bind(false))
		"right":
			button.button_down.connect(_set_right_flipper.bind(true))
			button.button_up.connect(_set_right_flipper.bind(false))
		"launch":
			button.pressed.connect(_launch)
		"reset":
			button.pressed.connect(_reset)
		"next":
			button.pressed.connect(_next_table)

func _set_left_flipper(value: bool) -> void:
	left_flipper_active = value

func _set_right_flipper(value: bool) -> void:
	right_flipper_active = value

func _launch() -> void:
	Rules.launch(state)
	queue_redraw()

func _reset() -> void:
	state = Rules.reset(state)
	left_flipper_active = false
	right_flipper_active = false
	queue_redraw()

func _next_table() -> void:
	state = Rules.create_state(int(state.get("table_index", 0)) + 1)
	left_flipper_active = false
	right_flipper_active = false
	queue_redraw()

func _process(delta: float) -> void:
	var left_active: bool = left_flipper_active or Input.is_key_pressed(KEY_A)
	var right_active: bool = right_flipper_active or Input.is_key_pressed(KEY_D)
	state = Rules.step(state, delta, left_active, right_active)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_SPACE:
			_launch()
		KEY_R:
			_reset()
		KEY_N:
			_next_table()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.028, 0.045), true)
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 42.0), "KROLL ORBITAL PINBALL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.48, 0.9, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(36.0, 74.0), "TABLE %02d   SCORE %05d   BALLS %d" % [int(state.get("table_index", 0)) + 1, int(state.get("score", 0)), int(state.get("lives", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.82, 0.9, 0.94))
	draw_string(ThemeDB.fallback_font, Vector2(36.0, 104.0), "A / D FLIPPERS · SPACE LAUNCH · R RESET · N NEXT TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.54, 0.68, 0.76))

	var board := Rect2(BOARD_OFFSET, Vector2(Rules.BOARD_WIDTH, Rules.BOARD_HEIGHT))
	draw_rect(board, Color(0.035, 0.075, 0.105), true)
	draw_rect(board, Color(0.12, 0.38, 0.48), false, 4.0)
	draw_line(BOARD_OFFSET + Vector2(28.0, 20.0), BOARD_OFFSET + Vector2(28.0, 560.0), Color(0.18, 0.54, 0.66), 5.0)
	draw_line(BOARD_OFFSET + Vector2(372.0, 20.0), BOARD_OFFSET + Vector2(372.0, 560.0), Color(0.18, 0.54, 0.66), 5.0)
	draw_line(BOARD_OFFSET + Vector2(28.0, 565.0), BOARD_OFFSET + Vector2(372.0, 565.0), Color(0.38, 0.2, 0.16), 3.0)

	for bumper in state.get("bumpers", []):
		var center: Vector2 = BOARD_OFFSET + bumper.get("position", Vector2.ZERO)
		var radius: float = float(bumper.get("radius", 24.0))
		draw_circle(center, radius + 5.0, Color(0.08, 0.28, 0.4))
		draw_circle(center, radius, Color(0.12, 0.68, 0.82))
		draw_circle(center, radius * 0.48, Color(0.65, 0.95, 1.0))

	var left_color: Color = Color(0.35, 0.95, 0.82) if left_flipper_active else Color(0.1, 0.5, 0.56)
	var right_color: Color = Color(0.35, 0.95, 0.82) if right_flipper_active else Color(0.1, 0.5, 0.56)
	draw_line(BOARD_OFFSET + Vector2(70.0, 540.0), BOARD_OFFSET + Vector2(178.0, 525.0 if left_flipper_active else 548.0), left_color, 12.0)
	draw_line(BOARD_OFFSET + Vector2(330.0, 540.0), BOARD_OFFSET + Vector2(222.0, 525.0 if right_flipper_active else 548.0), right_color, 12.0)
	draw_circle(BOARD_OFFSET + Vector2(200.0, 580.0), 18.0, Color(0.65, 0.28, 0.12))

	var ball: Vector2 = state.get("ball", Vector2(340.0, 548.0))
	draw_circle(BOARD_OFFSET + ball, Rules.BALL_RADIUS, Color(0.95, 0.97, 1.0))
	draw_circle(BOARD_OFFSET + ball + Vector2(-2.0, -2.0), 2.5, Color(0.35, 0.55, 0.72))
	if not bool(state.get("launched", false)):
		draw_string(ThemeDB.fallback_font, BOARD_OFFSET + Vector2(115.0, 470.0), "PRESS SPACE OR LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.8, 0.9, 0.95))
	if bool(state.get("game_over", false)):
		draw_string(ThemeDB.fallback_font, BOARD_OFFSET + Vector2(122.0, 315.0), "TABLE OVER · RESET", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.55, 0.35))
