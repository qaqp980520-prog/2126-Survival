extends Node2D
const Rules = preload("res://scripts/game_rules.gd")
const PLAYER_SPEED: float = 270.0
const BULLET_SPEED: float = 480.0
const BULLET_RADIUS: float = 5.0
const ENEMY_RADIUS: float = 15.0
var _player_position: Vector2 = Vector2.ZERO
var _player_hp: int = Rules.MAX_HP
var _score: int = 0
var _time_left: float = Rules.SURVIVE_SECONDS
var _state: String = "playing"
var _enemies: Array[Dictionary] = []
var _bullets: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.45
var _shot_timer: float = 0.0
var _touch_move_id: int = -1
var _touch_move_origin: Vector2 = Vector2.ZERO
var _touch_move_position: Vector2 = Vector2.ZERO
var _touch_aim_id: int = -1
var _touch_aim_position: Vector2 = Vector2.ZERO

func _ready() -> void:
    _rng.randomize()
    _player_position = get_viewport_rect().size * 0.5
    queue_redraw()

func _input(event: InputEvent) -> void:
    var viewport_size := get_viewport_rect().size
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if touch.position.x < viewport_size.x * 0.5 and _touch_move_id == -1:
                _touch_move_id = touch.index
                _touch_move_origin = touch.position
                _touch_move_position = touch.position
            elif _touch_aim_id == -1:
                _touch_aim_id = touch.index
                _touch_aim_position = touch.position
        else:
            if touch.index == _touch_move_id:
                _touch_move_id = -1
            if touch.index == _touch_aim_id:
                _touch_aim_id = -1
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_move_id:
            _touch_move_position = drag.position
        elif drag.index == _touch_aim_id:
            _touch_aim_position = drag.position

func _process(delta: float) -> void:
    if _state != "playing":
        queue_redraw()
        return
    _time_left = maxf(0.0, _time_left - delta)
    if Rules.can_win(_time_left, _player_hp):
        _state = "victory"
        queue_redraw()
        return
    var viewport_size := get_viewport_rect().size
    _player_position += _get_move_direction() * PLAYER_SPEED * delta
    _player_position = Rules.clamp_player_position(_player_position, viewport_size)
    _shot_timer = maxf(0.0, _shot_timer - delta)
    var wants_fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) or _touch_aim_id >= 0
    if wants_fire and _shot_timer <= 0.0:
        var aim_position := _touch_aim_position if _touch_aim_id >= 0 else get_global_mouse_position()
        _fire_toward(aim_position - _player_position)
        _shot_timer = 0.22
    _spawn_timer -= delta
    if _spawn_timer <= 0.0:
        _spawn_enemy()
        _spawn_timer = _rng.randf_range(0.7, 1.05)
    _move_enemies(delta)
    _move_bullets(delta)
    if _player_hp <= 0:
        _state = "defeat"
    queue_redraw()

func _get_move_direction() -> Vector2:
    if _touch_move_id >= 0:
        return ((_touch_move_position - _touch_move_origin) / 68.0).limit_length(1.0)
    var direction := Vector2(
        float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
        float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    )
    return direction.normalized() if direction.length_squared() > 1.0 else direction

func _fire_toward(direction: Vector2) -> void:
    var aim := Rules.normalize_aim(direction)
    _bullets.append({"position": _player_position + aim * 22.0, "velocity": aim * BULLET_SPEED, "life": 1.8})

func _spawn_enemy() -> void:
    var size := get_viewport_rect().size
    var side := _rng.randi_range(0, 3)
    var spawn_position := Vector2.ZERO
    match side:
        0: spawn_position = Vector2(-20.0, _rng.randf_range(30.0, size.y - 30.0))
        1: spawn_position = Vector2(size.x + 20.0, _rng.randf_range(30.0, size.y - 30.0))
        2: spawn_position = Vector2(_rng.randf_range(30.0, size.x - 30.0), -20.0)
        _: spawn_position = Vector2(_rng.randf_range(30.0, size.x - 30.0), size.y + 20.0)
    _spawn_enemy_at(spawn_position, _rng.randf_range(62.0, 92.0))

func _spawn_enemy_at(position: Vector2, speed: float) -> void:
    _enemies.append({"position": position, "speed": speed})

func debug_spawn_enemy_at(position: Vector2) -> void:
    _spawn_enemy_at(position, 0.0)

func debug_fire_toward(direction: Vector2) -> void:
    _fire_toward(direction)

func _move_enemies(delta: float) -> void:
    for index in range(_enemies.size() - 1, -1, -1):
        var enemy: Dictionary = _enemies[index]
        var enemy_position: Vector2 = enemy["position"]
        var to_player := _player_position - enemy_position
        if to_player.length() <= Rules.PLAYER_RADIUS + ENEMY_RADIUS:
            _player_hp = Rules.apply_damage(_player_hp)
            _enemies.remove_at(index)
            continue
        var direction := to_player.normalized() if to_player.length_squared() > 0.001 else Vector2.RIGHT
        enemy["position"] = enemy_position + direction * float(enemy["speed"]) * delta

