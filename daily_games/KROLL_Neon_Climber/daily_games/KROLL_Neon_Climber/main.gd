extends Node2D

const Rules = preload("res://daily_games/KROLL_Neon_Climber/rules.gd")

var _state: Dictionary = {}
var _level_root: Node2D
var _player: CharacterBody2D
var _hud: Label
var _message_label: Label
var _exit_visual: Polygon2D
var _core_nodes: Dictionary = {}
var _checkpoint_position: Vector2 = Vector2.ZERO
var _touch_left: bool = false
var _touch_right: bool = false
var _jump_pending: bool = false
var _dash_pending: bool = false
var _jumps_used: int = 0
var _facing: int = 1
var _dash_remaining: float = 0.0
var _dash_cooldown: float = 0.0

func _ready() -> void:
	_build_ui()
	_load_level(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameHUD"
	add_child(layer)
	_hud = Label.new()
	_hud.name = "StatusLabel"
	_hud.position = Vector2(18.0, 14.0)
	_hud.size = Vector2(900.0, 68.0)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_color", Color("#b8f7ff"))
	layer.add_child(_hud)
	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.position = Vector2(18.0, 86.0)
	_message_label.size = Vector2(900.0, 42.0)
	_message_label.add_theme_color_override("font_color", Color("#ffd68a"))
	layer.add_child(_message_label)
	var controls := HBoxContainer.new()
	controls.name = "TouchControls"
	controls.anchor_left = 0.5
	controls.anchor_right = 0.5
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = -250.0
	controls.offset_right = 250.0
	controls.offset_top = -76.0
	controls.offset_bottom = -12.0
	controls.add_theme_constant_override("separation", 10)
	layer.add_child(controls)
	var left := _make_button("LEFT", Vector2(84, 56))
	left.button_down.connect(_set_touch_left.bind(true))
	left.button_up.connect(_set_touch_left.bind(false))
	controls.add_child(left)
	var right := _make_button("RIGHT", Vector2(84, 56))
	right.button_down.connect(_set_touch_right.bind(true))
	right.button_up.connect(_set_touch_right.bind(false))
	controls.add_child(right)
	var jump := _make_button("JUMP", Vector2(92, 56))
	jump.button_down.connect(_queue_jump)
	controls.add_child(jump)
	var dash := _make_button("DASH", Vector2(92, 56))
	dash.button_down.connect(_queue_dash)
	controls.add_child(dash)

func _make_button(label_text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	return button

func _load_level(level_index: int) -> void:
	if _level_root != null and is_instance_valid(_level_root):
		_level_root.queue_free()
	_state = Rules.new_run(level_index)
	_core_nodes.clear()
	_jumps_used = 0
	_facing = 1
	_dash_remaining = 0.0
	_dash_cooldown = 0.0
	_jump_pending = false
	_dash_pending = false
	_touch_left = false
	_touch_right = false
	_level_root = Node2D.new()
	_level_root.name = "Level_" + str(_state["level_id"])
	add_child(_level_root)
	var level: Dictionary = Rules.get_level(level_index)
	var size: Vector2i = level["size"]
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(float(size.x), 0.0),
		Vector2(float(size.x), float(size.y)),
		Vector2(0.0, float(size.y))
	])
	background.color = Color("#091526")
	_level_root.add_child(background)
	for platform in level["platforms"]:
		_make_platform(platform)
	for hazard in level["hazards"]:
		_make_hazard(hazard)
	for core in level["cores"]:
		_make_core(str(core["id"]), core["position"])
	_make_checkpoint(str(level["checkpoint_id"]), level["checkpoint_position"])
	_make_exit(level["exit"])
	_checkpoint_position = level["spawn"]
	_make_player(level["spawn"], size)
	_message_label.text = "Collect all three data cores, touch the beacon, then reach the exit."
	_refresh_hud()

func _make_platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "Platform"
	body.position = rect.position + rect.size * 0.5
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	collision.shape = box
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, rect.size.y * 0.5),
		Vector2(-rect.size.x * 0.5, rect.size.y * 0.5)
	])
	visual.color = Color("#1a6279")
	body.add_child(visual)
	_level_root.add_child(body)

