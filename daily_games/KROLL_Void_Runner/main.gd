extends Node2D

const Rules = preload("res://rules.gd")
const BACKGROUND := Color(0.012, 0.022, 0.04)
const CYAN := Color(0.22, 0.9, 1.0)
const AMBER := Color(1.0, 0.68, 0.24)
const PLAYER_X: float = 168.0
const DISTANCE_SCALE: float = 14.0
const LANE_Y: Array[float] = [246.0, 366.0, 486.0]

var scenario_index: int = 0
var scenario: Dictionary = {}
var state: Dictionary = {}
var hud: Label
var message_label: Label
var touch_buttons: Dictionary = {}
var _queued_actions: Dictionary = {"left": false, "right": false, "jump": false, "slide": false}

func _ready() -> void:
	_build_ui()
	_load_scenario(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.name = "RunnerStatus"
	hud.position = Vector2(18.0, 14.0)
	hud.size = Vector2(900.0, 70.0)
	hud.add_theme_color_override("font_color", Color(0.72, 0.93, 1.0))
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)
	message_label = Label.new()
	message_label.name = "RunnerMessage"
	message_label.position = Vector2(18.0, 90.0)
	message_label.size = Vector2(900.0, 34.0)
	message_label.add_theme_color_override("font_color", AMBER)
	layer.add_child(message_label)
	var panel := PanelContainer.new()
	panel.name = "TouchControls"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -76.0
	panel.offset_bottom = -8.0
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	_add_action_button(row, "left", "LANE ◀", "left")
	_add_action_button(row, "right", "LANE ▶", "right")
	_add_action_button(row, "jump", "JUMP", "jump")
	_add_action_button(row, "slide", "SLIDE", "slide")
	_add_command_button(row, "reset", "RESET", _restart)
	_add_command_button(row, "next", "NEXT", _next_scenario)

func _add_action_button(parent: HBoxContainer, key: String, label_text: String, action: String) -> void:
	var button := Button.new()
	button.name = "Touch_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(100.0, 52.0)
	parent.add_child(button)
	touch_buttons[key] = button
	button.pressed.connect(_queue_action.bind(action))

