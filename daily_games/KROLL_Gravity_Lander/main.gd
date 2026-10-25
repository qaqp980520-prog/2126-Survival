extends Node2D

const Rules = preload("res://rules.gd")
const FIELD_BOUNDS := Rect2(0.0, 0.0, 960.0, 640.0)
const PAD_LEFT: float = 390.0
const PAD_RIGHT: float = 570.0
const CONTACT_Y: float = 560.0
const GRAVITY: float = 185.0
const THRUST_ACCEL: float = 330.0
const HORIZONTAL_ACCEL: float = 220.0
const HORIZONTAL_DRAG: float = 30.0
const FUEL_BURN: float = 22.0
const MAX_HORIZONTAL_SPEED: float = 65.0
const MAX_VERTICAL_SPEED: float = 90.0
const ROUND_SECONDS: float = 75.0

var rng := RandomNumberGenerator.new()
var lander_position := Vector2(480.0, 120.0)
var lander_velocity := Vector2.ZERO
var fuel: float = 100.0
var time_left: float = ROUND_SECONDS
var round_state: String = "playing"
var touch_controls: Dictionary = {}
var stars: Array[Vector2] = []
var hud: Label
var thrust_visual: bool = false

func _ready() -> void:
    rng.randomize()
    _build_hud()
    _start_round()

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(18.0, 12.0)
    hud.size = Vector2(900.0, 86.0)
    hud.add_theme_font_size_override("font_size", 18)
    hud.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0))
    layer.add_child(hud)

func _start_round() -> void:
    lander_position = Vector2(480.0, 120.0)
    lander_velocity = Vector2.ZERO
    fuel = 100.0
    time_left = ROUND_SECONDS
    round_state = "playing"
    thrust_visual = false
    touch_controls.clear()
    stars.clear()
    for i in range(100):
        stars.append(Vector2(rng.randf_range(8.0, 952.0), rng.randf_range(8.0, 500.0)))
    _refresh_hud()
    queue_redraw()

func restart_round() -> void:
    _start_round()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
        _start_round()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and round_state != "playing":
        _start_round()
        return
    if event is InputEventScreenTouch:
        if event.pressed and round_state != "playing":
            _start_round()
            return
        if event.pressed:
            touch_controls[event.index] = _touch_action(event.position)
        else:
            touch_controls.erase(event.index)
    elif event is InputEventScreenDrag:
        touch_controls[event.index] = _touch_action(event.position)

func _touch_action(point: Vector2) -> String:
    if point.y < 420.0:
        return ""
    if point.x < 320.0:
        return "left"
    if point.x > 640.0:
        return "right"
    return "thrust"

func _read_controls() -> Dictionary:
    var horizontal_axis := 0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        horizontal_axis -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        horizontal_axis += 1
    var thrusting := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
    for action in touch_controls.values():
        if action == "left":
            horizontal_axis -= 1
        elif action == "right":
            horizontal_axis += 1
        elif action == "thrust":
            thrusting = true
    return {"axis": clampi(horizontal_axis, -1, 1), "thrust": thrusting}

func _process(delta: float) -> void:
    if round_state != "playing":
        return
    time_left = maxf(0.0, time_left - delta)
    var controls := _read_controls()
    var fuel_available := fuel > 0.0
    var active_thrust := bool(controls["thrust"]) and fuel_available
    var active_axis := int(controls["axis"]) if fuel_available else 0
    thrust_visual = active_thrust
    lander_velocity = Rules.step_velocity(lander_velocity, active_axis, active_thrust, delta, GRAVITY, THRUST_ACCEL, HORIZONTAL_ACCEL)
    lander_velocity.x = move_toward(lander_velocity.x, 0.0, HORIZONTAL_DRAG * delta)
    if active_thrust:
        fuel = Rules.consume_fuel(fuel, FUEL_BURN * delta)
    elif active_axis != 0:
        fuel = Rules.consume_fuel(fuel, FUEL_BURN * 0.3 * delta)
    lander_position += lander_velocity * delta
    lander_position.x = clampf(lander_position.x, 20.0, 940.0)
    if lander_position.y >= CONTACT_Y:
        lander_position.y = CONTACT_Y
        resolve_landing()
    if time_left <= 0.0 and round_state == "playing":
        round_state = "lost"
    _refresh_hud()
    queue_redraw()

