extends CharacterBody3D

@export var move_speed: float = 5.5
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.0
@export var gravity_strength: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var pitch_limit_degrees: float = 82.0

@onready var camera: Camera3D = $Camera3D
var _look_active: bool = false
var _pitch: float = deg_to_rad(-12.0)
var _third_person: bool = true
var avatar_visual: Node3D
var world_bridge: Node

func bind_world_bridge(candidate: Node) -> bool:
    if candidate == null or not candidate.has_method("get_movement_multiplier") or not candidate.has_method("can_player_jump"):
        return false
    world_bridge = candidate
    return true

func get_effective_movement_multiplier() -> float:
    if world_bridge == null or not is_instance_valid(world_bridge):
        return 1.0
    return clampf(float(world_bridge.call("get_movement_multiplier")), 0.1, 1.0)

func can_jump_with_current_load() -> bool:
    if world_bridge == null or not is_instance_valid(world_bridge):
        return true
    return bool(world_bridge.call("can_player_jump"))

func bind_avatar_visual(candidate: Node3D) -> bool:
    if candidate == null:
        return false
    avatar_visual = candidate
    _apply_camera_mode()
    return true

func toggle_camera_mode() -> void:
    _third_person = not _third_person
    _apply_camera_mode()

func _apply_camera_mode() -> void:
    if camera != null:
        camera.position = Vector3(0.0, 2.3, 5.5) if _third_person else Vector3(0.0, 1.62, 0.0)
        camera.rotation = Vector3(_pitch, 0.0, 0.0)
        camera.current = true
    if avatar_visual != null and is_instance_valid(avatar_visual):
        avatar_visual.visible = _third_person

func _ready() -> void:
    add_to_group("player")
    camera.current = true
    _apply_camera_mode()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        _look_active = event.pressed
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look_active else Input.MOUSE_MODE_VISIBLE
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _look_active:
        rotate_y(-event.relative.x * mouse_sensitivity)
        _pitch = clampf(_pitch - event.relative.y * mouse_sensitivity,
            deg_to_rad(-pitch_limit_degrees), deg_to_rad(pitch_limit_degrees))
        camera.rotation.x = _pitch
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
        toggle_camera_mode()
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _look_active = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
        var window := get_window()
        window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _look_active = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    var input_dir := Vector2.ZERO
    input_dir.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    input_dir.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    if input_dir.length_squared() > 1.0:
        input_dir = input_dir.normalized()
    var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
    var base_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
    var speed: float = base_speed * get_effective_movement_multiplier()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if not is_on_floor():
        velocity.y -= gravity_strength * delta
    elif Input.is_key_pressed(KEY_SPACE) and can_jump_with_current_load():
        velocity.y = jump_velocity
    move_and_slide()
