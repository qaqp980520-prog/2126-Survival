extends RefCounted
class_name KROLLNeonBreakerRules

static func clamp_paddle_center(x: float, half_width: float, field_width: float) -> float:
	if field_width <= half_width * 2.0:
		return field_width * 0.5
	return clampf(x, half_width, field_width - half_width)

static func reflect_velocity(velocity: Vector2, normal: Vector2) -> Vector2:
	if normal.length_squared() < 0.000001:
		return velocity
	return velocity.bounce(normal.normalized())

static func paddle_bounce(hit_offset: float, max_angle_degrees: float, speed: float) -> Vector2:
	var offset := clampf(hit_offset, -1.0, 1.0)
	var angle := deg_to_rad(offset * max_angle_degrees)
	return Vector2(sin(angle), -cos(angle)) * maxf(0.0, speed)

static func has_lost_ball(ball_y: float, field_bottom: float, radius: float) -> bool:
	return ball_y - radius > field_bottom

static func remaining_lives(lives: int) -> int:
	return maxi(0, lives - 1)

static func time_expired(seconds_left: float) -> bool:
	return seconds_left <= 0.0

static func all_bricks_cleared(brick_count: int) -> bool:
	return brick_count <= 0
