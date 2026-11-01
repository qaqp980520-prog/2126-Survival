extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Inertial_Docking/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"

var _rules: RefCounted
var _state: Dictionary = {}
var _manual_controls: Dictionary = {}
var _mission_label: Label
var _stats_label: Label
var _status_label: Label
var _next_button: Button
var _field_rect: Rect2
var _world_scale: float = 1.0

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Inertial Docking could not load its rules module.")
		return
	_rules = rules_script.new() as RefCounted
	_state = _rules.call("make_state", 0)
	_build_ui()
	_refresh_ui()
	queue_redraw()

func _process(delta: float) -> void:
	var controls: Dictionary = _manual_controls.duplicate(true)
	controls["thrust"] = bool(controls.get("thrust", false)) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	controls["reverse"] = bool(controls.get("reverse", false)) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	controls["left"] = bool(controls.get("left", false)) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	controls["right"] = bool(controls.get("right", false)) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	controls["brake"] = bool(controls.get("brake", false)) or Input.is_key_pressed(KEY_SPACE)
	step_simulation(minf(delta, 0.05), controls)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		reset_scenario()
	elif event.keycode == KEY_N:
		advance_scenario()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // INERTIAL DOCKING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#83e6f2"))
	column.add_child(title)
	_mission_label = Label.new()
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_label.add_theme_font_size_override("font_size", 19)
	_mission_label.add_theme_color_override("font_color", Color("#f0d49b"))
	column.add_child(_mission_label)
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_color_override("font_color", Color("#c6dce4"))
	column.add_child(_stats_label)
	var field_space := Control.new()
	field_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_space.custom_minimum_size = Vector2(0.0, 360.0)
	column.add_child(field_space)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color("#a8e5cb"))
	column.add_child(_status_label)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_add_hold_button(controls, "ROTATE LEFT", "left")
	_add_hold_button(controls, "THRUST", "thrust")
	_add_hold_button(controls, "BRAKE", "brake")
	_add_hold_button(controls, "REVERSE", "reverse")
	_add_hold_button(controls, "ROTATE RIGHT", "right")
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var reset_button := Button.new()
	reset_button.text = "RESET (R)"
	reset_button.custom_minimum_size = Vector2(140.0, 42.0)
	reset_button.pressed.connect(reset_scenario)
	actions.add_child(reset_button)
	_next_button = Button.new()
	_next_button.text = "NEXT BERTH (N)"
	_next_button.custom_minimum_size = Vector2(170.0, 42.0)
	_next_button.pressed.connect(advance_scenario)
	actions.add_child(_next_button)