func _add_command_button(parent: HBoxContainer, key: String, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Action_" + key
	button.text = label_text
	button.custom_minimum_size = Vector2(88.0, 52.0)
	parent.add_child(button)
	touch_buttons[key] = button
	button.pressed.connect(callback)

func _queue_action(action: String) -> void:
	if _queued_actions.has(action):
		_queued_actions[action] = true

func _process(delta: float) -> void:
	_advance_simulation(delta)

func _advance_simulation(delta: float) -> void:
	if state.is_empty() or scenario.is_empty():
		return
	state = Rules.step(state, _queued_actions, delta, scenario)
	_queued_actions = {"left": false, "right": false, "jump": false, "slide": false}
	_refresh_hud()
	queue_redraw()

func _load_scenario(index: int) -> void:
	scenario_index = posmod(index, Rules.get_scenario_count())
	scenario = Rules.get_scenario(scenario_index)
	state = Rules.create_state(scenario_index)
	_queued_actions = {"left": false, "right": false, "jump": false, "slide": false}
	_refresh_hud()
	queue_redraw()

func _restart() -> void:
	_load_scenario(scenario_index)

func _next_scenario() -> void:
	_load_scenario(scenario_index + 1)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_A, KEY_LEFT:
			_queue_action("left")
		KEY_D, KEY_RIGHT:
			_queue_action("right")
		KEY_SPACE, KEY_W:
			_queue_action("jump")
		KEY_S, KEY_DOWN:
			_queue_action("slide")
		KEY_R:
			_restart()
		KEY_N:
			_next_scenario()

func _refresh_hud() -> void:
	if hud == null or message_label == null or state.is_empty():
		return
	hud.text = "KROLL VOID RUNNER // %s\nDISTANCE %.1f / %.1f   CELLS %d / %d   INTEGRITY %d" % [
		str(scenario.get("name", "UNKNOWN")),
		float(state.get("distance", 0.0)),
		float(scenario.get("end_distance", 0.0)),
		int(state.get("cells", 0)),
		int(scenario.get("required_cells", 0)),
		int(state.get("health", 0))
	]
	var status: String = str(state.get("status", "running"))
	if status == "won":
		message_label.text = "RELAY COMPLETE — all required data cells recovered"
	elif status == "failed":
		message_label.text = "RUN FAILED — press R to retry or N for another route"
	else:
		message_label.text = "A/D or ◀/▶ lane · SPACE/W jump · S/▼ slide · avoid barriers, gates and drones"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 640.0)), BACKGROUND)
	for index in range(64):
		var star := Vector2(float((index * 193) % 950 + 5), float((index * 79) % 620 + 5))
		draw_circle(star, 1.0 + float(index % 3) * 0.3, Color(0.4, 0.62, 0.78, 0.4))
	for lane_index in range(3):
		var y: float = LANE_Y[lane_index]
		draw_line(Vector2(70.0, y + 42.0), Vector2(930.0, y + 42.0), Color(0.18, 0.34, 0.43, 0.8), 2.0)
		draw_line(Vector2(70.0, y - 42.0), Vector2(930.0, y - 42.0), Color(0.18, 0.34, 0.43, 0.45), 1.0)
	if state.is_empty() or scenario.is_empty():
		return
	var distance: float = float(state.get("distance", 0.0))
	for obstacle in state.get("obstacles", []):
		if bool(obstacle.get("resolved", false)):
			continue
		var x: float = PLAYER_X + (float(obstacle.get("at", 0.0)) - distance) * DISTANCE_SCALE
		if x < 80.0 or x > 940.0:
			continue
		var y: float = LANE_Y[int(obstacle.get("lane", 1))]
		match str(obstacle.get("kind", "")):
			"barrier":
				draw_rect(Rect2(Vector2(x - 15.0, y - 30.0), Vector2(30.0, 60.0)), Color(0.95, 0.48, 0.2))
			"gate":
				draw_rect(Rect2(Vector2(x - 18.0, y - 38.0), Vector2(36.0, 18.0)), Color(0.72, 0.46, 1.0))
			_:
				draw_circle(Vector2(x, y), 17.0, Color(1.0, 0.3, 0.35))
	for pickup in state.get("pickups", []):
		if bool(pickup.get("resolved", false)):
			continue
		var pickup_x: float = PLAYER_X + (float(pickup.get("at", 0.0)) - distance) * DISTANCE_SCALE
		if pickup_x < 80.0 or pickup_x > 940.0:
			continue
		draw_circle(Vector2(pickup_x, LANE_Y[int(pickup.get("lane", 1))]), 10.0, AMBER)
	var lane: int = int(state.get("lane", 1))
	var player_y: float = LANE_Y[lane]
	var jump_ratio: float = clampf(float(state.get("jump_timer", 0.0)) / Rules.JUMP_DURATION, 0.0, 1.0)
	player_y -= 48.0 * sin((1.0 - jump_ratio) * PI * 0.5)
	var sliding: bool = float(state.get("slide_timer", 0.0)) > 0.0
	var player_size := Vector2(34.0, 26.0) if sliding else Vector2(30.0, 52.0)
	draw_rect(Rect2(Vector2(PLAYER_X - player_size.x * 0.5, player_y - player_size.y * 0.5), player_size), CYAN)
	draw_circle(Vector2(PLAYER_X + 12.0, player_y - 5.0), 4.0, Color(0.02, 0.08, 0.12))
	var exit_x: float = PLAYER_X + (float(scenario.get("end_distance", 0.0)) - distance) * DISTANCE_SCALE
	if exit_x >= 80.0 and exit_x <= 940.0:
		draw_line(Vector2(exit_x, 180.0), Vector2(exit_x, 540.0), Color(0.28, 0.92, 0.62, 0.75), 3.0)
