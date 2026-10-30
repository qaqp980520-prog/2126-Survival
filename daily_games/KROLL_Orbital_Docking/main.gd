extends Node2D

const Rules = preload("res://rules.gd")
const BACKGROUND := Color(0.012, 0.022, 0.04)
const CYAN := Color(0.25, 0.88, 1.0)
const AMBER := Color(1.0, 0.68, 0.24)

var scenario_index: int = 0
var scenario: Dictionary = {}
var state: Dictionary = {}
var hud: Label
var status_label: Label
var touch_buttons: Dictionary = {}
var _touch_input: Dictionary = {"left": false, "right": false, "thrust": false, "reverse": false}

func _ready() -> void:
	_build_hud()
	_load_scenario(0)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.name = "FlightStatus"
	hud.position = Vector2(18.0, 14.0)
	hud.size = Vector2(920.0, 76.0)
	hud.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)
	status_label = Label.new()
	status_label.name = "FlightMessage"
	status_label.position = Vector2(18.0, 92.0)
	status_label.size = Vector2(920.0, 32.0)
	status_label.add_theme_color_override("font_color", AMBER)
	layer.add_child(status_label)
	var panel := PanelContainer.new()
	panel.name = "TouchControls"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -78.0
	panel.offset_bottom = -8.0
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	_add_control(row, "left", "ROTATE ◀")
	_add_control(row, "right", "ROTATE ▶")
	_add_control(row, "thrust", "THRUST")
	_add_control(row, "reverse", "REVERSE")
	_add_action_button(row, "reset", "RESET", _restart)
	_add_action_button(row, "next", "NEXT", _next_scenario)

func _add_control(parent: HBoxContainer, key: String, label_text: String) -> void:
	var button := Button.new()
	button.name = "Touch_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(100.0, 52.0)
	parent.add_child(button)
	touch_buttons[key] = button
	button.button_down.connect(_set_touch_input.bind(key, true))
	button.button_up.connect(_set_touch_input.bind(key, false))

func _add_action_button(parent: HBoxContainer, key: String, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Action_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(88.0, 52.0)
	parent.add_child(button)
	touch_buttons[key] = button
	button.pressed.connect(callback)

func _set_touch_input(key: String, value: bool) -> void:
	_touch_input[key] = value

func _physics_process(delta: float) -> void:
	_advance_simulation(delta)

func _advance_simulation(delta: float) -> void:
	if state.is_empty() or scenario.is_empty():
		return
	var input_state := {
		"left": Input.is_key_pressed(KEY_A) or bool(_touch_input.get("left", false)),
		"right": Input.is_key_pressed(KEY_D) or bool(_touch_input.get("right", false)),
		"thrust": Input.is_key_pressed(KEY_W) or bool(_touch_input.get("thrust", false)),
		"reverse": Input.is_key_pressed(KEY_S) or bool(_touch_input.get("reverse", false))
	}
	state = Rules.step(state, input_state, delta, scenario)
	_refresh_hud()
	queue_redraw()

func _load_scenario(index: int) -> void:
	scenario_index = posmod(index, Rules.get_scenario_count())
	scenario = Rules.get_scenario(scenario_index)
	state = Rules.create_state(scenario_index)
	_touch_input = {"left": false, "right": false, "thrust": false, "reverse": false}
	_refresh_hud()
	queue_redraw()

func _restart() -> void:
	_load_scenario(scenario_index)

func _next_scenario() -> void:
	_load_scenario(scenario_index + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_R:
				_restart()
			elif key_event.keycode == KEY_N:
				_next_scenario()

func _refresh_hud() -> void:
	if hud == null or status_label == null or state.is_empty():
		return
	var distance: float = Rules.distance_to_target(state, scenario)
	var velocity: Vector2 = state["velocity"]
	var speed: float = velocity.length()
	hud.text = "KROLL ORBITAL DOCKING // %s\nFUEL %.1f   SPEED %.1f   DISTANCE %.1f   TIME %.1f" % [
		str(scenario["name"]), float(state["fuel"]), speed, distance, float(state["elapsed"])
	]
	var status: String = str(state["status"])
	match status:
		"docked":
			status_label.text = "DOCKING SUCCESS — velocity and alignment stabilized"
		"failed":
			status_label.text = "MISSION TIME EXPIRED — press R to retry or N for next approach"
		"stranded":
			status_label.text = "FUEL DEPLETED — use the next approach to try again"
		_:
			status_label.text = "A/D rotate · W thrust · S reverse · match speed, range and port angle"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 640.0)), BACKGROUND)
	for index in range(52):
		var star := Vector2(float((index * 193) % 950 + 5), float((index * 79) % 620 + 5))
		draw_circle(star, 1.0 + float(index % 3) * 0.35, Color(0.42, 0.62, 0.78, 0.45))
	if scenario.is_empty() or state.is_empty():
		return
	var target: Vector2 = scenario["target_position"]
	var target_angle: float = float(scenario["target_angle"])
	var target_forward := Vector2(cos(target_angle), sin(target_angle))
	draw_circle(target, 48.0, Color(0.08, 0.28, 0.36, 0.22))
	draw_arc(target, Rules.DOCK_RADIUS, 0.0, TAU, 64, Color(0.28, 0.92, 1.0, 0.9), 2.0)
	draw_arc(target, 48.0, 0.0, TAU, 64, Color(0.22, 0.48, 0.62, 0.55), 1.0)
	draw_line(target - target_forward * 58.0, target + target_forward * 58.0, AMBER, 3.0)
	draw_circle(target, 5.0, AMBER)
	var ship_position: Vector2 = state["position"]
	var ship_angle: float = float(state["angle"])
	var forward := Vector2(cos(ship_angle), sin(ship_angle))
	var side := forward.rotated(PI * 0.5)
	var points := PackedVector2Array([
		ship_position + forward * 20.0,
		ship_position - forward * 13.0 + side * 11.0,
		ship_position - forward * 8.0,
		ship_position - forward * 13.0 - side * 11.0
	])
	draw_colored_polygon(points, CYAN)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.88, 0.98, 1.0), 2.0)
	var velocity: Vector2 = state["velocity"]
	if velocity.length() > 1.0:
		draw_line(ship_position, ship_position + velocity * 0.65, Color(1.0, 0.74, 0.28, 0.8), 2.0)
