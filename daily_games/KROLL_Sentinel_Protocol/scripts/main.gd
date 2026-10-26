extends Node2D
const Rules = preload("res://scripts/game_rules.gd")
const PLAYER_SPEED: float = 270.0
const DASH_SPEED: float = 560.0
const DASH_DURATION: float = 0.18
const DASH_COOLDOWN: float = 1.4
const CELL_SPAWN_INTERVAL: float = 1.1
var _player_position: Vector2 = Vector2.ZERO
var _player_hp: int = Rules.MAX_HP
var _score: int = 0
var _time_left: float = Rules.SURVIVE_SECONDS
var _state: String = "playing"
var _enemies: Array[Dictionary] = []
var _cells: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.8
var _cell_spawn_timer: float = 0.0
var _touch_move_id: int = -1
var _touch_move_origin: Vector2 = Vector2.ZERO
var _touch_move_position: Vector2 = Vector2.ZERO
var _dash_requested: bool = false
var _dash_target: Vector2 = Vector2.ZERO
var _dash_velocity: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0

func _ready() -> void:
    _rng.randomize()
    _player_position = get_viewport_rect().size * 0.5
    for index in range(3):
        _spawn_cell()
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
            else:
                _dash_requested = true
                _dash_target = touch.position
        elif touch.index == _touch_move_id:
            _touch_move_id = -1
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_move_id:
            _touch_move_position = drag.position

func _process(delta: float) -> void:
    if _state != "playing":
        queue_redraw()
        return
    _time_left = maxf(0.0, _time_left - delta)
    if Rules.can_win(_score, _player_hp):
        _state = "victory"
        queue_redraw()
        return
    if Rules.has_timed_out(_time_left, _score):
        _state = "timeout"
        queue_redraw()
        return

    var viewport_size := get_viewport_rect().size
    var move_direction := _get_move_direction()
    _dash_cooldown = maxf(0.0, _dash_cooldown - delta)
    if _dash_requested and _dash_cooldown <= 0.0:
        var dash_direction := move_direction
        if dash_direction.length_squared() < 0.01:
            dash_direction = _dash_target - _player_position
        _activate_dash(dash_direction)
    _dash_requested = false
    var movement_velocity := move_direction * PLAYER_SPEED
    if _dash_timer > 0.0:
        movement_velocity = _dash_velocity
        _dash_timer = maxf(0.0, _dash_timer - delta)
    _player_position += movement_velocity * delta
    _player_position = Rules.clamp_player_position(_player_position, viewport_size)

    _spawn_timer -= delta
    if _spawn_timer <= 0.0:
        _spawn_enemy()
        _spawn_timer = _rng.randf_range(0.75, 1.05)
    _cell_spawn_timer -= delta
    if _cell_spawn_timer <= 0.0 and _cells.size() < 4:
        _spawn_cell()
        _cell_spawn_timer = CELL_SPAWN_INTERVAL
    _move_enemies(delta)
    _collect_cells()
    if _player_hp <= 0:
        _state = "defeat"
    elif Rules.can_win(_score, _player_hp):
        _state = "victory"
    elif Rules.has_timed_out(_time_left, _score):
        _state = "timeout"
    queue_redraw()

func _get_move_direction() -> Vector2:
    if _touch_move_id >= 0:
        return ((_touch_move_position - _touch_move_origin) / 68.0).limit_length(1.0)
    var direction := Vector2(
        float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
        float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    )
    return direction.normalized() if direction.length_squared() > 1.0 else direction

func _activate_dash(direction: Vector2) -> void:
    if _dash_cooldown > 0.0:
        return
    _dash_velocity = Rules.normalize_direction(direction) * DASH_SPEED
    _dash_timer = DASH_DURATION
    _dash_cooldown = DASH_COOLDOWN

func debug_dash(direction: Vector2) -> void:
    _activate_dash(direction)

func _spawn_enemy() -> void:
    var size := get_viewport_rect().size
    var side := _rng.randi_range(0, 3)
    var spawn_position := Vector2.ZERO
    match side:
        0: spawn_position = Vector2(-20.0, _rng.randf_range(30.0, size.y - 30.0))
        1: spawn_position = Vector2(size.x + 20.0, _rng.randf_range(30.0, size.y - 30.0))
        2: spawn_position = Vector2(_rng.randf_range(30.0, size.x - 30.0), -20.0)
        _: spawn_position = Vector2(_rng.randf_range(30.0, size.x - 30.0), size.y + 20.0)
    _spawn_enemy_at(spawn_position, _rng.randf_range(58.0, 86.0))

func _spawn_enemy_at(spawn_position: Vector2, speed: float) -> void:
    _enemies.append({"position": spawn_position, "speed": speed})

func _spawn_cell() -> void:
    var size := get_viewport_rect().size
    var cell_position := Vector2.ZERO
    for attempt in range(8):
        cell_position = Vector2(_rng.randf_range(45.0, size.x - 45.0), _rng.randf_range(130.0, size.y - 45.0))
        if cell_position.distance_to(_player_position) > 100.0:
            break
    _cells.append({"position": cell_position, "phase": _rng.randf_range(0.0, TAU)})

func _spawn_cell_at(cell_position: Vector2) -> void:
    _cells.append({"position": cell_position, "phase": 0.0})

func debug_spawn_enemy_at(spawn_position: Vector2) -> void:
    _spawn_enemy_at(spawn_position, 0.0)

func debug_spawn_cell_at(cell_position: Vector2) -> void:
    _spawn_cell_at(cell_position)

