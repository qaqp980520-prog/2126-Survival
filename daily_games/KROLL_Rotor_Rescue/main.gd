extends Control

const Rules = preload("res://rules.gd")
const SEEDS: Array[int] = [1, 2, 3]

var game_state: Dictionary = {}
var _seed_index: int = 0
var _touch_directions: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(960.0, 600.0)
	game_state = Rules.new_game(SEEDS[_seed_index])
	_build_controls()
	queue_redraw()

func _process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1.0
	for direction in _touch_directions.keys():
		input_vector += _direction_vector(str(direction))
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	game_state = Rules.step(game_state, input_vector, delta)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		_restart()
	elif key_event.keycode == KEY_N:
		_next_seed()

func _build_controls() -> void:
	var definitions: Array[Dictionary] = [
		{"label": "LEFT", "direction": "left", "x": 18.0},
		{"label": "UP", "direction": "up", "x": 96.0},
		{"label": "DOWN", "direction": "down", "x": 174.0},
		{"label": "RIGHT", "direction": "right", "x": 252.0}
	]
	for definition in definitions:
		var button := Button.new()
		button.text = str(definition["label"])
		button.position = Vector2(float(definition["x"]), 526.0)
		button.size = Vector2(70.0, 48.0)
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(_press_touch.bind(str(definition["direction"])))
		button.button_up.connect(_release_touch.bind(str(definition["direction"])))
		add_child(button)
	var reset_button := Button.new()
	reset_button.text = "RESTART"
	reset_button.position = Vector2(650.0, 526.0)
	reset_button.size = Vector2(100.0, 48.0)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_restart)
	add_child(reset_button)
	var next_button := Button.new()
	next_button.text = "NEXT"
	next_button.position = Vector2(760.0, 526.0)
	next_button.size = Vector2(100.0, 48.0)
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(_next_seed)
	add_child(next_button)

func _press_touch(direction: String) -> void:
	_touch_directions[direction] = true

func _release_touch(direction: String) -> void:
	_touch_directions.erase(direction)

func _direction_vector(direction: String) -> Vector2:
	match direction:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
	return Vector2.ZERO

func _restart() -> void:
	game_state = Rules.new_game(SEEDS[_seed_index])
	_touch_directions.clear()
	queue_redraw()

func _next_seed() -> void:
	_seed_index = posmod(_seed_index + 1, SEEDS.size())
	_restart()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 500.0)), Color("#102638"))
	for x in range(0, 961, 40):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), 490.0), Color(0.25, 0.46, 0.56, 0.18), 1.0)
	for y in range(0, 491, 40):
		draw_line(Vector2(0.0, float(y)), Vector2(960.0, float(y)), Color(0.25, 0.46, 0.56, 0.18), 1.0)
	draw_rect(Rect2(Vector2(0.0, 470.0), Vector2(960.0, 30.0)), Color("#233d49"))
	for obstacle: Rect2 in Rules.obstacle_rects(int(game_state.get("seed", 1))):
		draw_rect(obstacle, Color("#596a75"))
		draw_rect(Rect2(obstacle.position + Vector2(6.0, 6.0), obstacle.size - Vector2(12.0, 12.0)), Color("#3a4d59"))
	var pad: Vector2 = Rules.PAD_POSITION
	draw_circle(pad, 27.0, Color("#1b775f"))
	draw_arc(pad, 29.0, 0.0, TAU, 40, Color("#76f2c3"), 3.0)
	draw_string(ThemeDB.fallback_font, pad + Vector2(-18.0, 5.0), "H", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color.WHITE)

	var survivor_positions: Array = game_state.get("survivor_positions", [])
	var rescued: Array = game_state.get("rescued", [])
	for index in range(survivor_positions.size()):
		var survivor: Vector2 = survivor_positions[index]
		var color: Color = Color("#8798a1") if bool(rescued[index]) else Color("#f0d36b")
		draw_circle(survivor, 10.0, color)
		draw_line(survivor + Vector2(-7.0, 0.0), survivor + Vector2(7.0, 0.0), Color("#172630"), 2.0)
		draw_line(survivor + Vector2(0.0, -7.0), survivor + Vector2(0.0, 7.0), Color("#172630"), 2.0)

	var position: Vector2 = game_state.get("position", Vector2(70.0, 250.0))
	var velocity: Vector2 = game_state.get("velocity", Vector2.ZERO)
	var heading: Vector2 = velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT
	draw_line(position - heading * 26.0, position + heading * 26.0, Color("#5be2ee"), 4.0)
	draw_circle(position, 13.0, Color("#d8f8ff"))
	draw_circle(position, 6.0, Color("#2588a1"))
	draw_line(position + Vector2(-19.0, -16.0), position + Vector2(19.0, -16.0), Color("#e5f7ff"), 3.0)
	draw_line(position + Vector2(0.0, -16.0), position + Vector2(0.0, -8.0), Color("#e5f7ff"), 2.0)

	var rescued_count := 0
	for value in rescued:
		if bool(value):
			rescued_count += 1
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 28.0), "KROLL // ROTOR RESCUE    SEED %d" % int(game_state.get("seed", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("#8df1f4"))
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 54.0), "RESCUED %d/3    FUEL %.1f    TIME %.1f" % [rescued_count, float(game_state.get("fuel", 0.0)), float(game_state.get("time_left", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color("#e0f1f4"))
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 80.0), "WASD / ARROWS: THRUST    STABILIZE NEAR CREW AND LAND AT H", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#b4cbd5"))
	if bool(game_state.get("won", false)):
		draw_rect(Rect2(Vector2(270.0, 205.0), Vector2(420.0, 90.0)), Color("#0d4b43"))
		draw_string(ThemeDB.fallback_font, Vector2(325.0, 258.0), "RESCUE COMPLETE  //  R RESTART · N NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
	elif bool(game_state.get("failed", false)):
		draw_rect(Rect2(Vector2(270.0, 205.0), Vector2(420.0, 90.0)), Color("#652f36"))
		draw_string(ThemeDB.fallback_font, Vector2(320.0, 258.0), "MISSION FAILED: %s  //  R RETRY" % str(game_state.get("reason", "unknown")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
