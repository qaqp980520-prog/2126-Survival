extends Control

const RulesScript = preload("res://rules.gd")
const BOARD_ORIGIN: Vector2 = Vector2(24.0, 86.0)
const BOARD_SIZE: Vector2 = Vector2(640.0, 420.0)

var rules: RefCounted
var layout_index: int = 0
var layout: Dictionary = {}
var state: Dictionary = {}
var touch_directions: Dictionary = {}
var touch_buttons: Dictionary = {}
var hud_label: Label
var status_label: Label

func _ready() -> void:
	rules = RulesScript.new()
	_build_ui()
	_start_layout(0)
	set_process(true)

func _process(delta: float) -> void:
	if state.is_empty():
		return
	var thrust: Vector2 = _get_thrust_direction()
	state = rules.call("step", state, thrust, delta, layout)
	_refresh_ui()
	queue_redraw()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "KROLL // TIDAL SURVEY"
	title.position = Vector2(24.0, 18.0)
	title.size = Vector2(600.0, 34.0)
	title.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)

	hud_label = Label.new()
	hud_label.position = Vector2(690.0, 88.0)
	hud_label.size = Vector2(250.0, 118.0)
	hud_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	hud_label.add_theme_font_size_override("font_size", 16)
	add_child(hud_label)

	status_label = Label.new()
	status_label.position = Vector2(690.0, 218.0)
	status_label.size = Vector2(250.0, 70.0)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36))
	status_label.add_theme_font_size_override("font_size", 14)
	add_child(status_label)

	_add_hold_button("up", "W", Vector2(758.0, 342.0))
	_add_hold_button("left", "A", Vector2(700.0, 396.0))
	_add_hold_button("down", "S", Vector2(758.0, 396.0))
	_add_hold_button("right", "D", Vector2(816.0, 396.0))
	_add_action_button("restart", "RESTART", Vector2(700.0, 470.0), _on_restart_pressed)
	_add_action_button("next", "NEXT", Vector2(816.0, 470.0), _on_next_pressed)

func _add_hold_button(key: String, label_text: String, position: Vector2) -> void:
	var button := Button.new()
	button.name = "Touch_" + key
	button.text = label_text
	button.position = position
	button.custom_minimum_size = Vector2(52.0, 44.0)
	button.button_down.connect(_set_touch_direction.bind(key))
	button.button_up.connect(_clear_touch_direction.bind(key))
	add_child(button)
	touch_buttons[key] = button

func _add_action_button(key: String, label_text: String, position: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Action_" + key
	button.text = label_text
	button.position = position
	button.custom_minimum_size = Vector2(108.0, 42.0)
	button.pressed.connect(callback)
	add_child(button)
	touch_buttons[key] = button

func _set_touch_direction(key: String) -> void:
	touch_directions[key] = true

func _clear_touch_direction(key: String) -> void:
	touch_directions.erase(key)

func _get_thrust_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch_directions.has("left"):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch_directions.has("right"):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch_directions.has("up"):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch_directions.has("down"):
		direction.y += 1.0
	return direction.normalized() if direction.length_squared() > 1.0 else direction

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		_on_restart_pressed()
	elif key_event.keycode == KEY_N:
		_on_next_pressed()

func _start_layout(index: int) -> void:
	layout_index = posmod(index, int(rules.call("layout_count")))
	layout = rules.call("get_layout", layout_index)
	state = rules.call("create_state", layout)
	_refresh_ui()
	queue_redraw()

func _on_restart_pressed() -> void:
	_start_layout(layout_index)

func _on_next_pressed() -> void:
	_start_layout(layout_index + 1)

func _refresh_ui() -> void:
	if hud_label == null or state.is_empty():
		return
	var beacons: Array = layout.get("beacons", [])
	hud_label.text = "%s\nOXYGEN  %.1f%%\nBEACONS  %d / %d\nHAZARD HITS  %d" % [
		str(layout.get("name", "Survey")),
		float(state.get("oxygen", 0.0)),
		int(state.get("collected", 0)),
		beacons.size(),
		int(state.get("hits", 0))
	]
	if bool(state.get("finished", false)):
		status_label.text = "SURVEY COMPLETE" if bool(state.get("won", false)) else "OXYGEN DEPLETED"
	elif int(state.get("collected", 0)) >= beacons.size():
		status_label.text = "RETURN TO THE DOCK"
	else:
		status_label.text = "COLLECT THE BEACONS\nTHEN RETURN TO THE DOCK"

func _draw() -> void:
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.012, 0.055, 0.085), true)
	for x in range(0, 641, 40):
		var x_pos: float = BOARD_ORIGIN.x + float(x)
		draw_line(Vector2(x_pos, BOARD_ORIGIN.y), Vector2(x_pos, BOARD_ORIGIN.y + BOARD_SIZE.y), Color(0.08, 0.22, 0.28, 0.65), 1.0)
	for y in range(0, 421, 40):
		var y_pos: float = BOARD_ORIGIN.y + float(y)
		draw_line(Vector2(BOARD_ORIGIN.x, y_pos), Vector2(BOARD_ORIGIN.x + BOARD_SIZE.x, y_pos), Color(0.08, 0.22, 0.28, 0.65), 1.0)
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.18, 0.55, 0.68), false, 2.0)
	if layout.is_empty() or state.is_empty():
		return
	for current_value in layout.get("currents", []):
		var current: Dictionary = current_value
		var center: Vector2 = BOARD_ORIGIN + current.get("center", Vector2.ZERO)
		var radius: float = float(current.get("radius", 0.0))
		draw_circle(center, radius, Color(0.05, 0.34, 0.42, 0.12))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.12, 0.62, 0.72, 0.55), 1.5, true)
		var force: Vector2 = current.get("force", Vector2.ZERO)
		draw_line(center, center + force.normalized() * 26.0, Color(0.2, 0.86, 0.9), 3.0, true)
	for hazard in layout.get("hazards", []):
		var hazard_center: Vector2 = BOARD_ORIGIN + hazard
		draw_circle(hazard_center, 20.0, Color(0.42, 0.13, 0.12, 0.88))
		draw_arc(hazard_center, 23.0, 0.0, TAU, 32, Color(0.96, 0.36, 0.24), 2.0, true)
	var beacons: Array = layout.get("beacons", [])
	for index in range(beacons.size()):
		var beacon_center: Vector2 = BOARD_ORIGIN + beacons[index]
		var collected: bool = index < int(state.get("collected", 0))
		var beacon_color: Color = Color(0.28, 0.88, 0.55) if collected else Color(1.0, 0.76, 0.28)
		draw_circle(beacon_center, 7.0, beacon_color)
		draw_arc(beacon_center, 16.0, 0.0, TAU, 32, beacon_color, 2.0, true)
	var dock_center: Vector2 = BOARD_ORIGIN + layout.get("dock", Vector2.ZERO)
	draw_arc(dock_center, 25.0, 0.0, TAU, 48, Color(0.22, 0.92, 0.64), 3.0, true)
	draw_circle(dock_center, 5.0, Color(0.22, 0.92, 0.64))
	var player_position: Vector2 = BOARD_ORIGIN + state.get("position", Vector2.ZERO)
	draw_circle(player_position, 9.0, Color(0.18, 0.86, 1.0))
	draw_arc(player_position, 13.0, 0.0, TAU, 32, Color(0.72, 0.97, 1.0), 2.0, true)
	var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
	if velocity.length_squared() > 1.0:
		draw_line(player_position, player_position + velocity.normalized() * 22.0, Color(0.9, 1.0, 1.0), 2.0, true)
