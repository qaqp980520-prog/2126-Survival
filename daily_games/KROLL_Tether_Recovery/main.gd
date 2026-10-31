extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var touch_buttons: Dictionary = {}
var held: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state = Rules.create_state(0)
	_build_controls()
	queue_redraw()

func _build_controls() -> void:
	_add_hold_button("up", "THRUST ↑", Vector2(28.0, 638.0), Vector2(100.0, 42.0))
	_add_hold_button("left", "←", Vector2(136.0, 638.0), Vector2(58.0, 42.0))
	_add_hold_button("brake", "BRAKE", Vector2(204.0, 638.0), Vector2(92.0, 42.0))
	_add_hold_button("right", "→", Vector2(304.0, 638.0), Vector2(58.0, 42.0))
	_add_hold_button("down", "THRUST ↓", Vector2(372.0, 638.0), Vector2(100.0, 42.0))
	_add_action_button("tether", "TETHER", Vector2(492.0, 638.0), Vector2(100.0, 42.0), _toggle_tether)
	_add_action_button("reset", "RESET", Vector2(610.0, 638.0), Vector2(90.0, 42.0), _reset)
	_add_action_button("next", "NEXT", Vector2(718.0, 638.0), Vector2(120.0, 42.0), _next_mission)

func _add_hold_button(key: String, label_text: String, button_position: Vector2, button_size: Vector2) -> void:
	var button := Button.new()
	button.name = "Button_" + key
	button.text = label_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 13)
	add_child(button)
	touch_buttons[key] = button
	held[key] = false
	button.button_down.connect(_set_held.bind(key, true))
	button.button_up.connect(_set_held.bind(key, false))

func _add_action_button(key: String, label_text: String, button_position: Vector2, button_size: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Button_" + key
	button.text = label_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 13)
	add_child(button)
	touch_buttons[key] = button
	button.pressed.connect(callback)

func _set_held(key: String, value: bool) -> void:
	held[key] = value

func _toggle_tether() -> void:
	Rules.toggle_tether(state)
	queue_redraw()

func _reset() -> void:
	state = Rules.reset(state)
	queue_redraw()

func _next_mission() -> void:
	state = Rules.next_mission(state)
	queue_redraw()

func _process(delta: float) -> void:
	var thrust := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or bool(held.get("up", false)):
		thrust.y -= 1.0
	if Input.is_key_pressed(KEY_S) or bool(held.get("down", false)):
		thrust.y += 1.0
	if Input.is_key_pressed(KEY_A) or bool(held.get("left", false)):
		thrust.x -= 1.0
	if Input.is_key_pressed(KEY_D) or bool(held.get("right", false)):
		thrust.x += 1.0
	var brake: bool = Input.is_key_pressed(KEY_SHIFT) or bool(held.get("brake", false))
	state = Rules.step(state, delta, {"thrust": thrust, "brake": brake})
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_SPACE:
					_toggle_tether()
				KEY_R:
					_reset()
				KEY_N:
					_next_mission()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.045), true)
	for y in range(30, 620, 40):
		for x in range(30, 900, 40):
			draw_circle(Vector2(x, y), 1.2, Color(0.14, 0.25, 0.34))
	for x in range(0, 901, 100):
		draw_line(Vector2(x, 0), Vector2(x, 620), Color(0.05, 0.11, 0.16), 1.0)
	for y in range(0, 621, 100):
		draw_line(Vector2(0, y), Vector2(900, y), Color(0.05, 0.11, 0.16), 1.0)

	var dock_position: Vector2 = state.get("dock_pos", Vector2(790.0, 310.0))
	draw_circle(dock_position, Rules.DOCK_RADIUS + 9.0, Color(0.04, 0.28, 0.25))
	draw_arc(dock_position, Rules.DOCK_RADIUS, 0.0, TAU, 48, Color(0.3, 1.0, 0.72), 5.0)
	draw_circle(dock_position, 12.0, Color(0.3, 1.0, 0.72))
	draw_string(ThemeDB.fallback_font, dock_position + Vector2(-35.0, -62.0), "KROLL DOCK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.45, 1.0, 0.78))

	for hazard in state.get("hazards", []):
		var hazard_position: Vector2 = hazard.get("position", Vector2.ZERO)
		var hazard_radius: float = float(hazard.get("radius", 30.0))
		draw_circle(hazard_position, hazard_radius, Color(0.24, 0.12, 0.15))
		draw_arc(hazard_position, hazard_radius, 0.0, TAU, 40, Color(1.0, 0.36, 0.3), 3.0)
		draw_arc(hazard_position, hazard_radius + 8.0, 0.0, TAU, 40, Color(0.55, 0.18, 0.22), 1.0)

	var cargo: Array = state.get("cargo", [])
	var tethered_index: int = int(state.get("tethered_index", -1))
	for index in range(cargo.size()):
		var item: Dictionary = cargo[index]
		var cargo_position: Vector2 = item.get("position", Vector2.ZERO)
		var delivered: bool = bool(item.get("delivered", false))
		var cargo_color: Color = Color(0.3, 1.0, 0.72) if delivered else Color(1.0, 0.68, 0.22) if index == tethered_index else Color(0.35, 0.78, 1.0)
		if index == tethered_index:
			draw_line(state.get("drone_pos", Vector2.ZERO), cargo_position, Color(1.0, 0.78, 0.32), 3.0)
		draw_rect(Rect2(cargo_position - Vector2(12.0, 12.0), Vector2(24.0, 24.0)), cargo_color, true)
		draw_rect(Rect2(cargo_position - Vector2(12.0, 12.0), Vector2(24.0, 24.0)), Color(0.06, 0.12, 0.18), false, 2.0)
		draw_string(ThemeDB.fallback_font, cargo_position + Vector2(-8.0, 4.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.03, 0.08, 0.12))

	var drone_position: Vector2 = state.get("drone_pos", Vector2(100.0, 310.0))
	draw_circle(drone_position, Rules.DRONE_RADIUS + 7.0, Color(0.05, 0.32, 0.46))
	draw_circle(drone_position, Rules.DRONE_RADIUS, Color(0.35, 0.9, 1.0))
	draw_line(drone_position, drone_position + Vector2(20.0, 0.0), Color(0.95, 1.0, 1.0), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 36.0), "KROLL TETHER RECOVERY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.42, 0.9, 1.0))
	var delivered_count: int = 0
	for item in cargo:
		if bool(item.get("delivered", false)):
			delivered_count += 1
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 68.0), "MISSION %02d   CARGO %d/3   FUEL %03d   HULL %d   TIME %03d   SCORE %04d" % [
		int(state.get("mission_index", 0)) + 1,
		delivered_count,
		int(state.get("fuel", 0.0)),
		int(state.get("hull", 0)),
		int(state.get("time_left", 0.0)),
		int(state.get("score", 0))
	], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.82, 0.91, 0.96))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 600.0), str(state.get("message", "")), HORIZONTAL_ALIGNMENT_LEFT, 840.0, 15, Color(0.86, 0.91, 0.94))
	var status: String = str(state.get("status", "active"))
	if status != "active":
		draw_string(ThemeDB.fallback_font, Vector2(330.0, 330.0), "MISSION " + status.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(0.9, 0.95, 1.0))
