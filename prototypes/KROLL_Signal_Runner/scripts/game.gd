extends Node2D

const SCREEN_SIZE := Vector2(960.0, 640.0)
const ARENA := Rect2(Vector2(48.0, 96.0), Vector2(864.0, 500.0))
const PLAYER_SPEED := 285.0
const PLAYER_RADIUS := 13.0
const SHARD_TOTAL := 8
const DRONE_TOTAL := 3
const PULSE_RANGE := 138.0
const PULSE_COOLDOWN := 4.0
const ROUND_TIME := 75.0

var player_pos := Vector2(480.0, 340.0)
var shards: Array[Vector2] = []
var drones: Array[Dictionary] = []
var collected := 0
var time_left := ROUND_TIME
var pulse_cooldown := 0.0
var pulse_flash := 0.0
var state := "playing"
var status_message := "Recover 8 signal shards. Avoid the patrol drones."

func _ready() -> void:
	randomize()
	_spawn_shards()
	_spawn_drones()
	queue_redraw()

func _spawn_shards() -> void:
	shards.clear()
	for i in range(SHARD_TOTAL):
		var candidate := _random_arena_point()
		var tries := 0
		while candidate.distance_to(player_pos) < 95.0 and tries < 30:
			candidate = _random_arena_point()
			tries += 1
		shards.append(candidate)

func _spawn_drones() -> void:
	drones.clear()
	for i in range(DRONE_TOTAL):
		var pos := _random_arena_point()
		var tries := 0
		while pos.distance_to(player_pos) < 220.0 and tries < 40:
			pos = _random_arena_point()
			tries += 1
		var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		drones.append({"position": pos, "velocity": direction * (68.0 + float(i) * 14.0), "stun": 0.0})

