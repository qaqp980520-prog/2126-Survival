extends Node2D

const Rules = preload("res://rules.gd")
const START_POSITION: Vector2 = Vector2(480.0, 1680.0)
const WORLD_WIDTH: float = 960.0
const WORLD_BOTTOM: float = 1820.0
const GRAVITY: float = 1050.0
const JUMP_SPEED: float = 560.0
const MOVE_SPEED: float = 240.0

var state: Dictionary = {}
var player: CharacterBody2D
var camera: Camera2D
var hud: Label
var goal_visual: Polygon2D
var platforms: Array[StaticBody2D] = []
var pickups: Dictionary = {}
var hazards: Array[Area2D] = []
var _elapsed: float = 0.0
var _hud_clock: float = 0.0
var _touch_left: bool = false
var _touch_right: bool = false
var _jump_queued: bool = false
var _jump_was_down: bool = false

func _ready() -> void:
	state = Rules.new_state()
	_build_level()
	_build_player()
	_build_pickups_and_goal()
	_build_hud()
	_reset_game()

func _process(delta: float) -> void:
	if str(state.get("status", "playing")) != "playing":
		return
	state = Rules.tick(state, delta)
	_elapsed += delta
	for hazard: Area2D in hazards:
		var origin_x: float = float(hazard.get_meta("origin_x", hazard.position.x))
		var amplitude: float = float(hazard.get_meta("amplitude", 0.0))
		var phase: float = float(hazard.get_meta("phase", 0.0))
		hazard.position.x = origin_x + sin(_elapsed * 1.7 + phase) * amplitude
	_hud_clock += delta
	if str(state.get("status", "playing")) != "playing" or _hud_clock >= 0.1:
		_hud_clock = 0.0
		_refresh_hud()

func _physics_process(delta: float) -> void:
	if player == null or str(state.get("status", "playing")) != "playing":
		return
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or _touch_left:
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or _touch_right:
		direction += 1.0
	player.velocity.x = direction * MOVE_SPEED
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	elif player.velocity.y > 0.0:
		player.velocity.y = 0.0

	var jump_down: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	if (_jump_queued or (jump_down and not _jump_was_down)) and player.is_on_floor():
		player.velocity.y = -JUMP_SPEED
	_jump_queued = false
	_jump_was_down = jump_down
	player.move_and_slide()
	if player.global_position.y > WORLD_BOTTOM:
		state = Rules.fail(state, "fell")
		_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_reset_game()

func _build_level() -> void:
	_add_platform(Vector2(480.0, 1710.0), Vector2(440.0, 24.0))
	var specs: Array[Dictionary] = [
		{"x": 300.0, "y": 1560.0, "width": 200.0},
		{"x": 590.0, "y": 1425.0, "width": 200.0},
		{"x": 360.0, "y": 1290.0, "width": 200.0},
		{"x": 620.0, "y": 1155.0, "width": 180.0},
		{"x": 430.0, "y": 1020.0, "width": 190.0},
		{"x": 220.0, "y": 885.0, "width": 170.0},
		{"x": 500.0, "y": 750.0, "width": 180.0},
		{"x": 720.0, "y": 615.0, "width": 160.0},
		{"x": 470.0, "y": 480.0, "width": 190.0},
		{"x": 260.0, "y": 345.0, "width": 180.0},
		{"x": 480.0, "y": 210.0, "width": 220.0}
	]
	for spec: Dictionary in specs:
		_add_platform(Vector2(float(spec["x"]), float(spec["y"])), Vector2(float(spec["width"]), 18.0))
	_add_platform(Vector2(0.0, 900.0), Vector2(24.0, 1800.0))
	_add_platform(Vector2(WORLD_WIDTH, 900.0), Vector2(24.0, 1800.0))
	_add_hazard(Vector2(620.0, 1135.0), 48.0, 0.2)
	_add_hazard(Vector2(500.0, 730.0), 58.0, 1.8)

func _add_platform(position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5)
	])
	visual.color = Color("#1a4054")
	body.add_child(visual)
	add_child(body)
	platforms.append(body)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = START_POSITION
	player.collision_layer = 1
	player.collision_mask = 1
	player.floor_snap_length = 8.0
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 11.0
	capsule.height = 34.0
	collision.shape = capsule
	player.add_child(collision)
	var body_visual := Polygon2D.new()
	body_visual.polygon = PackedVector2Array([
		Vector2(-10.0, -14.0), Vector2(10.0, -14.0),
		Vector2(12.0, 0.0), Vector2(7.0, 16.0),
		Vector2(-7.0, 16.0), Vector2(-12.0, 0.0)
	])
	body_visual.color = Color("#50e3c2")
	player.add_child(body_visual)
	add_child(player)
	camera = Camera2D.new()
	camera.name = "ClimbCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_BOTTOM)
	player.add_child(camera)
	camera.make_current()

