extends Node2D

const Rules = preload("res://rules.gd")
const FIELD_BOUNDS := Rect2(Vector2.ZERO, Vector2(960.0, 640.0))
const SHIP_SPEED: float = 300.0
const SHIP_RADIUS: float = 12.0
const CARGO_GOAL: int = 6
const ROUND_SECONDS: float = 75.0

var rng := RandomNumberGenerator.new()
var ship_position := Vector2(480.0, 490.0)
var target_position := Vector2(480.0, 490.0)
var asteroids: Array[Dictionary] = []
var cargo: Array[Dictionary] = []
var stars: Array[Vector2] = []
var cargo_collected: int = 0
var hull: int = 3
var time_left: float = ROUND_SECONDS
var invulnerable_timer: float = 0.0
var round_state: String = "playing"
var hud: Label

func _ready() -> void:
    rng.randomize()
    _build_hud()
    _start_round()

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(18.0, 12.0)
    hud.size = Vector2(920.0, 84.0)
    hud.add_theme_font_size_override("font_size", 18)
    hud.add_theme_color_override("font_color", Color(0.75, 0.98, 1.0))
    layer.add_child(hud)

func _start_round() -> void:
    ship_position = Vector2(480.0, 500.0)
    target_position = ship_position
    cargo_collected = 0
    hull = Rules.DEFAULT_HULL
    time_left = ROUND_SECONDS
    invulnerable_timer = 0.0
    round_state = "playing"
    asteroids.clear()
    cargo.clear()
    stars.clear()
    for i in range(90):
        stars.append(Vector2(rng.randf_range(8.0, 952.0), rng.randf_range(90.0, 632.0)))
    for i in range(8):
        var position := _random_clear_position(100.0)
        var velocity := Vector2(rng.randf_range(-85.0, 85.0), rng.randf_range(-70.0, 70.0))
        if velocity.length() < 28.0:
            velocity = Vector2(42.0, -35.0)
        asteroids.append({"position": position, "velocity": velocity, "radius": rng.randf_range(13.0, 22.0)})
    for i in range(CARGO_GOAL):
        cargo.append({"position": _random_clear_position(70.0), "phase": rng.randf_range(0.0, TAU)})
    _refresh_hud()
    queue_redraw()

func _random_clear_position(min_ship_distance: float) -> Vector2:
    var point := Vector2(480.0, 300.0)
    for attempt in range(80):
        point = Vector2(rng.randf_range(34.0, 926.0), rng.randf_range(112.0, 606.0))
        if point.distance_to(ship_position) < min_ship_distance:
            continue
        var overlaps_existing := false
        for asteroid in asteroids:
            var other_position: Vector2 = asteroid["position"]
            if point.distance_to(other_position) < float(asteroid["radius"]) + 24.0:
                overlaps_existing = true
                break
        if overlaps_existing:
            continue
        for item in cargo:
            var other_cargo_position: Vector2 = item["position"]
            if point.distance_to(other_cargo_position) < 28.0:
                overlaps_existing = true
                break
        if not overlaps_existing:
            return point
    return point

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
        _start_round()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if round_state != "playing":
            _start_round()
        else:
            target_position = Rules.clamp_to_field(event.position, FIELD_BOUNDS, 26.0)
    elif event is InputEventScreenTouch and event.pressed:
        if round_state != "playing":
            _start_round()
        else:
            target_position = Rules.clamp_to_field(event.position, FIELD_BOUNDS, 26.0)

func _process(delta: float) -> void:
    if round_state != "playing":
        return
    time_left = maxf(0.0, time_left - delta)
    invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
    var direction := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.y += 1.0
    if direction.length_squared() > 0.0:
        direction = direction.normalized()
        ship_position += direction * SHIP_SPEED * delta
        target_position = ship_position
    else:
        ship_position = ship_position.move_toward(target_position, SHIP_SPEED * delta)
    ship_position = Rules.clamp_to_field(ship_position, FIELD_BOUNDS, 24.0)
    _update_asteroids(delta)
    _collect_overlapping_cargo()
    if round_state == "playing" and invulnerable_timer <= 0.0:
        for asteroid in asteroids:
            var asteroid_position: Vector2 = asteroid["position"]
            var asteroid_radius: float = float(asteroid["radius"])
            if Rules.within_radius(ship_position, asteroid_position, SHIP_RADIUS + asteroid_radius):
                take_hit()
                break
    if round_state == "playing":
        round_state = Rules.outcome(cargo_collected, hull, time_left, CARGO_GOAL)
    _refresh_hud()
    queue_redraw()

