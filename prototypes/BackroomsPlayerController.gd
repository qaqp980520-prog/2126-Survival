extends CharacterBody3D

@export var move_speed: float = 5.5
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.0
@export var gravity_strength: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var pitch_limit_degrees: float = 82.0

@onready var camera: Camera3D = $Camera3D
var _look_active: bool = false
var _pitch: float = 0.0

func _ready() -> void:
    add_to_group("player")
    camera.position = Vector3(0.0, 1.62, 0.0)
    camera.rotation = Vector3.ZERO
    camera.current = true
    # Right mouse button is deliberately used for hold-to-look.
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
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
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _look_active = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if input_dir == Vector2.ZERO:
        input_dir = Vector2(
            float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
            float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
        )
    if input_dir.length_squared() > 1.0:
        input_dir = input_dir.normalized()
    var basis := global_transform.basis
    var direction := (basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
    var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if not is_on_floor():
        velocity.y -= gravity_strength * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = jump_velocity
    move_and_slide()