func _build_pickups_and_goal() -> void:
	var data_spawns: Array[Vector2] = [
		Vector2(300.0, 1527.0),
		Vector2(360.0, 1257.0),
		Vector2(430.0, 987.0),
		Vector2(500.0, 717.0),
		Vector2(260.0, 312.0)
	]
	for index: int in range(data_spawns.size()):
		var data_id: String = "relay_data_%02d" % (index + 1)
		_add_pickup(data_id, data_spawns[index])
	var goal := Area2D.new()
	goal.name = "ExtractionGate"
	goal.position = Vector2(480.0, 140.0)
	goal.collision_layer = 0
	goal.collision_mask = 1
	var goal_collision := CollisionShape2D.new()
	var goal_shape := RectangleShape2D.new()
	goal_shape.size = Vector2(72.0, 100.0)
	goal_collision.shape = goal_shape
	goal.add_child(goal_collision)
	goal_visual = Polygon2D.new()
	goal_visual.polygon = PackedVector2Array([
		Vector2(-36.0, -50.0), Vector2(36.0, -50.0),
		Vector2(36.0, 50.0), Vector2(-36.0, 50.0)
	])
	goal_visual.color = Color("#5a6676")
	goal.add_child(goal_visual)
	goal.body_entered.connect(_on_goal_body_entered)
	add_child(goal)

func _add_pickup(data_id: String, position: Vector2) -> void:
	var area := Area2D.new()
	area.name = data_id
	area.position = position
	area.collision_layer = 2
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	collision.shape = circle
	area.add_child(collision)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0.0, -13.0), Vector2(10.0, 0.0),
		Vector2(0.0, 13.0), Vector2(-10.0, 0.0)
	])
	diamond.color = Color("#ffd166")
	area.add_child(diamond)
	area.body_entered.connect(_on_pickup_body_entered.bind(area, data_id))
	add_child(area)
	pickups[data_id] = area

func _add_hazard(position: Vector2, amplitude: float, phase: float) -> void:
	var hazard := Area2D.new()
	hazard.name = "PatrolHazard_%d" % hazards.size()
	hazard.position = position
	hazard.collision_layer = 0
	hazard.collision_mask = 1
	hazard.set_meta("origin_x", position.x)
	hazard.set_meta("amplitude", amplitude)
	hazard.set_meta("phase", phase)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(68.0, 12.0)
	collision.shape = shape
	hazard.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-34.0, -6.0), Vector2(34.0, -6.0),
		Vector2(34.0, 6.0), Vector2(-34.0, 6.0)
	])
	visual.color = Color("#ff754f")
	hazard.add_child(visual)
	hazard.body_entered.connect(_on_hazard_body_entered)
	add_child(hazard)
	hazards.append(hazard)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18.0, 14.0)
	hud.size = Vector2(680.0, 86.0)
	hud.add_theme_color_override("font_color", Color("#d8f5ff"))
	hud.add_theme_font_size_override("font_size", 17)
	layer.add_child(hud)
	_add_touch_button(layer, "◀", Vector2(22.0, 448.0), Vector2(82.0, 66.0), Callable(self, "_on_left_down"), Callable(self, "_on_left_up"))
	_add_touch_button(layer, "▶", Vector2(112.0, 448.0), Vector2(82.0, 66.0), Callable(self, "_on_right_down"), Callable(self, "_on_right_up"))
	_add_touch_button(layer, "JUMP", Vector2(814.0, 448.0), Vector2(124.0, 66.0), Callable(self, "_on_jump_down"), Callable())

func _add_touch_button(layer: CanvasLayer, text_value: String, position: Vector2, size: Vector2, on_down: Callable, on_up: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 19)
	button.button_down.connect(on_down)
	if on_up.is_valid():
		button.button_up.connect(on_up)
	layer.add_child(button)

func _on_left_down() -> void:
	_touch_left = true

func _on_left_up() -> void:
	_touch_left = false

func _on_right_down() -> void:
	_touch_right = true

func _on_right_up() -> void:
	_touch_right = false

func _on_jump_down() -> void:
	_jump_queued = true

func _on_pickup_body_entered(body: Node2D, pickup: Area2D, data_id: String) -> void:
	if body != player or str(state.get("status", "playing")) != "playing":
		return
	state = Rules.collect_data(state, data_id)
	if str(state.get("last_action", "")) == "data_collected":
		pickup.monitoring = false
		pickup.visible = false
		_refresh_hud()

func _on_goal_body_entered(body: Node2D) -> void:
	if body != player:
		return
	state = Rules.reach_exit(state)
	_refresh_hud()

func _on_hazard_body_entered(body: Node2D) -> void:
	if body != player:
		return
	state = Rules.fail(state, "hazard")
	_refresh_hud()

func _reset_game() -> void:
	state = Rules.new_state()
	_elapsed = 0.0
	_hud_clock = 0.0
	_touch_left = false
	_touch_right = false
	_jump_queued = false
	_jump_was_down = false
	if player != null:
		player.position = START_POSITION
		player.velocity = Vector2.ZERO
	for data_id in pickups.keys():
		var pickup: Area2D = pickups[data_id]
		pickup.visible = true
		pickup.monitoring = true
	for hazard: Area2D in hazards:
		hazard.position.x = float(hazard.get_meta("origin_x", hazard.position.x))
	if hud != null:
		_refresh_hud()

func _refresh_hud() -> void:
	if hud == null:
		return
	var data_ids: Array = state.get("data_ids", [])
	var status: String = str(state.get("status", "playing")).to_upper()
	hud.text = "KROLL // VERTICAL RELAY     DATA %d / %d     TIME %02d s\nA / D or arrows: move   W / SPACE: jump   R: restart\n%s" % [data_ids.size(), Rules.REQUIRED_DATA, ceili(float(state.get("remaining_time", Rules.TIME_LIMIT))), status]
	if goal_visual != null:
		goal_visual.color = Color("#50e3c2") if data_ids.size() >= Rules.REQUIRED_DATA else Color("#5a6676")
