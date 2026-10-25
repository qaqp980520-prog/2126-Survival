extends RefCounted
class_name GravityLanderRules

static func step_velocity(velocity: Vector2, horizontal_axis: int, thrusting: bool, delta: float, gravity: float, thrust_accel: float, horizontal_accel: float) -> Vector2:
    if not is_finite(delta) or delta <= 0.0:
        return velocity
    var result := velocity
    result.y += maxf(0.0, gravity) * delta
    if thrusting:
        result.y -= maxf(0.0, thrust_accel) * delta
    result.x += clampi(horizontal_axis, -1, 1) * maxf(0.0, horizontal_accel) * delta
    return result

static func consume_fuel(current_fuel: float, amount: float) -> float:
    if not is_finite(current_fuel) or not is_finite(amount):
        return 0.0
    return maxf(0.0, current_fuel - maxf(0.0, amount))

static func landing_outcome(x_position: float, horizontal_speed: float, vertical_speed: float, pad_left: float, pad_right: float, max_horizontal_speed: float, max_vertical_speed: float) -> String:
    var values := [x_position, horizontal_speed, vertical_speed, pad_left, pad_right, max_horizontal_speed, max_vertical_speed]
    for value in values:
        if not is_finite(float(value)):
            return "crashed"
    if pad_left > pad_right or x_position < pad_left or x_position > pad_right:
        return "crashed"
    if absf(horizontal_speed) > max_horizontal_speed or vertical_speed < 0.0 or vertical_speed > max_vertical_speed:
        return "crashed"
    return "landed"
