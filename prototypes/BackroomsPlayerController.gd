extends CharacterBody3D

@export var move_speed: float = 5.5
@export var jump_velocity: float = 4.5
@export var gravity_strength: float = 18.0
@export var mouse_sensitivity: float = 0.003
@export var pitch_min_degrees: float = -55.0
@export var pitch_max_degrees: float = 35.0

@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
var _look_active: bool = false
var _camera_pitch: float = -12.0

func _ready() -> void:
    add_to_group("player")
    if camera != null:
        camera.current = true
        camera.fov = 78.0
        camera.position = Vector3(0.0, 2.3, 5.5)
        camera.rotation = Vector3(deg_to_rad(_camera_pitch), 0.0, 0.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        _look_active = event.pressed
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look_active else Input.MOUSE_MODE_VISIBLE
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _look_active and camera != null:
        rotate_y(-event.relative.x * mouse_sensitivity)
        _camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity * 180.0 / PI, pitch_min_degrees, pitch_max_degrees)
        camera.rotation.x = deg_to_rad(_camera_pitch)
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _look_active = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    var move := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        move.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        move.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        move.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        move.y += 1.0
    if move.length_squared() > 1.0:
        move = move.normalized()
    var local_direction := Vector3(move.x, 0.0, move.y)
    var world_direction := (global_transform.basis * local_direction).normalized()
    velocity.x = world_direction.x * move_speed
    velocity.z = world_direction.z * move_speed
    if not is_on_floor():
        velocity.y -= gravity_strength * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = jump_velocity
    move_and_slide()
