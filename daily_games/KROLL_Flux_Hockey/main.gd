extends Node2D

const Rules = preload("res://rules.gd")

var game_state: Dictionary = {}
var _pointer_active: bool = false
var _pointer_target_x: float = Rules.CENTER_X
var _message: String = "Drag to move the lower paddle. A/D also works."

func _ready() -> void:
	game_state = Rules.create_state()
	queue_redraw()

func _process(delta: float) -> void:
	if game_state.is_empty() or str(game_state.get("winner", "")) != "":
		return
	var target_x: float = float(game_state.get("player_x", Rules.CENTER_X))
	if _pointer_active:
		target_x = _pointer_target_x
	else:
		var axis: float = 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			axis -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			axis += 1.0
		target_x += axis * Rules.PLAYER_SPEED * delta
	var old_player_score: int = int(game_state.get("player_score", 0))
	var old_ai_score: int = int(game_state.get("ai_score", 0))
	game_state = Rules.step(game_state, target_x, delta)
	if int(game_state.get("player_score", 0)) > old_player_score:
		_message = "Point scored. Defend the lower goal!"
	elif int(game_state.get("ai_score", 0)) > old_ai_score:
		_message = "Opponent scored. Keep the rally alive!"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_player_target_x((event as InputEventMouseMotion).position.x)
	elif event is InputEventScreenDrag:
		_set_player_target_x((event as InputEventScreenDrag).position.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_set_player_target_x(touch.position.x)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_R:
				_reset_match()
			elif key_event.keycode == KEY_N:
				_next_arena()

func _set_player_target_x(value: float) -> void:
	if not is_finite(value):
		return
	_pointer_active = true
	_pointer_target_x = clampf(value, Rules.LEFT + Rules.PADDLE_HALF_WIDTH, Rules.RIGHT - Rules.PADDLE_HALF_WIDTH)

func _reset_match() -> void:
	game_state = Rules.reset_match(game_state)
	_message = "Match reset."
	queue_redraw()

func _next_arena() -> void:
	game_state = Rules.next_arena(game_state)
	_message = "Arena: " + Rules.get_arena_name(int(game_state.get("arena_index", 0)))
	queue_redraw()

func get_game_state() -> Dictionary:
	return game_state.duplicate(true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(800.0, 600.0)), Color("#07131f"), true)
	draw_rect(Rect2(Vector2(Rules.LEFT, Rules.TOP), Vector2(Rules.RIGHT - Rules.LEFT, Rules.BOTTOM - Rules.TOP)), Color("#102a3b"), true)
	var line_color := Color("#3b7187")
	draw_line(Vector2(Rules.LEFT, Rules.TOP), Vector2(Rules.CENTER_X - Rules.GOAL_HALF_WIDTH, Rules.TOP), line_color, 4.0)
	draw_line(Vector2(Rules.CENTER_X + Rules.GOAL_HALF_WIDTH, Rules.TOP), Vector2(Rules.RIGHT, Rules.TOP), line_color, 4.0)
	draw_line(Vector2(Rules.LEFT, Rules.BOTTOM), Vector2(Rules.CENTER_X - Rules.GOAL_HALF_WIDTH, Rules.BOTTOM), line_color, 4.0)
	draw_line(Vector2(Rules.CENTER_X + Rules.GOAL_HALF_WIDTH, Rules.BOTTOM), Vector2(Rules.RIGHT, Rules.BOTTOM), line_color, 4.0)
	draw_line(Vector2(Rules.LEFT, Rules.TOP), Vector2(Rules.LEFT, Rules.BOTTOM), line_color, 4.0)
	draw_line(Vector2(Rules.RIGHT, Rules.TOP), Vector2(Rules.RIGHT, Rules.BOTTOM), line_color, 4.0)
	draw_line(Vector2(Rules.LEFT + 2.0, Rules.CENTER_Y), Vector2(Rules.RIGHT - 2.0, Rules.CENTER_Y), Color("#275065"), 2.0)
	draw_circle(Vector2(Rules.CENTER_X, Rules.CENTER_Y), 54.0, Color("#17384a"))
	draw_circle(Vector2(Rules.CENTER_X, Rules.CENTER_Y), 54.0, Color("#3b7187"), false, 2.0)
	draw_rect(Rect2(Rules.CENTER_X - Rules.GOAL_HALF_WIDTH, Rules.TOP - 7.0, Rules.GOAL_HALF_WIDTH * 2.0, 14.0), Color("#e9a83e"), true)
	draw_rect(Rect2(Rules.CENTER_X - Rules.GOAL_HALF_WIDTH, Rules.BOTTOM - 7.0, Rules.GOAL_HALF_WIDTH * 2.0, 14.0), Color("#36c6d3"), true)

	var arena: Dictionary = Rules.get_arena(int(game_state.get("arena_index", 0)))
	for bumper_value in arena.get("bumpers", []):
		if bumper_value is Vector2:
			draw_circle(bumper_value, Rules.BUMPER_RADIUS, Color("#e9a83e"))
			draw_circle(bumper_value, 9.0, Color("#fff0bd"))

	var player_x: float = float(game_state.get("player_x", Rules.CENTER_X))
	var ai_x: float = float(game_state.get("ai_x", Rules.CENTER_X))
	draw_rect(Rect2(ai_x - Rules.PADDLE_HALF_WIDTH, Rules.AI_PADDLE_Y - Rules.PADDLE_HALF_HEIGHT, Rules.PADDLE_HALF_WIDTH * 2.0, Rules.PADDLE_HALF_HEIGHT * 2.0), Color("#f18b53"), true)
	draw_rect(Rect2(player_x - Rules.PADDLE_HALF_WIDTH, Rules.PLAYER_PADDLE_Y - Rules.PADDLE_HALF_HEIGHT, Rules.PADDLE_HALF_WIDTH * 2.0, Rules.PADDLE_HALF_HEIGHT * 2.0), Color("#39d0d8"), true)
	var puck_position: Vector2 = game_state.get("puck_position", Vector2(Rules.CENTER_X, Rules.CENTER_Y))
	draw_circle(puck_position, Rules.PUCK_RADIUS, Color("#f5f7f2"))
	draw_circle(puck_position, Rules.PUCK_RADIUS + 3.0, Color("#8be7ee"), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(40.0, 30.0), "KROLL FLUX HOCKEY", HORIZONTAL_ALIGNMENT_LEFT, 240.0, 20, Color("#b9e9f4"))
		var score := "%d   :   %d" % [int(game_state.get("player_score", 0)), int(game_state.get("ai_score", 0))]
		draw_string(font, Vector2(320.0, 32.0), score, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 24, Color("#ffffff"))
		var arena_label := Rules.get_arena_name(int(game_state.get("arena_index", 0))).to_upper()
		draw_string(font, Vector2(560.0, 30.0), arena_label, HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 17, Color("#e9b66a"))
		draw_string(font, Vector2(40.0, 580.0), _message, HORIZONTAL_ALIGNMENT_LEFT, 720.0, 15, Color("#9bc0d0"))
		draw_string(font, Vector2(40.0, 558.0), "DRAG / A-D MOVE  ·  R RESET  ·  N NEXT ARENA  ·  FIRST TO 5", HORIZONTAL_ALIGNMENT_LEFT, 720.0, 13, Color("#7899a8"))
		var winner: String = str(game_state.get("winner", ""))
		if winner != "":
			draw_rect(Rect2(190.0, 235.0, 420.0, 120.0), Color(0.02, 0.08, 0.12, 0.94), true)
			draw_string(font, Vector2(220.0, 285.0), "MATCH WON: " + winner, HORIZONTAL_ALIGNMENT_CENTER, 360.0, 26, Color("#ffffff"))
			draw_string(font, Vector2(220.0, 325.0), "PRESS R TO PLAY AGAIN OR N FOR NEXT ARENA", HORIZONTAL_ALIGNMENT_CENTER, 360.0, 13, Color("#b9e9f4"))
