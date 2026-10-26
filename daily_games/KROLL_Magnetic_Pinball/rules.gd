extends RefCounted
class_name KrollPinballRules

static func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)

static func reflect_velocity(velocity: Vector2, normal: Vector2, restitution: float) -> Vector2:
	var n: Vector2 = normal.normalized()
	var toward: float = velocity.dot(n)
	if toward >= 0.0:
		return velocity
	return velocity - (1.0 + clampf(restitution, 0.0, 1.0)) * toward * n

static func flipper_kick(velocity: Vector2, side: int, active: bool) -> Vector2:
	var minimum_upward_speed: float = 390.0 if active else 230.0
	var horizontal_kick: float = 230.0 if active else 90.0
	return Vector2(float(side) * horizontal_kick, -maxf(absf(velocity.y) * 0.78, minimum_upward_speed))

static func bump_score(score: int, bonus: int) -> int:
	return maxi(0, score + maxi(0, bonus))

static func is_ball_lost(ball_y: float, drain_y: float) -> bool:
	return ball_y > drain_y