func _move_enemies(delta: float) -> void:
    for index in range(_enemies.size() - 1, -1, -1):
        var enemy: Dictionary = _enemies[index]
        var enemy_position: Vector2 = enemy["position"]
        var to_player := _player_position - enemy_position
        if Rules.overlaps(enemy_position, _player_position, Rules.ENEMY_RADIUS + Rules.PLAYER_RADIUS):
            _player_hp = Rules.apply_damage(_player_hp)
            _enemies.remove_at(index)
            continue
        var direction := to_player.normalized() if to_player.length_squared() > 0.001 else Vector2.RIGHT
        enemy["position"] = enemy_position + direction * float(enemy["speed"]) * delta

func _collect_cells() -> void:
    for index in range(_cells.size() - 1, -1, -1):
        var cell: Dictionary = _cells[index]
        var cell_position: Vector2 = cell["position"]
        if Rules.overlaps(cell_position, _player_position, Rules.CELL_RADIUS + Rules.PLAYER_RADIUS):
            _cells.remove_at(index)
            _score += 1

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.045))
    for x in range(0, int(size.x) + 1, 48):
        draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.06, 0.14, 0.18, 0.55), 1.0)
    for y in range(0, int(size.y) + 1, 48):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.06, 0.14, 0.18, 0.55), 1.0)
    for cell in _cells:
        var cell_position: Vector2 = cell["position"]
        var pulse := 1.0 + sin(float(cell["phase"]) + float(Time.get_ticks_msec()) * 0.003) * 0.12
        draw_circle(cell_position, 15.0 * pulse, Color(0.15, 0.95, 0.55, 0.18))
        draw_circle(cell_position, Rules.CELL_RADIUS, Color(0.24, 1.0, 0.57))
        draw_circle(cell_position, 3.0, Color(0.9, 1.0, 0.78))
    for enemy in _enemies:
        var enemy_position: Vector2 = enemy["position"]
        draw_circle(enemy_position, Rules.ENEMY_RADIUS + 4.0, Color(0.36, 0.08, 0.12, 0.55))
        draw_circle(enemy_position, Rules.ENEMY_RADIUS, Color(0.96, 0.19, 0.24))
        draw_circle(enemy_position, 4.0, Color(1.0, 0.7, 0.4))
    draw_circle(_player_position, Rules.PLAYER_RADIUS + 8.0, Color(0.0, 0.55, 0.75, 0.28))
    draw_circle(_player_position, Rules.PLAYER_RADIUS, Color(0.18, 0.83, 0.94))
    draw_circle(_player_position + Vector2(0.0, -4.0), 5.0, Color(0.92, 1.0, 1.0))
    if _dash_timer > 0.0:
        draw_line(_player_position - _dash_velocity.normalized() * 26.0, _player_position - _dash_velocity.normalized() * 54.0, Color(0.25, 0.9, 1.0, 0.75), 5.0)
    var font := ThemeDB.fallback_font
    if font != null:
        draw_string(font, Vector2(22, 34), "KROLL // SENTINEL ESCAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.48, 0.92, 1.0))
        draw_string(font, Vector2(22, 65), "CORE %d/3    CELLS %d/%d    TIME %02d" % [_player_hp, _score, Rules.TARGET_CELLS, int(ceil(_time_left))], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.94, 0.96))
        var dash_text := "DASH READY" if _dash_cooldown <= 0.0 else "DASH %.1fs" % _dash_cooldown
        draw_string(font, Vector2(22, 92), "WASD/ARROWS MOVE | SPACE DASH | COLLECT 8 CELLS | " + dash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.53, 0.72, 0.78))
        draw_string(font, Vector2(22, 113), "TOUCH: LEFT DRAG MOVE | RIGHT TAP DASH | AVOID RED DRONES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.42, 0.67, 0.74))
        if _state == "victory":
            draw_string(font, Vector2(size.x * 0.5 - 105.0, size.y * 0.5), "SECTOR SECURED", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.4, 1.0, 0.65))
            draw_string(font, Vector2(size.x * 0.5 - 115.0, size.y * 0.5 + 35.0), "PRESS R TO REDEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.95, 0.9))
        elif _state == "defeat":
            draw_string(font, Vector2(size.x * 0.5 - 95.0, size.y * 0.5), "CORE FAILURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.3, 0.34))
            draw_string(font, Vector2(size.x * 0.5 - 115.0, size.y * 0.5 + 35.0), "PRESS R TO REDEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.8, 0.8))
        elif _state == "timeout":
            draw_string(font, Vector2(size.x * 0.5 - 120.0, size.y * 0.5), "EXTRACTION WINDOW CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.65, 0.32))
            draw_string(font, Vector2(size.x * 0.5 - 115.0, size.y * 0.5 + 35.0), "PRESS R TO REDEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.8, 0.8))
    if _touch_move_id >= 0:
        draw_circle(_touch_move_origin, 48.0, Color(0.2, 0.75, 0.9, 0.16))
        draw_circle(_touch_move_position, 20.0, Color(0.4, 0.9, 1.0, 0.55))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE:
            _dash_requested = true
            _dash_target = get_global_mouse_position()
        elif event.keycode == KEY_R and _state != "playing":
            _restart()

func _restart() -> void:
    _player_position = get_viewport_rect().size * 0.5
    _player_hp = Rules.MAX_HP
    _score = 0
    _time_left = Rules.SURVIVE_SECONDS
    _state = "playing"
    _enemies.clear()
    _cells.clear()
    _spawn_timer = 0.8
    _cell_spawn_timer = 0.0
    _dash_timer = 0.0
    _dash_cooldown = 0.0
    _dash_requested = false
    for index in range(3):
        _spawn_cell()
    queue_redraw()
