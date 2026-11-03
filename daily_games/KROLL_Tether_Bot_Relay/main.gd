extends Node2D

const GRAVITY: float = 1100.0
const BOOST_SPEED: float = 560.0
const COURSE_TIME_LIMIT: float = 90.0
const MAX_FALLS: int = 3
const COURSES: Array = [
	{
		"name": "Dockyard Relay",
		"start": Vector2(75.0, 620.0),
		"anchors": [Vector2(245.0, 470.0), Vector2(520.0, 380.0), Vector2(790.0, 310.0)],
		"platforms": [
			Rect2(0.0, 650.0, 250.0, 70.0),
			Rect2(350.0, 560.0, 170.0, 28.0),
			Rect2(620.0, 470.0, 170.0, 28.0),
			Rect2(835.0, 390.0, 125.0, 330.0)
		],
		"goal": Rect2(865.0, 325.0, 65.0, 60.0)
	},
	{
		"name": "Broken Gantry",
		"start": Vector2(75.0, 620.0),
		"anchors": [Vector2(180.0, 475.0), Vector2(430.0, 350.0), Vector2(690.0, 360.0)],
		"platforms": [
			Rect2(0.0, 650.0, 180.0, 70.0),
			Rect2(280.0, 575.0, 140.0, 28.0),
			Rect2(510.0, 455.0, 140.0, 28.0),
			Rect2(760.0, 535.0, 200.0, 28.0)
		],
		"goal": Rect2(875.0, 465.0, 60.0, 60.0)
	},
	{
		"name": "Spiral Service Shaft",
		"start": Vector2(75.0, 620.0),
		"anchors": [Vector2(170.0, 475.0), Vector2(390.0, 355.0), Vector2(600.0, 255.0), Vector2(820.0, 215.0)],
		"platforms": [
			Rect2(0.0, 650.0, 170.0, 70.0),
			Rect2(250.0, 570.0, 130.0, 28.0),
			Rect2(460.0, 470.0, 130.0, 28.0),
			Rect2(670.0, 370.0, 130.0, 28.0),
			Rect2(840.0, 300.0, 120.0, 420.0)
		],
		"goal": Rect2(875.0, 235.0, 65.0, 60.0)
	}
]

var rules: Variant
var course_index: int = 0
var player: CharacterBody2D
var start_position: Vector2 = Vector2.ZERO
var anchor_points: Array[Vector2] = []
var platforms: Array[Rect2] = []
var goal_rect: Rect2 = Rect2()
var falls_this_course: int = 0
var total_score: int = 0
var time_remaining: float = COURSE_TIME_LIMIT
var status: String = "playing"
var message: String = "Connect to a maintenance node, use thruster bursts, and reach the green service gate."
var _platform_bodies: Array[StaticBody2D] = []
var _tether_anchor_index: int = -1
var _rope_length: float = 0.0
var _left_held: bool = false
var _right_held: bool = false
var _boost_requested: bool = false
var _touch_control_count: int = 0

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Tether Bot Relay main script is unavailable.")
		return
	var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Tether Bot Relay could not load rules: " + rules_path)
		return
	rules = rules_script.new() as RefCounted
	if rules == null:
		push_error("Tether Bot Relay rules instance could not be created.")
		return
	_build_player()
	_load_course()
	_build_touch_controls()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if status != "playing" or not is_instance_valid(player):
		return
	time_remaining = maxf(0.0, time_remaining - maxf(delta, 0.0))
	if time_remaining <= 0.0:
		status = "failed"
		message = "Time expired. Press R to retry this course."
		_detach_tether()
		queue_redraw()
		return

	var horizontal_axis: float = 0.0
	if _left_held or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal_axis -= 1.0
	if _right_held or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal_axis += 1.0
	player.velocity = rules.apply_horizontal(player.velocity, horizontal_axis, delta, player.is_on_floor())

	if _boost_requested:
		if player.is_on_floor():
			player.velocity.y = -BOOST_SPEED
		_boost_requested = false

	if _tether_anchor_index >= 0 and _tether_anchor_index < anchor_points.size():
		var anchor: Vector2 = anchor_points[_tether_anchor_index]
		var constrained: Dictionary = rules.constrain_rope(player.global_position, player.velocity, anchor, _rope_length)
		player.global_position = constrained["position"]
		player.velocity = constrained["velocity"]

	player.velocity.y += GRAVITY * maxf(delta, 0.0)
	player.move_and_slide()

	if _tether_anchor_index >= 0 and _tether_anchor_index < anchor_points.size():
		var post_move_anchor: Vector2 = anchor_points[_tether_anchor_index]
		var post_move: Dictionary = rules.constrain_rope(player.global_position, player.velocity, post_move_anchor, _rope_length)
		player.global_position = post_move["position"]
		player.velocity = post_move["velocity"]

	if player.global_position.y > 790.0:
		_register_fall()
	elif rules.goal_contains(player.global_position, goal_rect):
		_complete_course()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_SPACE:
				_request_boost()
			KEY_E:
				toggle_tether()
			KEY_R:
				restart_course()
			KEY_N:
				advance_course()
			KEY_C:
				restart_campaign()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.position.y < 640.0:
			toggle_tether()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and touch_event.position.y < 640.0:
			toggle_tether()

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 1
	player.collision_mask = 1
	player.floor_snap_length = 8.0
	var collision := CollisionShape2D.new()
	collision.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	collision.shape = circle
	player.add_child(collision)
	add_child(player)