func _make_hazard(rect: Rect2) -> void:
	var area := Area2D.new()
	area.name = "LaserHazard"
	area.position = rect.position + rect.size * 0.5
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	collision.shape = box
	area.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, rect.size.y * 0.5),
		Vector2(-rect.size.x * 0.5, rect.size.y * 0.5)
	])
	visual.color = Color("#ff4d72")
	area.add_child(visual)
	area.body_entered.connect(_on_hazard_body_entered)
	_level_root.add_child(area)

func _make_core(core_id: String, position: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Core_" + core_id
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	collision.shape = circle
	area.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -15), Vector2(12, 0), Vector2(0, 15), Vector2(-12, 0)
	])
	visual.color = Color("#55f0d0")
	area.add_child(visual)
	area.body_entered.connect(_on_core_body_entered.bind(core_id))
	_core_nodes[core_id] = area
	_level_root.add_child(area)

func _make_checkpoint(checkpoint_id: String, position: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Checkpoint_" + checkpoint_id
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(46, 86)
	collision.shape = box
	area.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-18, 42), Vector2(-18, -42), Vector2(18, -42), Vector2(18, 42)
	])
	visual.color = Color("#ffcf62")
	area.add_child(visual)
	area.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint_id, position))
	_level_root.add_child(area)

func _make_exit(rect: Rect2) -> void:
	var area := Area2D.new()
	area.name = "ExitGate"
	area.position = rect.position + rect.size * 0.5
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	collision.shape = box
	area.add_child(collision)
	_exit_visual = Polygon2D.new()
	_exit_visual.polygon = PackedVector2Array([
		Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
		Vector2(rect.size.x * 0.5, rect.size.y * 0.5),
		Vector2(-rect.size.x * 0.5, rect.size.y * 0.5)
	])
	_exit_visual.color = Color("#a34b68")
	area.add_child(_exit_visual)
	area.body_entered.connect(_on_exit_body_entered)
	_level_root.add_child(area)

func _make_player(spawn: Vector2, level_size: Vector2i) -> void:
	_player = CharacterBody2D.new()
	_player.name = "Climber"
	_player.position = spawn
	_player.collision_layer = 1
	_player.collision_mask = 1
	_player.floor_snap_length = 8.0
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14.0
	capsule.height = 44.0
	collision.shape = capsule
	_player.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-12, -20), Vector2(12, -20), Vector2(14, 18), Vector2(-14, 18)
	])
	visual.color = Color("#70d9ff")
	_player.add_child(visual)
	var camera := Camera2D.new()
	camera.name = "FollowCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = level_size.x
	camera.limit_bottom = level_size.y
	camera.enabled = true
	_player.add_child(camera)
	_level_root.add_child(_player)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or str(_state.get("status", "")) != "playing":
		return
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if _player.is_on_floor():
		_jumps_used = 0
		if _player.velocity.y > 0.0:
			_player.velocity.y = 0.0
	var axis: float = 0.0
	if Input.is_key_pressed(KEY_A) or _touch_left:
		axis -= 1.0
	if Input.is_key_pressed(KEY_D) or _touch_right:
		axis += 1.0
	if not is_zero_approx(axis):
		_facing = 1 if axis > 0.0 else -1
	if _jump_pending:
		if _jumps_used < Rules.MAX_JUMPS:
			_player.velocity.y = -Rules.JUMP_SPEED
			_jumps_used += 1
		_jump_pending = false
	if _dash_pending and _dash_cooldown <= 0.0:
		_dash_remaining = Rules.DASH_DURATION
		_dash_cooldown = Rules.DASH_COOLDOWN
		_player.velocity.y = 0.0
	_dash_pending = false
	if _dash_remaining > 0.0:
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
		_player.velocity.x = float(_facing) * Rules.DASH_SPEED
	else:
		_player.velocity.x = axis * Rules.MOVE_SPEED
	if not _player.is_on_floor():
		_player.velocity.y += Rules.GRAVITY * delta
	_player.move_and_slide()
	var level: Dictionary = Rules.get_level(int(_state.get("level_index", 0)))
	if _player.global_position.y > float(level["size"].y) + 100.0:
		hit_hazard()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_SPACE, KEY_W, KEY_UP:
			_queue_jump()
		KEY_X:
			_queue_dash()
		KEY_R:
			reset_level()
		KEY_N:
			next_level()

func _queue_jump() -> void:
	_jump_pending = true

func _queue_dash() -> void:
	_dash_pending = true

func _set_touch_left(value: bool) -> void:
	_touch_left = value

