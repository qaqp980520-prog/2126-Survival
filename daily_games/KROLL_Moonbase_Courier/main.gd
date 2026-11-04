extends Node2D

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _touch_left: bool = false
var _touch_right: bool = false
var _jump_requested: bool = false
var _interact_requested: bool = false
var _message: String = "Collect the parcel, then reach the marked airlock. Jump over the surface vents."

func _ready() -> void:
    _state = Rules.new_state()
    queue_redraw()

func _physics_process(delta: float) -> void:
    if _state.is_empty() or str(_state.get("status", "")) != "active":
        return
    var direction: int = 0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or _touch_left:
        direction -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or _touch_right:
        direction += 1
    direction = clampi(direction, -1, 1)
    var jump_pressed: bool = _jump_requested
    var interact_pressed: bool = _interact_requested
    _jump_requested = false
    _interact_requested = false
    _simulate_step(minf(delta, 0.05), direction, jump_pressed, interact_pressed)

func _simulate_step(delta: float, direction: int, jump_pressed: bool, interact_pressed: bool) -> void:
    if str(_state.get("status", "")) != "active":
        return
    var time_left: float = maxf(0.0, float(_state.get("time_left", 0.0)) - delta)
    _state["time_left"] = time_left
    if time_left <= 0.0:
        _state["status"] = "failed"
        _message = "OXYGEN WINDOW EXPIRED. Restart the delivery route."
        queue_redraw()
        return

    var level: Dictionary = Rules.level_at(int(_state.get("level_index", 0)))
    var position: Vector2 = _state.get("player_position", Vector2.ZERO)
    var velocity: Vector2 = _state.get("velocity", Vector2.ZERO)
    var grounded: bool = bool(_state.get("grounded", false))
    var acceleration: float = 1400.0 if direction != 0 else 900.0
    velocity.x = move_toward(velocity.x, float(direction) * Rules.MOVE_SPEED, acceleration * delta)
    if jump_pressed and grounded:
        velocity.y = -Rules.JUMP_SPEED
        grounded = false
    velocity.y = minf(velocity.y + Rules.GRAVITY * delta, 720.0)

    var previous_position: Vector2 = position
    position.x = clampf(position.x + velocity.x * delta, 0.0, Rules.WORLD_SIZE.x - Rules.PLAYER_SIZE.x)
    position.y += velocity.y * delta
    var platforms: Array = level["platforms"]
    var landing_index: int = Rules.landing_platform(previous_position, position, velocity.y, platforms)
    if landing_index >= 0:
        var platform: Rect2 = platforms[landing_index]
        position.y = platform.position.y - Rules.PLAYER_SIZE.y
        velocity.y = 0.0
        grounded = true
    else:
        grounded = false

    _state["player_position"] = position
    _state["velocity"] = velocity
    _state["grounded"] = grounded

    var player_bounds: Rect2 = Rules.player_rect(position)
    for hazard_value in level["hazards"]:
        var hazard: Rect2 = hazard_value
        if Rules.rects_overlap(player_bounds, hazard):
            _lose_life()
            return

    if interact_pressed:
        _try_interact()
    queue_redraw()

func _lose_life() -> void:
    var lives: int = maxi(0, int(_state.get("lives", 0)) - 1)
    _state["lives"] = lives
    if lives <= 0:
        _state["status"] = "failed"
        _message = "SUIT INTEGRITY DEPLETED. Restart the mission."
    else:
        var level: Dictionary = Rules.level_at(int(_state.get("level_index", 0)))
        _state["player_position"] = level["start_position"]
        _state["velocity"] = Vector2.ZERO
        _state["grounded"] = false
        _state["carrying"] = false
        _message = "VENT CONTACT. Parcel returned to its pickup pad; suit charge remaining: %d." % lives
    queue_redraw()

func _try_interact() -> bool:
    if str(_state.get("status", "")) != "active":
        return false
    var player_bounds: Rect2 = Rules.player_rect(_state.get("player_position", Vector2.ZERO))
    if not bool(_state.get("carrying", false)):
        var package_rect: Rect2 = _state.get("package_rect", Rect2())
        if not Rules.rects_overlap(player_bounds, package_rect):
            return false
        _state["carrying"] = true
        _message = "PARCEL SECURED. Reach the highlighted airlock."
        queue_redraw()
        return true

    var exit_rect: Rect2 = _state.get("exit_rect", Rect2())
    if not Rules.rects_overlap(player_bounds, exit_rect):
        return false
    _state["status"] = "complete"
    var level_index: int = int(_state.get("level_index", 0))
    var awarded: Array = _state.get("awarded", []).duplicate(true)
    if not bool(awarded[level_index]):
        var level: Dictionary = Rules.level_at(level_index)
        var points: int = 100 if float(_state.get("time_left", 0.0)) >= float(level["par_time"]) else 75
        _state["campaign_score"] = int(_state.get("campaign_score", 0)) + points
        awarded[level_index] = true
        _state["awarded"] = awarded
    _message = "DELIVERY COMPLETE. Press NEXT or N for the next route."
    queue_redraw()
    return true

