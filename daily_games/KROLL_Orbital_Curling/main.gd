extends Control

const LAUNCH_POINT := Vector2(140.0, 345.0)
const STONE_RADIUS := 16.0

var rules: Variant
var state: Dictionary = {}
var status_label: Label
var stats_label: Label
var next_button: Button
var _dragging := false
var _drag_position := Vector2.ZERO

func _ready() -> void:
	var rules_path := "res://daily_games/KROLL_Orbital_Curling/rules.gd"
	if not ResourceLoader.exists(rules_path):
		rules_path = "res://rules.gd"
	var rules_script := load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Orbital Curling could not load its rules script.")
		return
	rules = rules_script.new()
	state = rules.new_campaign()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var title := Label.new()
	title.name = "GameTitle"
	title.text = "KROLL // ORBITAL CURLING"
	title.position = Vector2(28.0, 18.0)
	title.size = Vector2(600.0, 36.0)
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	add_child(title)

	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.position = Vector2(30.0, 55.0)
	stats_label.size = Vector2(720.0, 28.0)
	stats_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.96))
	add_child(stats_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(30.0, 84.0)
	status_label.size = Vector2(850.0, 26.0)
	status_label.add_theme_color_override("font_color", Color(0.66, 0.83, 0.91))
	add_child(status_label)

	next_button = Button.new()
	next_button.name = "NextRoundButton"
	next_button.text = "NEXT ROUND"
	next_button.position = Vector2(710.0, 620.0)
	next_button.size = Vector2(128.0, 42.0)
	next_button.pressed.connect(_advance_round)
	add_child(next_button)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "RESTART"
	restart_button.position = Vector2(850.0, 620.0)
	restart_button.size = Vector2(118.0, 42.0)
	restart_button.pressed.connect(restart_campaign)
	add_child(restart_button)

	var hint := Label.new()
	hint.name = "ControlHint"
	hint.text = "Drag from the blue launch stone opposite the direction you want to throw. Release to curl."
	hint.position = Vector2(28.0, 620.0)
	hint.size = Vector2(660.0, 42.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.72, 0.79, 0.84))
	add_child(hint)

func get_current_state() -> Dictionary:
	return state.duplicate(true)

func throw_from_aim(aim: Vector2, power: float) -> bool:
	var result: Dictionary = rules.throw_stone(state, aim, power)
	if not bool(result.get("ok", false)):
		status_label.text = "Throw rejected: %s" % str(result.get("reason", "unknown"))
		return false
	state = result["state"]
	_refresh()
	return true

func advance_round() -> bool:
	var result: Dictionary = rules.advance_round(state)
	if not bool(result.get("ok", false)):
		return false
	state = result["state"]
	_refresh()
	return true

func restart_campaign() -> void:
	state = rules.restart_campaign()
	_dragging = false
	_refresh()

func _advance_round() -> void:
	advance_round()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_aim(mouse_event.position)
		else:
			_release_aim(mouse_event.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_position = (event as InputEventMouseMotion).position
		queue_redraw()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_aim(touch_event.position)
		else:
			_release_aim(touch_event.position)
	elif event is InputEventScreenDrag and _dragging:
		_drag_position = (event as InputEventScreenDrag).position
		queue_redraw()

func _begin_aim(position: Vector2) -> void:
	if str(state.get("status", "")) != "playing" or int(state.get("shots_left", 0)) <= 0:
		return
	if position.distance_to(LAUNCH_POINT) > 44.0:
		return
	_dragging = true
	_drag_position = position
	queue_redraw()

func _release_aim(position: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var aim := LAUNCH_POINT - position
	var drag_length := aim.length()
	if drag_length < 20.0:
		status_label.text = "Aim farther from the launch stone before releasing."
		queue_redraw()
		return
	var power := clampf(drag_length * 1.8, rules.get_min_power(), rules.get_max_power())
	throw_from_aim(aim, power)
	queue_redraw()

func _refresh() -> void:
	var round_number := int(state.get("round_index", 0)) + 1
	stats_label.text = "ROUND %d/%d    THROWS %d/%d    SCORE %d/90" % [
		round_number,
		rules.get_round_count(),
		int(state.get("shots_left", 0)),
		rules.get_shots_per_round(),
		int(state.get("total_score", 0))
	]
	status_label.text = str(state.get("message", ""))
	next_button.visible = str(state.get("status", "")) == "round_complete"
	next_button.disabled = not next_button.visible
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.07), true)
	var rink_rect := Rect2(rules.get_rink_min(), rules.get_rink_max() - rules.RINK_MIN)
	draw_rect(rink_rect, Color(0.12, 0.25, 0.34), true)
	draw_rect(rink_rect, Color(0.58, 0.84, 0.92), false, 3.0)
	draw_line(Vector2(rink_rect.position.x, LAUNCH_POINT.y), Vector2(rink_rect.end.x, LAUNCH_POINT.y), Color(0.55, 0.72, 0.79, 0.35), 1.0)
	var target: Vector2 = state.get("target", rules.get_target(0))
	draw_circle(target, 104.0, Color(0.17, 0.38, 0.53, 0.7))
	draw_circle(target, 72.0, Color(0.28, 0.58, 0.72, 0.85))
	draw_circle(target, 42.0, Color(0.75, 0.88, 0.92))
	draw_circle(target, 17.0, Color(0.94, 0.64, 0.25))
	draw_circle(LAUNCH_POINT, STONE_RADIUS + 5.0, Color(0.1, 0.65, 0.86))
	draw_circle(LAUNCH_POINT, STONE_RADIUS, Color(0.88, 0.95, 0.98))
	var stones: Array = state.get("stones", [])
	for index in range(stones.size()):
		var stone: Dictionary = stones[index]
		var position: Vector2 = stone.get("position", LAUNCH_POINT)
		draw_circle(position + Vector2(3.0, 4.0), STONE_RADIUS, Color(0.02, 0.05, 0.08, 0.45))
		draw_circle(position, STONE_RADIUS, Color(0.94, 0.96, 0.98))
		draw_arc(position, STONE_RADIUS - 4.0, 0.0, TAU, 24, Color(0.2, 0.52, 0.66), 2.0)
	if _dragging:
		var aim := LAUNCH_POINT - _drag_position
		if aim.length_squared() > 1.0:
			var end_point := LAUNCH_POINT + aim.normalized() * minf(aim.length(), 170.0)
			draw_line(LAUNCH_POINT, end_point, Color(1.0, 0.78, 0.32), 4.0)
			draw_circle(end_point, 6.0, Color(1.0, 0.78, 0.32))
	draw_string(ThemeDB.fallback_font, target + Vector2(-34.0, -118.0), "TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.95, 0.98))
	draw_string(ThemeDB.fallback_font, LAUNCH_POINT + Vector2(-42.0, 38.0), "LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.92, 0.98))
