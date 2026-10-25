extends RefCounted
class_name OrbitalConvoyRules

const DEFAULT_CARGO_GOAL: int = 6
const DEFAULT_HULL: int = 3

static func within_radius(a: Vector2, b: Vector2, radius: float) -> bool:
    if radius < 0.0 or not is_finite(radius):
        return false
    return a.distance_squared_to(b) <= radius * radius

static func collect_count(current: int, goal: int = DEFAULT_CARGO_GOAL) -> int:
    if goal <= 0:
        return 0
    return clampi(current + 1, 0, goal)

static func apply_damage(hull: int, amount: int = 1) -> int:
    return maxi(0, hull - maxi(0, amount))

static func outcome(cargo_count: int, hull: int, time_left: float, goal: int = DEFAULT_CARGO_GOAL) -> String:
    if cargo_count >= goal:
        return "won"
    if hull <= 0 or time_left <= 0.0:
        return "lost"
    return "playing"

static func clamp_to_field(point: Vector2, bounds: Rect2, padding: float = 18.0) -> Vector2:
    var safe_padding: float = maxf(0.0, padding)
    var left: float = bounds.position.x + safe_padding
    var top: float = bounds.position.y + safe_padding
    var right: float = maxf(left, bounds.end.x - safe_padding)
    var bottom: float = maxf(top, bounds.end.y - safe_padding)
    return Vector2(clampf(point.x, left, right), clampf(point.y, top, bottom))