func _update_asteroids(delta: float) -> void:
    for i in range(asteroids.size()):
        var asteroid: Dictionary = asteroids[i]
        var position: Vector2 = asteroid["position"]
        var velocity: Vector2 = asteroid["velocity"]
        var radius: float = float(asteroid["radius"])
        position += velocity * delta
        if position.x < radius + 12.0 or position.x > 948.0 - radius:
            velocity.x *= -1.0
        if position.y < 94.0 + radius or position.y > 628.0 - radius:
            velocity.y *= -1.0
        position.x = clampf(position.x, radius + 12.0, 948.0 - radius)
        position.y = clampf(position.y, 94.0 + radius, 628.0 - radius)
        asteroid["position"] = position
        asteroid["velocity"] = velocity
        asteroids[i] = asteroid

func _collect_overlapping_cargo() -> void:
    for i in range(cargo.size() - 1, -1, -1):
        var item: Dictionary = cargo[i]
        var position: Vector2 = item["position"]
        if Rules.within_radius(ship_position, position, SHIP_RADIUS + 10.0):
            cargo.remove_at(i)
            collect_cargo()
            if round_state == "won":
                return

func collect_cargo() -> void:
    cargo_collected = Rules.collect_count(cargo_collected, CARGO_GOAL)
    round_state = Rules.outcome(cargo_collected, hull, time_left, CARGO_GOAL)
    _refresh_hud()
    queue_redraw()

func take_hit() -> void:
    if round_state != "playing" or invulnerable_timer > 0.0:
        return
    hull = Rules.apply_damage(hull, 1)
    invulnerable_timer = 1.4
    ship_position = Vector2(480.0, 500.0)
    target_position = ship_position
    round_state = Rules.outcome(cargo_collected, hull, time_left, CARGO_GOAL)
    _refresh_hud()
    queue_redraw()

func get_round_state() -> String:
    return Rules.outcome(cargo_collected, hull, time_left, CARGO_GOAL)

func _refresh_hud() -> void:
    if hud == null:
        return
    var status := "CARGO %d/%d    HULL %d/%d    TIME %02d" % [cargo_collected, CARGO_GOAL, hull, Rules.DEFAULT_HULL, int(ceil(time_left))]
    if round_state == "won":
        hud.text = "KROLL // ORBITAL CONVOY\nCONVOY SECURED — 全部貨艙已回收！\n點擊畫面或按 R 再出發"
    elif round_state == "lost":
        hud.text = "KROLL // ORBITAL CONVOY\nMISSION FAILED — 船體或時間耗盡\n" + status + "\n點擊畫面或按 R 再出發"
    else:
        hud.text = "KROLL // ORBITAL CONVOY\n" + status + "\nWASD／方向鍵移動；點擊或觸控設定航向；避開隕石"

func _draw() -> void:
    draw_rect(FIELD_BOUNDS, Color(0.012, 0.025, 0.065), true)
    for x in range(0, 961, 48):
        draw_line(Vector2(float(x), 82.0), Vector2(float(x), 640.0), Color(0.08, 0.22, 0.34, 0.28), 1.0)
    for y in range(96, 641, 48):
        draw_line(Vector2(0.0, float(y)), Vector2(960.0, float(y)), Color(0.08, 0.22, 0.34, 0.28), 1.0)
    for star in stars:
        draw_circle(star, 1.2, Color(0.58, 0.83, 1.0, 0.72))
    for item in cargo:
        var point: Vector2 = item["position"]
        var diamond := PackedVector2Array([point + Vector2(0.0, -11.0), point + Vector2(10.0, 0.0), point + Vector2(0.0, 11.0), point + Vector2(-10.0, 0.0)])
        draw_colored_polygon(diamond, Color(0.25, 1.0, 0.77))
        draw_arc(point, 15.0, 0.0, TAU, 28, Color(0.25, 1.0, 0.77, 0.55), 1.5)
    for asteroid in asteroids:
        var point: Vector2 = asteroid["position"]
        var radius: float = float(asteroid["radius"])
        draw_circle(point, radius, Color(0.28, 0.34, 0.45))
        draw_arc(point, radius, 0.0, TAU, 24, Color(0.65, 0.76, 0.9), 1.4)
        draw_circle(point + Vector2(-radius * 0.25, -radius * 0.15), radius * 0.22, Color(0.13, 0.18, 0.28))
    var ship := PackedVector2Array([ship_position + Vector2(0.0, -17.0), ship_position + Vector2(13.0, 12.0), ship_position + Vector2(0.0, 7.0), ship_position + Vector2(-13.0, 12.0)])
    var ship_color := Color(0.35, 0.92, 1.0) if invulnerable_timer <= 0.0 or int(Time.get_ticks_msec() / 120) % 2 == 0 else Color(0.35, 0.92, 1.0, 0.25)
    draw_colored_polygon(ship, ship_color)
    draw_polyline(PackedVector2Array([ship[0], ship[1], ship[2], ship[3], ship[0]]), Color(0.88, 1.0, 1.0), 1.6)
    if round_state == "playing":
        draw_arc(target_position, 8.0, 0.0, TAU, 24, Color(0.3, 0.85, 1.0, 0.45), 1.0)