func _advance_level() -> bool:
    if str(_state.get("status", "")) != "complete":
        return false
    var index: int = int(_state.get("level_index", 0))
    if index >= Rules.level_count() - 1:
        _state["status"] = "victory"
        _message = "CAMPAIGN COMPLETE. All three moonbase parcels delivered."
        queue_redraw()
        return true
    var score: int = int(_state.get("campaign_score", 0))
    var awards: Array = _state.get("awarded", []).duplicate(true)
    _state = Rules.new_state(index + 1, score, awards)
    _message = "Next route loaded. Watch the vent spacing and upper platforms."
    queue_redraw()
    return true

func _restart_level() -> void:
    var index: int = int(_state.get("level_index", 0))
    var score: int = int(_state.get("campaign_score", 0))
    var awards: Array = _state.get("awarded", []).duplicate(true)
    _state = Rules.new_state(index, score, awards)
    _message = "Route restarted. Previously delivered parcels keep their campaign points."
    queue_redraw()

func _restart_campaign() -> void:
    _state = Rules.new_state()
    _message = "New moonbase delivery campaign initialized."
    queue_redraw()

func get_game_state() -> Dictionary:
    return _state.duplicate(true)

func _handle_touch_action(action: String, pressed: bool) -> void:
    match action:
        "left":
            _touch_left = pressed
        "right":
            _touch_right = pressed
        "jump":
            if pressed:
                _jump_requested = true
        "interact":
            if pressed:
                _interact_requested = true
        "restart":
            if pressed:
                _restart_level()
        "next":
            if pressed:
                _advance_level()
        "campaign":
            if pressed:
                _restart_campaign()

func _touch_action_at(position: Vector2) -> String:
    if Rect2(790.0, 62.0, 70.0, 34.0).has_point(position):
        return "restart"
    if Rect2(870.0, 62.0, 72.0, 34.0).has_point(position):
        return "next"
    if Rect2(18.0, 448.0, 70.0, 70.0).has_point(position):
        return "left"
    if Rect2(96.0, 448.0, 70.0, 70.0).has_point(position):
        return "right"
    if Rect2(730.0, 448.0, 92.0, 70.0).has_point(position):
        return "jump"
    if Rect2(830.0, 448.0, 112.0, 70.0).has_point(position):
        return "interact"
    return ""

