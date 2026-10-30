extends Node2D

const Rules = preload("res://rules.gd")
const CARGO_SPECS: Array[Dictionary] = [
	{"id": "cargo_1", "position": Vector2(250.0, 530.0)},
	{"id": "cargo_2", "position": Vector2(455.0, 145.0)},
	{"id": "cargo_3", "position": Vector2(700.0, 535.0)},
	{"id": "cargo_4", "position": Vector2(885.0, 145.0)}
]
const RUN_SPEED: float = 340.0
const GRAVITY: float = 1450.0
const JUMP_IMPULSE: float = 560.0

var state: Dictionary = {}
var player: CharacterBody2D
var hud: Label
var message_label: Label
var touch_buttons: Dictionary = {}
var cargo_areas: Dictionary = {}
var goal_area: Area2D
var _touch_left: bool = false
var _touch_right: bool = false
var _touch_jump: bool = false
var _jump_was_down: bool = false
var _message: String = "Collect all four cargo cells, then reach the EXIT."

func _ready() -> void:
	_build_level()
	_build_hud()
	_restart()

func _build_level() -> void:
	_add_platform("Floor", Vector2(550.0, 700.0), Vector2(1100.0, 40.0), Color(0.10, 0.16, 0.22))
	_add_platform("Ceiling", Vector2(550.0, 20.0), Vector2(1100.0, 40.0), Color(0.10, 0.16, 0.22))
	_add_platform("WestWall", Vector2(20.0, 360.0), Vector2(40.0, 720.0), Color(0.10, 0.16, 0.22))
	_add_platform("EastWall", Vector2(1080.0, 360.0), Vector2(40.0, 720.0), Color(0.10, 0.16, 0.22))
	_add_platform("CargoDeck_A", Vector2(300.0, 570.0), Vector2(150.0, 18.0), Color(0.16, 0.35, 0.42))
	_add_platform("CargoDeck_B", Vector2(500.0, 205.0), Vector2(170.0, 18.0), Color(0.16, 0.35, 0.42))
	_add_platform("CargoDeck_C", Vector2(715.0, 565.0), Vector2(170.0, 18.0), Color(0.16, 0.35, 0.42))
	_add_platform("CargoDeck_D", Vector2(885.0, 205.0), Vector2(150.0, 18.0), Color(0.16, 0.35, 0.42))
	for spec in CARGO_SPECS:
		_add_cargo(str(spec["id"]), spec["position"])
	_add_goal()
	player = CharacterBody2D.new()
	player.name = "Courier"
	player.position = Vector2(90.0, 360.0)
	player.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	player.floor_snap_length = 8.0
	player.collision_layer = 1
	player.collision_mask = 1
	var player_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(30.0, 46.0)
	player_shape.shape = rectangle
	player.add_child(player_shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-15,-23), Vector2(15,-23), Vector2(15,23), Vector2(-15,23)])
	visual.color = Color(0.22, 0.86, 0.98)
	player.add_child(visual)
	add_child(player)

func _add_platform(node_name: String, center: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-size.x*0.5,-size.y*0.5), Vector2(size.x*0.5,-size.y*0.5), Vector2(size.x*0.5,size.y*0.5), Vector2(-size.x*0.5,size.y*0.5)])
	visual.color = color
	body.add_child(visual)
	add_child(body)

func _add_cargo(cargo_id: String, position: Vector2) -> void:
	var area := Area2D.new()
	area.name = cargo_id
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 19.0
	collision.shape = circle
	area.add_child(collision)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0,-18), Vector2(14,0), Vector2(0,18), Vector2(-14,0)])
	diamond.color = Color(1.0, 0.68, 0.18)
	area.add_child(diamond)
	area.body_entered.connect(_on_cargo_body_entered.bind(cargo_id))
	add_child(area)
	cargo_areas[cargo_id] = area

func _add_goal() -> void:
	goal_area = Area2D.new()
	goal_area.name = "ExitGate"
	goal_area.position = Vector2(1030.0, 360.0)
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44.0, 140.0)
	collision.shape = shape
	goal_area.add_child(collision)
	var gate := Polygon2D.new()
	gate.polygon = PackedVector2Array([Vector2(-22,-70), Vector2(22,-70), Vector2(22,70), Vector2(-22,70)])
	gate.color = Color(0.12, 0.78, 0.52, 0.42)
	goal_area.add_child(gate)
	goal_area.body_entered.connect(_on_goal_body_entered)
	add_child(goal_area)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18.0, 14.0)
	hud.size = Vector2(900.0, 76.0)
	hud.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)
	message_label = Label.new()
	message_label.position = Vector2(18.0, 92.0)
	message_label.size = Vector2(900.0, 34.0)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	layer.add_child(message_label)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -190.0
	panel.offset_right = 190.0
	panel.offset_top = -88.0
	panel.offset_bottom = -8.0
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_add_touch_button(row, "left", "LEFT")
	_add_touch_button(row, "right", "RIGHT")
	_add_touch_button(row, "jump", "JUMP")
	_add_touch_button(row, "flip", "FLIP")

