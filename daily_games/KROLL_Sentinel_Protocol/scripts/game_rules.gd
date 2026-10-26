extends RefCounted
const MAX_HP: int = 3
const TARGET_CELLS: int = 8
const SURVIVE_SECONDS: float = 45.0
const PLAYER_RADIUS: float = 17.0
const CELL_RADIUS: float = 10.0
const ENEMY_RADIUS: float = 15.0

static func clamp_player_position(position: Vector2, viewport: Vector2) -> Vector2:
    return Vector2(clampf(position.x, PLAYER_RADIUS, maxf(PLAYER_RADIUS, viewport.x - PLAYER_RADIUS)), clampf(position.y, PLAYER_RADIUS, maxf(PLAYER_RADIUS, viewport.y - PLAYER_RADIUS)))
static func apply_damage(current_hp: int, damage: int = 1) -> int:
    return clampi(current_hp - maxi(damage, 0), 0, MAX_HP)
static func overlaps(first: Vector2, second: Vector2, radius: float) -> bool:
    return first.distance_squared_to(second) <= radius * radius
static func normalize_direction(direction: Vector2) -> Vector2:
    if direction.length_squared() < 0.0001:
        return Vector2.RIGHT
    return direction.normalized()
static func can_win(collected_cells: int, hp: int) -> bool:
    return collected_cells >= TARGET_CELLS and hp > 0
static func has_timed_out(time_left: float, collected_cells: int) -> bool:
    return time_left <= 0.0 and collected_cells < TARGET_CELLS
