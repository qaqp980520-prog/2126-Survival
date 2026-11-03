extends RefCounted

const GRAVITY: float = 1100.0
const JUMP_SPEED: float = 560.0
const MAX_NODE_RANGE: float = 260.0
const MIN_ROPE_LENGTH: float = 76.0
const MAX_ROPE_LENGTH: float = 240.0
const HORIZONTAL_ACCEL: float = 1500.0
const MAX_HORIZONTAL_SPEED: float = 430.0
const GROUND_FRICTION: float = 1900.0
const AIR_FRICTION: float = 180.0
const COURSE_TIME_LIMIT: float = 90.0
const MAX_FALLS: int = 3

func nearest_tether_node(position: Vector2, anchors: Array, max_distance: float = MAX_NODE_RANGE) -> int:
	var nearest_index: int = -1
	var nearest_distance: float = maxf(max_distance, 0.0)
	for index in range(anchors.size()):
		var candidate: Variant = anchors[index]
		if typeof(candidate) != TYPE_VECTOR2:
			continue
		var distance: float = position.distance_to(candidate)
		if distance <= nearest_distance:
			if nearest_index == -1 or distance < nearest_distance:
				nearest_index = index
				nearest_distance = distance
	return nearest_index

func calculate_rope_length(distance: float) -> float:
	return clampf(distance, MIN_ROPE_LENGTH, MAX_ROPE_LENGTH)

func constrain_rope(position: Vector2, velocity: Vector2, anchor: Vector2, rope_length: float) -> Dictionary:
	var offset: Vector2 = position - anchor
	var distance: float = offset.length()
	var safe_length: float = maxf(rope_length, 0.0)
	if distance <= safe_length or distance <= 0.0001:
		return {
			"position": position,
			"velocity": velocity,
			"tension": false
		}
	var direction: Vector2 = offset / distance
	var constrained_position: Vector2 = anchor + direction * safe_length
	var constrained_velocity: Vector2 = velocity
	var radial_speed: float = velocity.dot(direction)
	if radial_speed > 0.0:
		constrained_velocity -= direction * radial_speed
	return {
		"position": constrained_position,
		"velocity": constrained_velocity,
		"tension": true
	}

func apply_horizontal(velocity: Vector2, input_axis: float, delta: float, grounded: bool) -> Vector2:
	if delta <= 0.0:
		return velocity
	var axis: float = clampf(input_axis, -1.0, 1.0)
	var result: Vector2 = velocity
	result.x = clampf(result.x + axis * HORIZONTAL_ACCEL * delta, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
	if absf(axis) < 0.01:
		var friction: float = GROUND_FRICTION if grounded else AIR_FRICTION
		result.x = move_toward(result.x, 0.0, friction * delta)
	return result

func calculate_score(time_remaining: float, falls: int) -> int:
	var time_bonus: int = int(maxf(time_remaining, 0.0) * 10.0)
	var fall_penalty: int = maxi(falls, 0) * 150
	return maxi(0, 1000 + time_bonus - fall_penalty)

func goal_contains(position: Vector2, goal_rect: Rect2) -> bool:
	return goal_rect.has_point(position)