func _add_touch_button(parent: HBoxContainer, key: String, text_value: String) -> void:
	var button := Button.new()
	button.name = "Touch_" + key
	button.text = text_value
	button.custom_minimum_size = Vector2(84.0, 54.0)
	parent.add_child(button)
	touch_buttons[key] = button
	match key:
		"left":
			button.button_down.connect(_set_touch_left.bind(true))
			button.button_up.connect(_set_touch_left.bind(false))
		"right":
			button.button_down.connect(_set_touch_right.bind(true))
			button.button_up.connect(_set_touch_right.bind(false))
		"jump":
			button.button_down.connect(_set_touch_jump.bind(true))
			button.button_up.connect(_set_touch_jump.bind(false))
		"flip":
			button.pressed.connect(_flip_gravity)

func _set_touch_left(value: bool) -> void:
	_touch_left = value

func _set_touch_right(value: bool) -> void:
	_touch_right = value

func _set_touch_jump(value: bool) -> void:
	_touch_jump = value

func _physics_process(delta: float) -> void:
	if player == null or str(state.get("result", "")) != "playing":
		return
	var axis: float = 0.0
	if Input.is_key_pressed(KEY_A) or _touch_left:
		axis -= 1.0
	if Input.is_key_pressed(KEY_D) or _touch_right:
		axis += 1.0
	player.velocity.x = axis * RUN_SPEED
	var gravity_sign: int = int(state.get("gravity_sign", 1))
	var attached: bool = player.is_on_floor() if gravity_sign > 0 else player.is_on_ceiling()
	if attached:
		player.velocity.y = 0.0
	else:
		player.velocity.y += float(gravity_sign) * GRAVITY * delta
	var jump_down: bool = Input.is_key_pressed(KEY_SPACE) or _touch_jump
	if jump_down and not _jump_was_down and attached:
		player.velocity.y = -float(gravity_sign) * JUMP_IMPULSE
	_jump_was_down = jump_down
	player.move_and_slide()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			_flip_gravity()
		KEY_R:
			_restart()

func _flip_gravity() -> void:
	var result: Dictionary = Rules.flip_gravity(state)
	if not bool(result.get("ok", false)):
		_message = "Gravity control is locked after the mission ends."
		_refresh_ui()
		return
	state = result["state"]
	player.velocity.y = -player.velocity.y
	_message = "Gravity reversed. Use the opposite surface to jump."
	_refresh_ui()

func _on_cargo_body_entered(body: Node2D, cargo_id: String) -> void:
	if body != player:
		return
	var result: Dictionary = Rules.collect_cargo(state, cargo_id)
	if not bool(result.get("ok", false)):
		return
	state = result["state"]
	if cargo_areas.has(cargo_id):
		var area: Area2D = cargo_areas[cargo_id] as Area2D
		area.visible = false
		area.set_deferred("monitoring", false)
		var collision := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.set_deferred("disabled", true)
	_message = "Cargo secured: %d / %d." % [state["collected"].size(), Rules.REQUIRED_CARGO]
	_refresh_ui()

func _on_goal_body_entered(body: Node2D) -> void:
	if body != player:
		return
	var result: Dictionary = Rules.try_exit(state)
	if bool(result.get("ok", false)):
		state = result["state"]
		_message = "DELIVERY COMPLETE // all cargo recovered."
	else:
		_message = "EXIT LOCKED // collect all four cargo cells first."
	_refresh_ui()

func _restart() -> void:
	state = Rules.new_game()
	_message = "Collect all four cargo cells, then reach the EXIT."
	if is_instance_valid(player):
		player.position = Vector2(90.0, 360.0)
		player.velocity = Vector2.ZERO
	for area_value in cargo_areas.values():
		var area := area_value as Area2D
		if not is_instance_valid(area):
			continue
		area.visible = true
		area.set_deferred("monitoring", true)
		var collision := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.set_deferred("disabled", false)
	_jump_was_down = false
	_refresh_ui()

func _refresh_ui() -> void:
	if hud == null:
		return
	var gravity_label: String = "DOWN" if int(state.get("gravity_sign", 1)) > 0 else "UP"
	hud.text = "KROLL // GRAVITY COURIER     GRAVITY: %s     CARGO: %d / %d     FLIPS: %d" % [
		gravity_label, state.get("collected", []).size(), Rules.REQUIRED_CARGO, int(state.get("flip_count", 0))
	]
	message_label.text = _message
	var finished: bool = str(state.get("result", "")) != "playing"
	for button_value in touch_buttons.values():
		(button_value as Button).disabled = finished
