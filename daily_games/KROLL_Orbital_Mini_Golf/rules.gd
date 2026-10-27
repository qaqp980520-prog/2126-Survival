extends RefCounted

const TIME_LIMIT: float = 90.0
const COURSE_COUNT: int = 3
const MAX_STROKES_PER_COURSE: int = 5
const BALL_RADIUS: float = 9.0
const HOLE_RADIUS: float = 20.0
const MIN_DRAG_DISTANCE: float = 8.0
const MAX_DRAG_DISTANCE: float = 100.0
const SPEED_PER_PIXEL: float = 5.0
const MAX_SHOT_SPEED: float = 500.0
const MAX_CAPTURE_SPEED: float = 190.0
const FRICTION_PER_SECOND: float = 1.7
const WALL_RESTITUTION: float = 0.72
const OBSTACLE_RESTITUTION: float = 0.78
const STOP_SPEED: float = 5.0

static func calculate_shot_velocity(ball_position: Vector2, pull_position: Vector2) -> Vector2:
	var drag: Vector2 = ball_position - pull_position
	var distance: float = drag.length()
	if distance < MIN_DRAG_DISTANCE:
		return Vector2.ZERO
	var speed: float = minf(minf(distance, MAX_DRAG_DISTANCE) * SPEED_PER_PIXEL, MAX_SHOT_SPEED)
	return drag.normalized() * speed

static func apply_friction(velocity: Vector2, delta: float) -> Vector2:
	if delta <= 0.0:
		return velocity
	var result: Vector2 = velocity * exp(-FRICTION_PER_SECOND * delta)
	if result.length() < STOP_SPEED:
		return Vector2.ZERO
	return result

static func can_sink(distance_to_hole: float, speed: float) -> bool:
	return distance_to_hole <= HOLE_RADIUS and speed <= MAX_CAPTURE_SPEED

static func reflect_velocity(velocity: Vector2, normal: Vector2, restitution: float) -> Vector2:
	if normal.length_squared() <= 0.000001:
		return velocity
	return velocity.bounce(normal.normalized()) * clampf(restitution, 0.0, 1.0)
