extends Node2D

const Rules = preload("res://rules.gd")
const ACTIONS: Array[String] = ["generate", "cool", "optimize"]
const ACTION_RECTS: Array[Rect2] = [
	Rect2(48.0, 430.0, 286.0, 130.0),
	Rect2(369.0, 430.0, 286.0, 130.0),
	Rect2(690.0, 430.0, 286.0, 130.0)
]

var state: Dictionary = {}
var hover_action: String = ""

func _ready() -> void:
	_reset_game()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1024.0, 720.0)), Color8(7, 16, 29))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(48.0, 48.0), "KROLL // MICROGRID OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color8(96, 239, 255))
	draw_string(font, Vector2(50.0, 78.0), "SURVIVE 8 POWER CYCLES WITHOUT OVERHEATING", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color8(143, 171, 190))

	_draw_meter(font, Vector2(56.0, 150.0), "POWER", int(state.get("power", 0)), Rules.MAX_POWER, Color8(96, 239, 255))
	_draw_meter(font, Vector2(56.0, 222.0), "FUEL", int(state.get("fuel", 0)), 16, Color8(255, 195, 88))
	_draw_meter(font, Vector2(370.0, 150.0), "HEAT", int(state.get("heat", 0)), Rules.MAX_HEAT, Color8(255, 108, 95))
	_draw_meter(font, Vector2(370.0, 222.0), "STABILITY", int(state.get("stability", 0)), Rules.MAX_STABILITY, Color8(121, 255, 166))

	var turn := int(state.get("turn", 0))
	var demands: Array = state.get("demands", [])
	var next_demand := int(demands[turn]) if turn >= 0 and turn < demands.size() else 0
	draw_string(font, Vector2(704.0, 157.0), "CYCLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(143, 171, 190))
	draw_string(font, Vector2(704.0, 193.0), "%d / %d" % [mini(turn + 1, Rules.MAX_TURNS), Rules.MAX_TURNS], HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color8(234, 243, 249))
	draw_string(font, Vector2(704.0, 230.0), "NEXT DEMAND: %d" % next_demand, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(255, 211, 115))

	for index in range(ACTIONS.size()):
		var action: String = ACTIONS[index]
		var rect: Rect2 = ACTION_RECTS[index]
		var fill := Color8(18, 43, 62)
		if hover_action == action:
			fill = Color8(25, 67, 84)
		if str(state.get("status", "")) != "running":
			fill = Color8(27, 34, 44)
		draw_rect(rect, fill)
		draw_rect(rect, Color8(73, 135, 153), false, 2.0)
		var title := "GENERATE" if action == "generate" else ("COOL" if action == "cool" else "OPTIMIZE")
		var detail := "Power +10  |  Fuel -2  |  Heat +14" if action == "generate" else ("Heat -22  |  Power +2" if action == "cool" else "Stability +12  |  Power +3  |  Heat -5")
		draw_string(font, rect.position + Vector2(18.0, 36.0), "%d  %s" % [index + 1, title], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color8(96, 239, 255))
		draw_string(font, rect.position + Vector2(18.0, 70.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color8(186, 205, 216))
		draw_string(font, rect.position + Vector2(18.0, 105.0), "CLICK / TAP TO USE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color8(143, 171, 190))

	var status := str(state.get("status", "running"))
	var message := str(state.get("message", ""))
	var message_color := Color8(224, 237, 244)
	if status == "won":
		message_color = Color8(121, 255, 166)
	elif status == "lost":
		message_color = Color8(255, 116, 110)
	draw_string(font, Vector2(50.0, 370.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, message_color)
	draw_string(font, Vector2(50.0, 625.0), "1 GENERATE    2 COOL    3 OPTIMIZE    |    R RESET", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color8(143, 171, 190))
	draw_string(font, Vector2(50.0, 665.0), "Tip: generation is efficient but hot. Cooling costs a cycle; optimization restores stability.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color8(112, 143, 163))

func _draw_meter(font: Font, position: Vector2, label: String, value: int, maximum: int, color: Color) -> void:
	draw_string(font, position, "%s  %d / %d" % [label, value, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	var rect := Rect2(position + Vector2(0.0, 16.0), Vector2(270.0, 18.0))
	draw_rect(rect, Color8(22, 38, 51))
	var ratio := clampf(float(value) / float(maxi(1, maximum)), 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_choose_action("generate")
			KEY_2:
				_choose_action("cool")
			KEY_3:
				_choose_action("optimize")
			KEY_R:
				_reset_game()
	elif event is InputEventMouseMotion:
		hover_action = _action_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_action(_action_at(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		_choose_action(_action_at(event.position))

func _action_at(position: Vector2) -> String:
	for index in range(ACTION_RECTS.size()):
		if ACTION_RECTS[index].has_point(position):
			return ACTIONS[index]
	return ""

func _choose_action(action: String) -> void:
	if action.is_empty():
		return
	if Rules.apply_action(state, action):
		queue_redraw()

func _reset_game() -> void:
	state = Rules.create_game(Time.get_ticks_msec())
	hover_action = ""
	queue_redraw()
