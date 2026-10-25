extends CharacterBody3D

@export var move_speed: float = 5.5
@export var jump_velocity: float = 4.0
@export var gravity_strength: float = 18.0

func _ready() -> void:
    add_to_group("player")

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
    velocity.x = move.x * move_speed
    velocity.z = move.y * move_speed
    if not is_on_floor():
        velocity.y -= gravity_strength * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = jump_velocity
    move_and_slide()