func _load_course() -> void:
	var data: Dictionary = COURSES[course_index]
	start_position = data["start"]
	anchor_points.clear()
	for anchor_value in data["anchors"]:
		var anchor: Vector2 = anchor_value
		anchor_points.append(anchor)
	platforms.clear()
	for old_body in _platform_bodies:
		if is_instance_valid(old_body):
			old_body.queue_free()
	_platform_bodies.clear()
	for platform_value in data["platforms"]:
		var platform_rect: Rect2 = platform_value
		platforms.append(platform_rect)
		var body := StaticBody2D.new()
		body.name = "Platform_%d" % _platform_bodies.size()
		body.position = platform_rect.position + platform_rect.size * 0.5
		body.collision_layer = 1
		body.collision_mask = 1
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = platform_rect.size
		collision.shape = rectangle
		body.add_child(collision)
		add_child(body)
		_platform_bodies.append(body)
	goal_rect = data["goal"]
	falls_this_course = 0
	time_remaining = COURSE_TIME_LIMIT
	status = "playing"
	_detach_tether()
	_boost_requested = false
	player.global_position = start_position
	player.velocity = Vector2.ZERO
	message = str(data["name"]) + ": drift between maintenance nodes and land inside the green service gate."
	queue_redraw()

func _register_fall() -> void:
	if status != "playing":
		return
	falls_this_course += 1
	_detach_tether()
	if falls_this_course >= MAX_FALLS:
		status = "failed"
		message = "Three falls. Press R to retry this course."
	else:
		player.global_position = start_position
		player.velocity = Vector2.ZERO
		message = "Recovery %d/%d. Try a different route." % [falls_this_course, MAX_FALLS]
	queue_redraw()

func _complete_course() -> void:
	if status != "playing":
		return
	var awarded: int = rules.calculate_score(time_remaining, falls_this_course)
	total_score += awarded
	_detach_tether()
	if course_index >= COURSES.size() - 1:
		status = "won"
		message = "All three service routes cleared! Campaign complete."
	else:
		status = "course_clear"
		message = "Course cleared: +%d points. Press N for the next rig." % awarded
	queue_redraw()

func toggle_tether() -> bool:
	if status != "playing" or not is_instance_valid(player):
		return false
	if _tether_anchor_index >= 0:
		_detach_tether()
		message = "Tether released. Keep your drift momentum."
		queue_redraw()
		return true
	var selected: int = rules.nearest_tether_node(player.global_position, anchor_points)
	if selected < 0:
		message = "No maintenance node is within tether range."
		queue_redraw()
		return false
	_tether_anchor_index = selected
	_rope_length = rules.calculate_rope_length(player.global_position.distance_to(anchor_points[selected]))
	message = "Tether connected to node %d. Use left/right to build drift momentum." % [selected + 1]
	queue_redraw()
	return true

func _detach_tether() -> void:
	_tether_anchor_index = -1
	_rope_length = 0.0

func restart_course() -> bool:
	if status == "course_clear" or status == "won":
		return false
	_load_course()
	return true

func advance_course() -> bool:
	if status != "course_clear" or course_index >= COURSES.size() - 1:
		return false
	course_index += 1
	_load_course()
	return true

func restart_campaign() -> bool:
	course_index = 0
	total_score = 0
	_load_course()
	return true

func _request_boost() -> void:
	if status == "playing":
		_boost_requested = true

func _set_left_held(value: bool) -> void:
	_left_held = value

func _set_right_held(value: bool) -> void:
	_right_held = value

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchControls"
	add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_control)
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.02
	bar.anchor_right = 0.98
	bar.anchor_top = 0.89
	bar.anchor_bottom = 0.99
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = 0.0
	bar.add_theme_constant_override("separation", 6)
	root_control.add_child(bar)

	var left_button: Button = _add_touch_button(bar, "LEFT")
	left_button.button_down.connect(_set_left_held.bind(true))
	left_button.button_up.connect(_set_left_held.bind(false))
	var right_button: Button = _add_touch_button(bar, "RIGHT")
	right_button.button_down.connect(_set_right_held.bind(true))
	right_button.button_up.connect(_set_right_held.bind(false))
	var boost_button: Button = _add_touch_button(bar, "BOOST")
	boost_button.pressed.connect(_request_boost)
	var hook_button: Button = _add_touch_button(bar, "TETHER")
	hook_button.pressed.connect(toggle_tether)
	var reset_button: Button = _add_touch_button(bar, "RESET")
	reset_button.pressed.connect(restart_course)
	var next_button: Button = _add_touch_button(bar, "NEXT")
	next_button.pressed.connect(advance_course)