func _input(event: InputEvent) -> void:
    var action: String = ""
    var pressed: bool = false
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if mouse_event.button_index != MOUSE_BUTTON_LEFT:
            return
        action = _touch_action_at(mouse_event.position)
        pressed = mouse_event.pressed
    elif event is InputEventScreenTouch:
        var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
        action = _touch_action_at(touch_event.position)
        pressed = touch_event.pressed
    if not action.is_empty():
        _handle_touch_action(action, pressed)

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_SPACE:
            _jump_requested = true
        KEY_E:
            _interact_requested = true
        KEY_R:
            _restart_level()
        KEY_N:
            _advance_level()
        KEY_C:
            _restart_campaign()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Rules.WORLD_SIZE), Color(0.018, 0.035, 0.075), true)
    for index in range(32):
        var x: float = float((index * 137) % 940) + 10.0
        var y: float = float((index * 71) % 390) + 20.0
        draw_circle(Vector2(x, y), 1.4, Color(0.24, 0.42, 0.62, 0.7))

    if _state.is_empty():
        return
    var level: Dictionary = Rules.level_at(int(_state.get("level_index", 0)))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 34.0), "KROLL  /  MOONBASE COURIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.48, 0.88, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 58.0), "A/D OR ARROWS: MOVE     SPACE: JUMP     E: PICK UP / DELIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.66, 0.78, 0.91))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 88.0), "ROUTE %d / %d  —  %s" % [int(_state["level_index"]) + 1, Rules.level_count(), str(level["name"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.82, 0.48))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 112.0), "SUIT %d     TIME %d s     CAMPAIGN %d / 300" % [int(_state["lives"]), int(ceil(float(_state["time_left"]))), int(_state["campaign_score"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.67, 0.92, 0.84))

    for platform_value in level["platforms"]:
        var platform: Rect2 = platform_value
        draw_rect(platform, Color(0.12, 0.29, 0.42), true)
        draw_rect(Rect2(platform.position, Vector2(platform.size.x, 4.0)), Color(0.32, 0.72, 0.85), true)
    for hazard_value in level["hazards"]:
        var hazard: Rect2 = hazard_value
        draw_rect(hazard, Color(0.82, 0.26, 0.16), true)
        draw_rect(Rect2(hazard.position + Vector2(4.0, 3.0), Vector2(hazard.size.x - 8.0, 4.0)), Color(1.0, 0.75, 0.28), true)

    var exit_rect: Rect2 = _state["exit_rect"]
    draw_rect(exit_rect, Color(0.12, 0.48, 0.38), true)
    draw_rect(Rect2(exit_rect.position + Vector2(6.0, 8.0), Vector2(exit_rect.size.x - 12.0, exit_rect.size.y - 16.0)), Color(0.35, 0.95, 0.76), false, 3.0)
    if not bool(_state.get("carrying", false)):
        var package_rect: Rect2 = _state["package_rect"]
        draw_rect(package_rect, Color(0.95, 0.66, 0.25), true)
        draw_rect(package_rect, Color(1.0, 0.9, 0.62), false, 2.0)
        draw_string(ThemeDB.fallback_font, package_rect.position + Vector2(-4.0, -7.0), "PARCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.86, 0.52))

    var player_position: Vector2 = _state["player_position"]
    var player_rect: Rect2 = Rules.player_rect(player_position)
    draw_rect(player_rect, Color(0.42, 0.76, 0.96), true)
    draw_rect(Rect2(player_position + Vector2(15.0, 7.0), Vector2(9.0, 8.0)), Color(0.04, 0.13, 0.24), true)
    if bool(_state.get("carrying", false)):
        draw_rect(Rect2(player_position + Vector2(4.0, -12.0), Vector2(20.0, 12.0)), Color(0.95, 0.66, 0.25), true)

    draw_string(ThemeDB.fallback_font, Vector2(24.0, 420.0), _message, HORIZONTAL_ALIGNMENT_LEFT, 900, 13, Color(1.0, 0.86, 0.58))
    _draw_button(Rect2(790.0, 62.0, 70.0, 34.0), "RESTART")
    _draw_button(Rect2(870.0, 62.0, 72.0, 34.0), "NEXT")
    _draw_button(Rect2(18.0, 448.0, 70.0, 70.0), "LEFT", _touch_left)
    _draw_button(Rect2(96.0, 448.0, 70.0, 70.0), "RIGHT", _touch_right)
    _draw_button(Rect2(730.0, 448.0, 92.0, 70.0), "JUMP", _jump_requested)
    _draw_button(Rect2(830.0, 448.0, 112.0, 70.0), "INTERACT", _interact_requested)

    var status: String = str(_state.get("status", "active"))
    if status == "complete" or status == "victory" or status == "failed":
        draw_rect(Rect2(220.0, 170.0, 520.0, 132.0), Color(0.02, 0.06, 0.12, 0.94), true)
        draw_rect(Rect2(220.0, 170.0, 520.0, 132.0), Color(0.34, 0.76, 0.91), false, 2.0)
        var heading: String = "DELIVERY COMPLETE" if status == "complete" else ("CAMPAIGN COMPLETE" if status == "victory" else "ROUTE FAILED")
        draw_string(ThemeDB.fallback_font, Vector2(260.0, 222.0), heading, HORIZONTAL_ALIGNMENT_CENTER, 440, 25, Color(0.5, 0.94, 0.8))
        draw_string(ThemeDB.fallback_font, Vector2(260.0, 260.0), "Press N to continue or R to retry.", HORIZONTAL_ALIGNMENT_CENTER, 440, 15, Color(0.82, 0.9, 0.98))

func _draw_button(rect: Rect2, caption: String, active: bool = false) -> void:
    var fill: Color = Color(0.12, 0.31, 0.46, 0.95) if not active else Color(0.22, 0.56, 0.68, 0.98)
    draw_rect(rect, fill, true)
    draw_rect(rect, Color(0.42, 0.78, 0.9), false, 2.0)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, rect.size.y * 0.58), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0, 14, Color(0.94, 0.98, 1.0))
