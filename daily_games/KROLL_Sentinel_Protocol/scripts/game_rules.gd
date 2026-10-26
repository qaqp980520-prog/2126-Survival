extends RefCounted
const MAX_HP: int = 3
const SURVIVE_SECONDS: float = 45.0
const SCORE_PER_KILL: int = 10
const PLAYER_RADIUS: float = 17.0

static func clamp_player_position(position: Vector2, viewport: Vector2) -> Vector2:
    return Vector2(clampf(position.x, PLAYER_RADIUS, maxf(PLAYER_RADIUS, viewport.x - PLAYER_RADIUS)), clampf(position.y, PLAYER_RADIUS, maxf(PLAYER_RADIUS, viewport.y - PLAYER_RADIUS)))
static func apply_damage(current_hp: int, damage: int = 1) -> int:
    return clampi(current_hp - maxi(damage, 0), 0, MAX_HP)
static func hit_test(first: Vector2, second: Vector2, radius: float) -> bool:
    return first.distance_squared_to(second) <= radius * radius
static func normalize_aim(direction: Vector2) -> Vector2:
    if direction.length_squared() < 0.0001:
        return Vector2.RIGHT
    return direction.normalized()
static func can_win(time_left: float, hp: int) -> bool:
    return time_left <= 0.0 and hp > 0
static func score_for_kill() -> int:
    return SCORE_PER_KILL