func _add_touch_button(parent: HBoxContainer, label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(112.0, 58.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	_touch_control_count += 1
	return button

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 720.0)), Color("#07111e"), true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(24.0, 34.0), "KROLL // TETHER BOT RELAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#91e8ff"))
	draw_string(font, Vector2(24.0, 58.0), "Guide the maintenance drone between tether nodes and release at the right moment to reach the green service gate.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c2d7e8"))
	draw_string(font, Vector2(24.0, 84.0), "COURSE %d/%d   FALLS %d/%d   TIME %.1f   SCORE %d" % [course_index + 1, COURSES.size(), falls_this_course, MAX_FALLS, time_remaining, total_score], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f4d58d"))

	for grid_x in range(40, 960, 40):
		draw_line(Vector2(float(grid_x), 100.0), Vector2(float(grid_x), 650.0), Color(0.18, 0.42, 0.54, 0.18), 1.0)
	for grid_y in range(120, 650, 40):
		draw_line(Vector2(0.0, float(grid_y)), Vector2(960.0, float(grid_y)), Color(0.18, 0.42, 0.54, 0.18), 1.0)

	for platform_rect in platforms:
		draw_rect(platform_rect.grow(3.0), Color(0.16, 0.72, 0.78, 0.16), true)
		draw_rect(platform_rect, Color("#24485d"), true)
		draw_rect(platform_rect, Color("#6ab8d0"), false, 2.0)

	draw_rect(goal_rect, Color(0.22, 0.88, 0.55, 0.22), true)
	draw_rect(goal_rect, Color("#7bf0b0"), false, 3.0)
	for index in range(anchor_points.size()):
		var anchor: Vector2 = anchor_points[index]
		draw_circle(anchor, 17.0, Color(0.28, 0.75, 1.0, 0.15))
		draw_circle(anchor, 8.0, Color("#6bdcff"))
		draw_arc(anchor, 18.0, 0.0, TAU, 32, Color("#b8f1ff"), 2.0)
		draw_string(font, anchor + Vector2(22.0, 5.0), "N%d" % [index + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b8f1ff"))
	if _tether_anchor_index >= 0 and _tether_anchor_index < anchor_points.size() and is_instance_valid(player):
		draw_line(anchor_points[_tether_anchor_index], player.global_position, Color("#f4d58d"), 3.0)
		draw_circle(anchor_points[_tether_anchor_index], _rope_length, Color(0.96, 0.82, 0.48, 0.06), false, 1.0)
	if is_instance_valid(player):
		var drone_body := Rect2(player.global_position - Vector2(14.0, 10.0), Vector2(28.0, 20.0))
		draw_rect(drone_body.grow(3.0), Color(0.28, 0.75, 1.0, 0.12), true)
		draw_rect(drone_body, Color("#f4d58d"), true)
		draw_rect(drone_body, Color("#fff0c2"), false, 2.0)
		draw_circle(player.global_position, 4.0, Color("#07111e"))
		draw_line(player.global_position + Vector2(0.0, -10.0), player.global_position + Vector2(0.0, -17.0), Color("#b8f1ff"), 2.0)
		draw_circle(player.global_position + Vector2(0.0, -18.0), 3.0, Color("#6bdcff"))
	draw_string(font, Vector2(24.0, 625.0), message, HORIZONTAL_ALIGNMENT_LEFT, 900, 14, Color("#d5e4ee"))

func get_title_text() -> String:
	return "KROLL // TETHER BOT RELAY"

func get_course_count() -> int:
	return COURSES.size()

func get_tether_node_count() -> int:
	return anchor_points.size()

func get_tether_node_position(index: int) -> Vector2:
	if index < 0 or index >= anchor_points.size():
		return Vector2(-9999.0, -9999.0)
	return anchor_points[index]

func get_touch_control_count() -> int:
	return _touch_control_count

func get_status() -> String:
	return status

func get_course_index() -> int:
	return course_index

func get_total_score() -> int:
	return total_score

func get_goal_center() -> Vector2:
	return goal_rect.get_center()

func get_player_position() -> Vector2:
	return player.global_position if is_instance_valid(player) else Vector2.ZERO

func set_player_position_for_test(position: Vector2) -> void:
	if is_instance_valid(player):
		player.global_position = position

func check_goal_for_test() -> void:
	if is_instance_valid(player) and rules.goal_contains(player.global_position, goal_rect):
		_complete_course()

func is_tether_attached() -> bool:
	return _tether_anchor_index >= 0

func get_tether_anchor_index() -> int:
	return _tether_anchor_index
