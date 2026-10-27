extends Node2D

const Rules = preload("res://rules.gd")
const VIEW_SIZE := Vector2(960.0, 640.0)
const PLAYFIELD_BOTTOM := 540.0

var state: Dictionary = {}
var ship_position := VIEW_SIZE * 0.5
var ship_velocity := Vector2.ZERO
var ship_angle := -PI * 0.5
var asteroids: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var spawn_timer := 1.0
var fire_cooldown := 0.0
var invulnerable_left := 0.0
var rng := RandomNumberGenerator.new()
var _touch_action := ""
var _mouse_action := ""
var notice := "Destroy 12 asteroids. Thrust, turn and fire."

func _ready() -> void:
	_restart_game()

func _process(delta: float) -> void:
	if str(state.get("status", "")) != "playing":
		queue_redraw()
		return
	Rules.tick(state, delta)
	if str(state.get("status", "")) != "playing":
		queue_redraw()
		return

	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	if _action_down("left"):
		ship_angle -= 3.6 * delta
	if _action_down("right"):
		ship_angle += 3.6 * delta
	var forward := Vector2.RIGHT.rotated(ship_angle)
	if _action_down("thrust"):
		ship_velocity += forward * 210.0 * delta
	ship_velocity = ship_velocity.limit_length(270.0)
	ship_velocity = ship_velocity.move_toward(Vector2.ZERO, 10.0 * delta)
	ship_position = _wrap_position(ship_position + ship_velocity * delta)

	spawn_timer -= delta
	if spawn_timer <= 0.0 and asteroids.size() < 14:
		_spawn_asteroid()
		spawn_timer = 1.25

	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[bullet_index]
		var bullet_position: Vector2 = bullet["position"]
		var bullet_velocity: Vector2 = bullet["velocity"]
		bullet["position"] = _wrap_position(bullet_position + bullet_velocity * delta)
		bullet["ttl"] = float(bullet["ttl"]) - delta
		if float(bullet["ttl"]) <= 0.0:
			bullets.remove_at(bullet_index)
		else:
			bullets[bullet_index] = bullet

	for asteroid_index in range(asteroids.size() - 1, -1, -1):
		var asteroid: Dictionary = asteroids[asteroid_index]
		var asteroid_position: Vector2 = asteroid["position"]
		var asteroid_velocity: Vector2 = asteroid["velocity"]
		asteroid["position"] = _wrap_position(asteroid_position + asteroid_velocity * delta)
		asteroid["rotation"] = float(asteroid["rotation"]) + float(asteroid["spin"]) * delta
		asteroids[asteroid_index] = asteroid

	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[bullet_index]
		var bullet_position: Vector2 = bullet["position"]
		var hit_index := -1
		for asteroid_index in range(asteroids.size() - 1, -1, -1):
			var asteroid: Dictionary = asteroids[asteroid_index]
			var asteroid_position: Vector2 = asteroid["position"]
			if bullet_position.distance_to(asteroid_position) <= float(asteroid["radius"]):
				hit_index = asteroid_index
				break
		if hit_index >= 0:
			bullets.remove_at(bullet_index)
			asteroids.remove_at(hit_index)
			_register_asteroid_destroyed()
			if str(state.get("status", "")) != "playing":
				queue_redraw()
				return

	if invulnerable_left <= 0.0:
		for asteroid in asteroids:
			var asteroid_position: Vector2 = asteroid["position"]
			if ship_position.distance_to(asteroid_position) < float(asteroid["radius"]) + 11.0:
				Rules.lose_life(state)
				ship_position = VIEW_SIZE * 0.5
				ship_velocity = Vector2.ZERO
				invulnerable_left = 1.5
				notice = "Hull impact. Lives remaining: %d" % int(state["lives"])
				if str(state["status"]) == "lost":
					notice = "Hull breach. Press R to restart."
				break
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#06101d"))
	draw_rect(Rect2(0, 0, VIEW_SIZE.x, PLAYFIELD_BOTTOM), Color("#081727"))
	for index in range(28):
		var x := float((index * 137 + 31) % 960)
		var y := float((index * 83 + 17) % 520)
		draw_circle(Vector2(x, y), 1.2 if index % 3 == 0 else 0.7, Color("#29455b"))

	for asteroid in asteroids:
		var center: Vector2 = asteroid["position"]
		var points := PackedVector2Array()
		for local_point in asteroid["outline"]:
			var local_vector: Vector2 = local_point
			points.append(center + local_vector.rotated(float(asteroid["rotation"])))
		if points.size() >= 3:
			draw_colored_polygon(points, Color("#243b4d"))
			var closed := PackedVector2Array()
			for point in points:
				closed.append(point)
			closed.append(points[0])
			draw_polyline(closed, Color("#79b8c9"), 2.0, true)

	for bullet in bullets:
		var bullet_position: Vector2 = bullet["position"]
		draw_circle(bullet_position, 3.5, Color("#8cf7ff"))
		draw_circle(bullet_position, 7.0, Color(0.55, 0.95, 1.0, 0.18))

	if str(state.get("status", "")) == "playing" and (invulnerable_left <= 0.0 or int(invulnerable_left * 12.0) % 2 == 0):
		var forward := Vector2.RIGHT.rotated(ship_angle)
		var ship_points := PackedVector2Array([
			ship_position + forward * 17.0,
			ship_position + forward.rotated(2.45) * 13.0,
			ship_position + forward.rotated(-2.45) * 13.0
		])
		draw_colored_polygon(ship_points, Color("#67e8f9"))
		ship_points.append(ship_points[0])
		draw_polyline(ship_points, Color("#e0fdff"), 2.0, true)
		if _action_down("thrust"):
			draw_line(ship_position - forward * 11.0, ship_position - forward * 23.0 + forward.rotated(PI / 2.0) * 3.0, Color("#ffbd66"), 3.0, true)

	draw_rect(Rect2(18, 14, 924, 72), Color("#10283a"))
	draw_string(ThemeDB.fallback_font, Vector2(34, 43), "KROLL / ORBIT WARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#82f4ff"))
	draw_string(ThemeDB.fallback_font, Vector2(35, 69), "SCORE %04d   ASTEROIDS %02d/%02d   LIVES %d   TIME %02d" % [int(state.get("score", 0)), int(state.get("asteroids_destroyed", 0)), Rules.TARGET_DESTROYS, int(state.get("lives", Rules.STARTING_LIVES)), int(ceil(float(state.get("time_left", Rules.TIME_LIMIT)))], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#c2d6e4"))
	draw_string(ThemeDB.fallback_font, Vector2(34, 112), notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a8c6d8"))

	draw_rect(Rect2(0, PLAYFIELD_BOTTOM, VIEW_SIZE.x, VIEW_SIZE.y - PLAYFIELD_BOTTOM), Color("#0b1b2c"))
	_draw_control(Rect2(18, 558, 200, 62), "TURN LEFT", _action_down("left"))
	_draw_control(Rect2(235, 558, 200, 62), "THRUST", _action_down("thrust"))
	_draw_control(Rect2(452, 558, 200, 62), "TURN RIGHT", _action_down("right"))
	_draw_control(Rect2(669, 558, 132, 62), "FIRE", false)
	_draw_control(Rect2(816, 558, 126, 62), "RESET", false)
	if str(state.get("status", "")) != "playing":
		draw_rect(Rect2(210, 220, 540, 112), Color("#10283a"))
		var title := "SECTOR CLEARED" if str(state.get("status", "")) == "won" else "MISSION FAILED"
		draw_string(ThemeDB.fallback_font, Vector2(300, 267), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#8ef5d0") if title == "SECTOR CLEARED" else Color("#ff8b9c"))
		draw_string(ThemeDB.fallback_font, Vector2(300, 303), "Press R or RESET to play again.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d3e5ef"))

func _draw_control(rect: Rect2, label: String, active: bool) -> void:
	draw_rect(rect, Color("#176a75") if active else Color("#142c40"))
	draw_rect(rect, Color("#63e7ef"), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e4fbff"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart_game()
		elif event.keycode == KEY_SPACE:
			_fire_bullet()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_action = _action_for_position(event.position)
			if _touch_action == "fire":
				_fire_bullet()
			elif _touch_action == "reset":
				_restart_game()
		else:
			_touch_action = ""
		return
	if event is InputEventScreenDrag:
		_touch_action = _action_for_position(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_action = _action_for_position(event.position)
			if _mouse_action == "fire":
				_fire_bullet()
			elif _mouse_action == "reset":
				_restart_game()
		else:
			_mouse_action = ""

func _action_for_position(position: Vector2) -> String:
	if position.y < PLAYFIELD_BOTTOM + 8.0:
		return ""
	if position.x < 225.0:
		return "left"
	if position.x < 442.0:
		return "thrust"
	if position.x < 660.0:
		return "right"
	if position.x < 808.0:
		return "fire"
	return "reset"

func _action_down(action: String) -> bool:
	if action == "left":
		return Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or _touch_action == action or _mouse_action == action
	if action == "right":
		return Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or _touch_action == action or _mouse_action == action
	if action == "thrust":
		return Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or _touch_action == action or _mouse_action == action
	return false

func _fire_bullet() -> void:
	if str(state.get("status", "")) != "playing" or fire_cooldown > 0.0:
		return
	var forward := Vector2.RIGHT.rotated(ship_angle)
	bullets.append({
		"position": ship_position + forward * 19.0,
		"velocity": forward * 440.0 + ship_velocity,
		"ttl": 1.4
	})
	fire_cooldown = 0.22

func _register_asteroid_destroyed() -> bool:
	var accepted := Rules.register_destroy(state)
	if accepted:
		notice = "Direct hit. Keep the orbit clear."
		if str(state.get("status", "")) == "won":
			notice = "All targets cleared. Sector secured."
	return accepted

func _spawn_asteroid() -> void:
	var radius := rng.randf_range(20.0, 32.0)
	var position := Vector2.ZERO
	match rng.randi_range(0, 3):
		0: position = Vector2(-radius, rng.randf_range(40.0, 510.0))
		1: position = Vector2(VIEW_SIZE.x + radius, rng.randf_range(40.0, 510.0))
		2: position = Vector2(rng.randf_range(20.0, VIEW_SIZE.x - 20.0), -radius)
		3: position = Vector2(rng.randf_range(20.0, VIEW_SIZE.x - 20.0), PLAYFIELD_BOTTOM + radius)
	var direction := (VIEW_SIZE * 0.5 - position).normalized().rotated(rng.randf_range(-0.8, 0.8))
	var outline := PackedVector2Array()
	for point_index in range(9):
		var angle := TAU * float(point_index) / 9.0
		outline.append(Vector2(cos(angle), sin(angle)) * radius * rng.randf_range(0.76, 1.12))
	asteroids.append({
		"position": position,
		"velocity": direction * rng.randf_range(45.0, 95.0),
		"radius": radius,
		"outline": outline,
		"rotation": rng.randf_range(0.0, TAU),
		"spin": rng.randf_range(-0.7, 0.7)
	})

func _wrap_position(position: Vector2) -> Vector2:
	return Vector2(fposmod(position.x, VIEW_SIZE.x), fposmod(position.y, PLAYFIELD_BOTTOM))

func _restart_game() -> void:
	state = Rules.new_state()
	rng.seed = 20261027
	ship_position = VIEW_SIZE * 0.5
	ship_velocity = Vector2.ZERO
	ship_angle = -PI * 0.5
	asteroids.clear()
	bullets.clear()
	spawn_timer = 1.0
	fire_cooldown = 0.0
	invulnerable_left = 0.0
	_touch_action = ""
	_mouse_action = ""
	notice = "Destroy 12 asteroids. Thrust, turn and fire."
	for _index in range(4):
		_spawn_asteroid()
	queue_redraw()
