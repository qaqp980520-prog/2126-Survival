extends RefCounted
## Deterministic top-down time-trial model for KROLL Vector Rally.
const MAX_SPEED: float = 290.0
const ACCELERATION: float = 360.0
const BRAKE_DECELERATION: float = 520.0
const TURN_RATE: float = 2.8
const LATERAL_GRIP: float = 6.5
const TRACKS: Array[Dictionary] = [
	{"id":"dock_loop","name":"Dock Loop","center":Vector2(480.0,350.0),"outer":Vector2(410.0,300.0),"inner":Vector2(215.0,125.0),"checkpoints":[Vector2(120.0,350.0),Vector2(480.0,82.0),Vector2(840.0,350.0),Vector2(480.0,625.0)],"start":Vector2(480.0,625.0),"start_heading":PI,"grip":1.0,"checkpoint_radius":44.0},
	{"id":"reactor_ring","name":"Reactor Ring","center":Vector2(480.0,350.0),"outer":Vector2(390.0,280.0),"inner":Vector2(220.0,145.0),"checkpoints":[Vector2(145.0,350.0),Vector2(480.0,105.0),Vector2(815.0,350.0),Vector2(480.0,595.0)],"start":Vector2(480.0,595.0),"start_heading":PI,"grip":0.88,"checkpoint_radius":43.0},
	{"id":"canyon_sweep","name":"Canyon Sweep","center":Vector2(480.0,350.0),"outer":Vector2(430.0,310.0),"inner":Vector2(195.0,110.0),"checkpoints":[Vector2(92.0,350.0),Vector2(480.0,62.0),Vector2(868.0,350.0),Vector2(480.0,640.0)],"start":Vector2(480.0,640.0),"start_heading":PI,"grip":1.12,"checkpoint_radius":45.0}
]
static func get_track(track_index: int) -> Dictionary:
	return TRACKS[clampi(track_index, 0, TRACKS.size() - 1)].duplicate(true)
static func new_race(track_index: int = 0) -> Dictionary:
	var safe_index: int = clampi(track_index, 0, TRACKS.size() - 1)
	var track: Dictionary = get_track(safe_index)
	return {"track_index":safe_index,"track_id":str(track["id"]),"position":track["start"],"velocity":Vector2.ZERO,"heading":float(track["start_heading"]),"next_checkpoint":0,"laps":0,"elapsed":0.0,"offroad_time":0.0,"status":"racing"}
static func is_on_track(position: Vector2, track: Dictionary) -> bool:
	var center: Vector2 = track.get("center", Vector2.ZERO)
	var outer: Vector2 = track.get("outer", Vector2.ZERO)
	var inner: Vector2 = track.get("inner", Vector2.ZERO)
	if outer.x <= 0.0 or outer.y <= 0.0 or inner.x <= 0.0 or inner.y <= 0.0:
		return false
	var offset: Vector2 = position - center
	var outer_norm: float = pow(offset.x / outer.x, 2.0) + pow(offset.y / outer.y, 2.0)
	var inner_norm: float = pow(offset.x / inner.x, 2.0) + pow(offset.y / inner.y, 2.0)
	return outer_norm <= 1.0 and inner_norm >= 1.0
static func step(state: Dictionary, input: Dictionary, delta: float) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "racing":
		return next
	var dt: float = clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return next
	var track: Dictionary = get_track(int(next.get("track_index", 0)))
	var position: Vector2 = next.get("position", Vector2.ZERO)
	var velocity: Vector2 = next.get("velocity", Vector2.ZERO)
	var heading: float = float(next.get("heading", 0.0))
	var steer: float = clampf(float(input.get("steer", 0.0)), -1.0, 1.0)
	var forward: Vector2 = Vector2.RIGHT.rotated(heading)
	if bool(input.get("throttle", false)):
		velocity += forward * ACCELERATION * dt
	if bool(input.get("brake", false)):
		velocity = velocity.move_toward(Vector2.ZERO, BRAKE_DECELERATION * dt)
	var speed: float = velocity.length()
	if speed > 6.0:
		var travel_sign: float = 1.0 if velocity.dot(forward) >= 0.0 else -1.0
		if absf(steer) > 0.001:
			heading = wrapf(heading + steer * TURN_RATE * clampf(speed / MAX_SPEED, 0.08, 1.0) * travel_sign * dt, -PI, PI)
		forward = Vector2.RIGHT.rotated(heading)
		var longitudinal_speed: float = velocity.dot(forward)
		var longitudinal: Vector2 = forward * longitudinal_speed
		var lateral: Vector2 = velocity - longitudinal
		var grip: float = maxf(0.1, float(track.get("grip", 1.0)))
		var damping: float = LATERAL_GRIP * grip
		if bool(input.get("handbrake", false)):
			damping = 1.35 * grip
		velocity = longitudinal + lateral * exp(-damping * dt)
	if not is_on_track(position, track):
		velocity *= exp(-4.0 * dt)
		next["offroad_time"] = float(next.get("offroad_time", 0.0)) + dt
	else:
		velocity *= exp(-0.22 * dt)
		next["offroad_time"] = maxf(0.0, float(next.get("offroad_time", 0.0)) - dt * 2.0)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * dt
	next["position"] = position
	next["velocity"] = velocity
	next["heading"] = heading
	next["elapsed"] = float(next.get("elapsed", 0.0)) + dt
	return advance_checkpoint(next)
static func advance_checkpoint(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "racing":
		return next
	var track: Dictionary = get_track(int(next.get("track_index", 0)))
	var checkpoints: Array = track.get("checkpoints", [])
	var checkpoint_index: int = int(next.get("next_checkpoint", 0))
	if checkpoint_index < 0 or checkpoint_index >= checkpoints.size():
		return next
	var checkpoint: Vector2 = checkpoints[checkpoint_index]
	var position: Vector2 = next.get("position", Vector2.ZERO)
	if position.distance_to(checkpoint) > float(track.get("checkpoint_radius", 40.0)):
		return next
	if checkpoint_index == checkpoints.size() - 1:
		next["laps"] = int(next.get("laps", 0)) + 1
		next["next_checkpoint"] = 0
		if int(next["laps"]) >= 1:
			next["status"] = "finished"
			next["velocity"] = Vector2.ZERO
	else:
		next["next_checkpoint"] = checkpoint_index + 1
	return next
static func next_track(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "finished":
		return state.duplicate(true)
	return new_race((int(state.get("track_index", 0)) + 1) % TRACKS.size())
static func ellipse_points(center: Vector2, radii: Vector2, segments: int = 72) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = maxi(12, segments)
	for index in range(safe_segments):
		var angle: float = TAU * float(index) / float(safe_segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