func _add_hold_button(parent: HBoxContainer, label_text: String, control_name: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(132.0, 46.0)
	button.button_down.connect(_set_control.bind(control_name, true))
	button.button_up.connect(_set_control.bind(control_name, false))
	parent.add_child(button)

func _set_control(control_name: String, enabled: bool) -> void:
	set_control(control_name, enabled)

func set_control(control_name: String, enabled: bool) -> bool:
	if not ["thrust","reverse","brake","left","right"].has(control_name):
		return false
	_manual_controls[control_name] = enabled
	return true

func step_simulation(delta: float, controls_override: Dictionary = {}) -> bool:
	if _rules == null or _state.is_empty():
		return false
	var controls: Dictionary = _manual_controls.duplicate(true)
	for key in controls_override.keys():
		controls[str(key)] = controls_override[key]
	var result: Dictionary = _rules.call("step", _state, controls, delta)
	if not bool(result.get("ok", false)):
		return false
	_state = result.get("state", _state)
	_refresh_ui()
	queue_redraw()
	return true

func reset_scenario() -> void:
	if _rules == null or _state.is_empty():
		return
	_state = _rules.call("reset_state", _state)
	_manual_controls.clear()
	_refresh_ui()
	queue_redraw()

func advance_scenario() -> bool:
	if _rules == null or _state.is_empty():
		return false
	var result: Dictionary = _rules.call("advance_state", _state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_manual_controls.clear()
	_refresh_ui()
	queue_redraw()
	return true

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_scenario() -> Dictionary:
	if _rules == null or _state.is_empty():
		return {}
	return _rules.call("get_scenario", int(_state.get("scenario_index", -1)))

func get_control_button_count() -> int:
	return 5

func _refresh_ui() -> void:
	if _rules == null or _state.is_empty():
		return
	var scenario: Dictionary = get_current_scenario()
	var summary: Dictionary = _rules.call("get_status_summary", _state)
	_mission_label.text = "%s  //  BERTH %d / 3" % [str(scenario.get("name", "UNKNOWN")), int(_state.get("scenario_index", 0)) + 1]
	_stats_label.text = "FUEL %03d  |  RELATIVE SPEED %05.1f  |  TIME %05.1f" % [int(round(float(summary.get("fuel", 0.0)))), float(summary.get("speed", 0.0)), float(_state.get("elapsed", 0.0))]
	var status: String = str(_state.get("status", "unknown"))
	var progress: float = float(_state.get("dock_progress", 0.0))
	_status_label.text = "%s  |  DOCK ALIGNMENT %d%%  |  %s" % [status.to_upper(), int(round(progress / 1.0 * 100.0)), str(scenario.get("brief", ""))]
	_next_button.disabled = status != "docked"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#06131d"))
	_field_rect = Rect2(Vector2(18.0, 112.0), Vector2(maxf(100.0, size.x - 36.0), maxf(180.0, size.y - 255.0)))
	draw_rect(_field_rect, Color("#0a202d"), true)
	draw_rect(_field_rect, Color("#285263"), false, 2.0)
	_world_scale = minf(_field_rect.size.x / 760.0, _field_rect.size.y / 470.0)
	for x_index in range(13):
		var x: float = _field_rect.position.x + _field_rect.size.x * float(x_index) / 12.0
		draw_line(Vector2(x, _field_rect.position.y), Vector2(x, _field_rect.end.y), Color(0.18,0.35,0.42,0.28), 1.0)
	for y_index in range(9):
		var y: float = _field_rect.position.y + _field_rect.size.y * float(y_index) / 8.0
		draw_line(Vector2(_field_rect.position.x, y), Vector2(_field_rect.end.x, y), Color(0.18,0.35,0.42,0.28), 1.0)
	if _state.is_empty() or _rules == null:
		return
	for obstacle_value in _state.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var obstacle_center: Vector2 = _world_to_screen(obstacle["position"])
		draw_circle(obstacle_center, float(obstacle["radius"]) * _world_scale, Color("#6b4650"))
		draw_arc(obstacle_center, float(obstacle["radius"]) * _world_scale, 0.0, TAU, 48, Color("#d88b79"), 2.0)
	var target_world: Vector2 = _rules.call("get_target_position", _state)
	var target: Vector2 = _world_to_screen(target_world)
	draw_circle(target, 27.0 * _world_scale, Color(0.2,0.8,0.65,0.08))
	draw_arc(target, 27.0 * _world_scale, 0.0, TAU, 64, Color("#7ce9c4"), 3.0)
	draw_arc(target, 18.0 * _world_scale, 0.0, TAU, 64, Color("#d5f4e8"), 1.5)
	var target_forward := Vector2(cos(float(_state["target_heading"])), -sin(float(_state["target_heading"])))
	draw_line(target, target + target_forward * 36.0 * _world_scale, Color("#f0d49b"), 3.0)
	var ship: Vector2 = _world_to_screen(_state["position"])
	var forward := Vector2(cos(float(_state["angle"])), -sin(float(_state["angle"])))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		ship + forward * 14.0 * _world_scale,
		ship - forward * 9.0 * _world_scale + side * 8.0 * _world_scale,
		ship - forward * 9.0 * _world_scale - side * 8.0 * _world_scale
	])
	draw_colored_polygon(points, Color("#83e6f2"))
	var velocity: Vector2 = _state["velocity"]
	if velocity.length() > 1.0:
		draw_line(ship, ship + Vector2(velocity.x, -velocity.y) * 2.2 * _world_scale, Color("#f0d49b"), 2.0)

func _world_to_screen(position: Vector2) -> Vector2:
	return _field_rect.position + _field_rect.size * 0.5 + Vector2(position.x, -position.y) * _world_scale