func _random_arena_point() -> Vector2:
	return Vector2(randf_range(ARENA.position.x + 28.0, ARENA.end.x - 28.0), randf_range(ARENA.position.y + 28.0, ARENA.end.y - 28.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and state == "playing":
			_activate_pulse()
		elif event.keycode == KEY_R and state != "playing":
			_restart_round()

func _process(delta: float) -> void:
	if state == "playing":
		time_left = maxf(0.0, time_left - delta)
		pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
		pulse_flash = maxf(0.0, pulse_flash - delta)
		_move_player(delta)
		_update_drones(delta)
		_collect_shards()
		_check_drone_collision()
		if collected >= SHARD_TOTAL:
			state = "won"
			status_message = "Signal recovered. KROLL relay secured!"
		elif time_left <= 0.0 and state == "playing":
			state = "lost"
			status_message = "Signal window expired. Press R to retry."
	queue_redraw()

func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
	if direction.length_squared() > 0.0:
		player_pos += direction.normalized() * PLAYER_SPEED * delta
	player_pos.x = clampf(player_pos.x, ARENA.position.x + PLAYER_RADIUS, ARENA.end.x - PLAYER_RADIUS)
	player_pos.y = clampf(player_pos.y, ARENA.position.y + PLAYER_RADIUS, ARENA.end.y - PLAYER_RADIUS)

func _update_drones(delta: float) -> void:
	for i in range(drones.size()):
		var drone: Dictionary = drones[i]
		var pos: Vector2 = drone["position"]
		var velocity: Vector2 = drone["velocity"]
		var stun := float(drone["stun"])
		if stun > 0.0:
			stun = maxf(0.0, stun - delta)
		else:
			var toward_player := player_pos - pos
			var desired := toward_player.normalized() * (82.0 + float(i) * 15.0)
			velocity = velocity.lerp(desired, minf(1.0, delta * 0.72))
			pos += velocity * delta
			if pos.x < ARENA.position.x + 15.0:
				pos.x = ARENA.position.x + 15.0
				velocity.x = absf(velocity.x)
			elif pos.x > ARENA.end.x - 15.0:
				pos.x = ARENA.end.x - 15.0
				velocity.x = -absf(velocity.x)
			if pos.y < ARENA.position.y + 15.0:
				pos.y = ARENA.position.y + 15.0
				velocity.y = absf(velocity.y)
			elif pos.y > ARENA.end.y - 15.0:
				pos.y = ARENA.end.y - 15.0
				velocity.y = -absf(velocity.y)
		drone["position"] = pos
		drone["velocity"] = velocity
		drone["stun"] = stun
		drones[i] = drone

func _collect_shards() -> void:
	for i in range(shards.size() - 1, -1, -1):
		if player_pos.distance_to(shards[i]) < 25.0:
			shards.remove_at(i)
			collected += 1
			status_message = "Signal shard %d/%d recovered." % [collected, SHARD_TOTAL]

func _check_drone_collision() -> void:
	for drone in drones:
		if float(drone["stun"]) <= 0.0 and player_pos.distance_to(drone["position"]) < PLAYER_RADIUS + 15.0:
			state = "lost"
			status_message = "Patrol drone detected you. Press R to retry."
			return

func _activate_pulse() -> void:
	if pulse_cooldown > 0.0:
		status_message = "EMP pulse recharging: %.1fs" % pulse_cooldown
		return
	pulse_cooldown = PULSE_COOLDOWN
	pulse_flash = 0.28
	var stunned := 0
	for i in range(drones.size()):
		var drone: Dictionary = drones[i]
		if player_pos.distance_to(drone["position"]) <= PULSE_RANGE:
			drone["stun"] = 2.6
			drones[i] = drone
			stunned += 1
	status_message = "EMP pulse: %d drone(s) disabled." % stunned

func _restart_round() -> void:
	player_pos = Vector2(480.0, 340.0)
	collected = 0
	time_left = ROUND_TIME
	pulse_cooldown = 0.0
	pulse_flash = 0.0
	state = "playing"
	status_message = "Recover 8 signal shards. Avoid the patrol drones."
	_spawn_shards()
	_spawn_drones()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.025, 0.035, 0.055))
	draw_rect(ARENA, Color(0.045, 0.075, 0.095))
	for x in range(int(ARENA.position.x), int(ARENA.end.x), 32):
		draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(0.11, 0.18, 0.20, 0.55), 1.0)
	for y in range(int(ARENA.position.y), int(ARENA.end.y), 32):
		draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color(0.11, 0.18, 0.20, 0.55), 1.0)
	draw_rect(ARENA, Color(0.25, 0.72, 0.72), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(48.0, 38.0), "KROLL // SIGNAL RUNNER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, Color(0.35, 0.95, 0.90))
	draw_string(font, Vector2(48.0, 68.0), "SHARDS %d/%d    TIME %02d    EMP %s" % [collected, SHARD_TOTAL, int(ceil(time_left)), ("READY" if pulse_cooldown <= 0.0 else "%.1fs" % pulse_cooldown)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.83, 0.91, 0.94))
	for shard in shards:
		var diamond := PackedVector2Array([shard + Vector2(0.0, -9.0), shard + Vector2(7.0, 0.0), shard + Vector2(0.0, 9.0), shard + Vector2(-7.0, 0.0)])
		draw_colored_polygon(diamond, Color(1.0, 0.78, 0.24))
		draw_circle(shard, 12.0, Color(1.0, 0.78, 0.24, 0.12))
	for drone in drones:
		var dpos: Vector2 = drone["position"]
		var stunned := float(drone["stun"]) > 0.0
		draw_circle(dpos, 15.0, Color(0.25, 0.88, 1.0) if stunned else Color(1.0, 0.23, 0.28))
		draw_circle(dpos, 5.0, Color(0.035, 0.045, 0.055))
		if stunned: draw_arc(dpos, 21.0, 0.0, TAU, 24, Color(0.3, 0.9, 1.0), 2.0)
	if pulse_flash > 0.0:
		draw_arc(player_pos, PULSE_RANGE, 0.0, TAU, 48, Color(0.3, 0.85, 1.0, 0.8), 3.0)
	draw_circle(player_pos, PLAYER_RADIUS + 4.0, Color(0.25, 0.85, 0.72, 0.2))
	draw_circle(player_pos, PLAYER_RADIUS, Color(0.38, 1.0, 0.78))
	draw_line(player_pos, player_pos + Vector2(0.0, -19.0), Color(0.85, 1.0, 0.95), 3.0)
	draw_string(font, Vector2(48.0, 622.0), "WASD/ARROWS Move    E EMP Pulse    Collect every yellow shard", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.69, 0.78, 0.82))
	draw_string(font, Vector2(48.0, 588.0), status_message, HORIZONTAL_ALIGNMENT_LEFT, 820.0, 16, Color(0.96, 0.88, 0.65))
	if state != "playing":
		draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.01, 0.015, 0.025, 0.78))
		var headline := "MISSION COMPLETE" if state == "won" else "MISSION FAILED"
		draw_string(font, Vector2(0.0, 285.0), headline, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 32, Color(0.4, 1.0, 0.82) if state == "won" else Color(1.0, 0.35, 0.38))
		draw_string(font, Vector2(0.0, 330.0), status_message, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 18, Color(0.9, 0.94, 0.96))
		draw_string(font, Vector2(0.0, 365.0), "Press R to restart", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 17, Color(0.95, 0.82, 0.45))