func resolve_landing() -> void:
    if round_state != "playing":
        return
    var outcome := Rules.landing_outcome(lander_position.x, lander_velocity.x, lander_velocity.y, PAD_LEFT, PAD_RIGHT, MAX_HORIZONTAL_SPEED, MAX_VERTICAL_SPEED)
    if outcome == "landed":
        round_state = "won"
        lander_velocity = Vector2.ZERO
    else:
        round_state = "lost"
    lander_position.y = CONTACT_Y
    thrust_visual = false
    _refresh_hud()
    queue_redraw()

func get_round_state() -> String:
    return round_state

func _refresh_hud() -> void:
    if hud == null:
        return
    var status := "MISSION: land inside the green pad with low speed"
    if round_state == "won":
        status = "LANDING SUCCESS // Press R to fly again"
    elif round_state == "lost":
        status = "MISSION FAILED // Press R to retry"
    hud.text = "KROLL GRAVITY LANDER   Fuel: %3d%%   Time: %02d s\n%s" % [int(round(fuel)), int(ceil(time_left)), status]

func _draw() -> void:
    draw_rect(FIELD_BOUNDS, Color(0.018, 0.03, 0.07))
    for star in stars:
        draw_circle(star, 1.4, Color(0.62, 0.8, 0.96, 0.78))
    draw_circle(Vector2(790.0, 135.0), 38.0, Color(0.22, 0.29, 0.36))
    draw_circle(Vector2(776.0, 122.0), 7.0, Color(0.29, 0.36, 0.43))
    draw_circle(Vector2(808.0, 149.0), 10.0, Color(0.17, 0.23, 0.3))
    draw_rect(Rect2(0.0, 580.0, 960.0, 60.0), Color(0.16, 0.19, 0.22))
    draw_line(Vector2(0.0, 580.0), Vector2(960.0, 580.0), Color(0.5, 0.66, 0.72), 2.0)
    draw_rect(Rect2(PAD_LEFT, 576.0, PAD_RIGHT - PAD_LEFT, 10.0), Color(0.2, 0.88, 0.58))
    draw_line(Vector2(PAD_LEFT, 586.0), Vector2(PAD_RIGHT, 586.0), Color(0.48, 1.0, 0.72), 2.0)
    if thrust_visual and round_state == "playing":
        draw_colored_polygon(PackedVector2Array([
            lander_position + Vector2(-5.0, 10.0),
            lander_position + Vector2(5.0, 10.0),
            lander_position + Vector2(0.0, 25.0 + rng.randf_range(0.0, 8.0))
        ]), Color(1.0, 0.52, 0.12))
    draw_colored_polygon(PackedVector2Array([
        lander_position + Vector2(0.0, -18.0),
        lander_position + Vector2(-13.0, 12.0),
        lander_position + Vector2(13.0, 12.0)
    ]), Color(0.66, 0.92, 1.0))
    draw_line(lander_position + Vector2(-10.0, 9.0), lander_position + Vector2(-15.0, 17.0), Color(0.7, 0.86, 0.95), 2.0)
    draw_line(lander_position + Vector2(10.0, 9.0), lander_position + Vector2(15.0, 17.0), Color(0.7, 0.86, 0.95), 2.0)
    _draw_touch_button(Rect2(18.0, 510.0, 275.0, 58.0), "LEFT")
    _draw_touch_button(Rect2(342.0, 510.0, 276.0, 58.0), "THRUST")
    _draw_touch_button(Rect2(667.0, 510.0, 275.0, 58.0), "RIGHT")

func _draw_touch_button(rect: Rect2, label_text: String) -> void:
    draw_rect(rect, Color(0.05, 0.18, 0.25, 0.76), true)
    draw_rect(rect, Color(0.24, 0.7, 0.82, 0.9), false, 2.0)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 36.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color(0.76, 0.96, 1.0))