func _set_touch_right(value: bool) -> void:
	_touch_right = value

func _on_core_body_entered(body: Node2D, core_id: String) -> void:
	if body == _player:
		collect_core(core_id)

func _on_checkpoint_body_entered(body: Node2D, checkpoint_id: String, position: Vector2) -> void:
	if body == _player:
		activate_checkpoint(checkpoint_id, position)

func _on_hazard_body_entered(body: Node2D) -> void:
	if body == _player:
		hit_hazard()

func _on_exit_body_entered(body: Node2D) -> void:
	if body == _player:
		try_complete_level()

func collect_core(core_id: String) -> bool:
	var before: int = (_state.get("collected", []) as Array).size()
	_state = Rules.collect_core(_state, core_id)
	var after: int = (_state.get("collected", []) as Array).size()
	if after <= before:
		return false
	if _core_nodes.has(core_id):
		var node: Node = _core_nodes[core_id]
		if is_instance_valid(node):
			node.queue_free()
		_core_nodes.erase(core_id)
	_message_label.text = "Data core secured. %d / %d recovered." % [after, get_core_count()]
	_refresh_hud()
	return true

func activate_checkpoint(checkpoint_id: String, position: Vector2) -> bool:
	var level: Dictionary = Rules.get_level(int(_state.get("level_index", 0)))
	var expected_id: String = str(level.get("checkpoint_id", ""))
	var expected_position: Vector2 = level.get("checkpoint_position", Vector2(-1.0, -1.0))
	if checkpoint_id != expected_id:
		return false
	if not Rules.is_checkpoint_supported(position, level.get("platforms", [])):
		return false
	if not is_equal_approx(position.x, expected_position.x) or not is_equal_approx(position.y, expected_position.y):
		return false
	var previous: String = str(_state.get("checkpoint_id", ""))
	_state = Rules.activate_checkpoint(_state, checkpoint_id)
	if str(_state.get("checkpoint_id", "")) != checkpoint_id or previous == checkpoint_id:
		return false
	_checkpoint_position = position
	_message_label.text = "Checkpoint synchronized. A fall will return you here."
	_refresh_hud()
	return true

func hit_hazard() -> void:
	_state = Rules.record_hazard(_state)
	if _player != null and is_instance_valid(_player):
		_player.global_position = _checkpoint_position
		_player.velocity = Vector2.ZERO
	_jumps_used = 0
	_dash_remaining = 0.0
	_message_label.text = "Hazard contact. Respawned at the latest checkpoint."
	_refresh_hud()

func try_complete_level() -> bool:
	_state = Rules.complete_level(_state)
	var complete: bool = str(_state.get("status", "")) == "complete"
	if complete:
		if _exit_visual != null and is_instance_valid(_exit_visual):
			_exit_visual.color = Color("#55f0a8")
		_message_label.text = "Sector cleared. Press N for the next climb."
	else:
		_message_label.text = "Exit locked. Recover all three data cores first."
	_refresh_hud()
	return complete

func next_level() -> bool:
	if str(_state.get("status", "")) != "complete":
		return false
	var next_state: Dictionary = Rules.next_level(_state)
	_load_level(int(next_state.get("level_index", 0)))
	return true

func reset_level() -> void:
	_load_level(int(_state.get("level_index", 0)))

func get_run_state() -> Dictionary:
	return _state.duplicate(true)

func get_player() -> CharacterBody2D:
	return _player

func get_checkpoint_position() -> Vector2:
	return _checkpoint_position

func get_core_count() -> int:
	return Rules.required_core_count(int(_state.get("level_index", 0)))

func get_exit_unlocked() -> bool:
	return Rules.can_exit(_state) or str(_state.get("status", "")) == "complete"

func get_current_level_index() -> int:
	return int(_state.get("level_index", 0))

func _refresh_hud() -> void:
	if _hud == null:
		return
	var level: Dictionary = Rules.get_level(int(_state.get("level_index", 0)))
	var collected: int = (_state.get("collected", []) as Array).size()
	_hud.text = "KROLL NEON CLIMBER  //  %s\nDATA CORES: %d / %d     FALLS: %d     DASH: X     DOUBLE JUMP: SPACE" % [
		str(level.get("name", "UNKNOWN")),
		collected,
		get_core_count(),
		int(_state.get("deaths", 0))
	]