func _move_bullets(delta: float) -> void:
    var size := get_viewport_rect().size
    for bullet_index in range(_bullets.size() - 1, -1, -1):
        var bullet: Dictionary = _bullets[bullet_index]
        var bullet_position: Vector2 = bullet["position"]
        var bullet_velocity: Vector2 = bullet["velocity"]
        bullet_position += bullet_velocity * delta
        bullet["position"] = bullet_position
        bullet["life"] = float(bullet["life"]) - delta
        var hit_enemy := false
        for enemy_index in range(_enemies.size() - 1, -1, -1):
            var enemy: Dictionary = _enemies[enemy_index]
            var enemy_position: Vector2 = enemy["position"]
            if Rules.hit_test(bullet_position, enemy_position, BULLET_RADIUS + ENEMY_RADIUS):
                _enemies.remove_at(enemy_index)
                _score += Rules.score_for_kill()
                hit_enemy = true
                break
        if hit_enemy or float(bullet["life"]) <= 0.0 or bullet_position.x < -20.0 or bullet_position.y < -20.0 or bullet_position.x > size.x + 20.0 or bullet_position.y > size.y + 20.0:
            _bullets.remove_at(bullet_index)

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.045))
    for x in range(0, int(size.x) + 1, 48):
        draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.06, 0.14, 0.18, 0.55), 1.0)
    for y in range(0, int(size.y) + 1, 48):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.06, 0.14, 0.18, 0.55), 1.0)
    for enemy in _enemies:
        var enemy_position: Vector2 = enemy["position"]
        draw_circle(enemy_position, ENEMY_RADIUS + 4.0, Color(0.36, 0.08, 0.12, 0.55))
        draw_circle(enemy_position, ENEMY_RADIUS, Color(0.96, 0.19, 0.24))
        draw_circle(enemy_position, 4.0, Color(1.0, 0.7, 0.4))
    for bullet in _bullets:
        var bullet_position: Vector2 = bullet["position"]
        draw_circle(bullet_position, BULLET_RADIUS, Color(1.0, 0.82, 0.28))
    draw_circle(_player_position, Rules.PLAYER_RADIUS + 7.0, Color(0.0, 0.55, 0.75, 0.28))
    draw_circle(_player_position, Rules.PLAYER_RADIUS, Color(0.18, 0.83, 0.94))
    draw_circle(_player_position + Vector2(0.0, -4.0), 5.0, Color(0.92, 1.0, 1.0))
    var font := ThemeDB.fallback_font
    if font != null:
        draw_string(font, Vector2(22, 34), "KROLL // SENTINEL PROTOCOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.48, 0.92, 1.0))
        draw_string(font, Vector2(22, 65), "CORE %d/3    SCORE %04d    TIME %02d" % [_player_hp, _score, int(ceil(_time_left))], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.94, 0.96))
        draw_string(font, Vector2(22, 92), "WASD/ARROWS MOVE | MOUSE AIM + FIRE | SPACE FIRE | SURVIVE 45s", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.53, 0.72, 0.78))
        draw_string(font, Vector2(22, 113), "TOUCH: LEFT DRAG MOVE | RIGHT DRAG AIM/FIRE | R REDEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.42, 0.67, 0.74))
        if _state == "victory":
            draw_string(font, Vector2(size.x * 0.5 - 105.0, size.y * 0.5), "SECTOR SECURED", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.4, 1.0, 0.65))
            draw_string(font, Vector2(size.x * 0.5 - 115.0, size.y * 0.5 + 35.0), "PRESS R TO REDEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.95, 0.9))
        elif _state == "defeat":
            draw_string(font, Vector2(size.x * 0.5 - 95.0, size.y * 0.5), "CORE FAILURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.3, 0.34))
            draw_string(font, Vector2(size.x * 0.5 - 115.0, size.y * 0.5 + 35.0), "PRESS R TO REDEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.8, 0.8))
    if _touch_move_id >= 0:
        draw_circle(_touch_move_origin, 48.0, Color(0.2, 0.75, 0.9, 0.16))
        draw_circle(_touch_move_position, 20.0, Color(0.4, 0.9, 1.0, 0.55))
    if _touch_aim_id >= 0:
        draw_circle(_touch_aim_position, 24.0, Color(1.0, 0.35, 0.28, 0.3))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and _state != "playing":
        _restart()

func _restart() -> void:
    _player_position = get_viewport_rect().size * 0.5
    _player_hp = Rules.MAX_HP
    _score = 0
    _time_left = Rules.SURVIVE_SECONDS
    _state = "playing"
    _enemies.clear()
    _bullets.clear()
    _spawn_timer = 0.45
    _shot_timer = 0.0
    queue_redraw()
