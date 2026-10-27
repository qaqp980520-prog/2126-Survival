extends RefCounted
class_name KrollMagneticSalvageRules

const TARGET_PARTS: int = 6
const MAX_CHARGE: int = 6

static func clamp_to_arena(position: Vector2, arena_size: Vector2, margin: float = 24.0) -> Vector2:
	return Vector2(
		clampf(position.x, margin, arena_size.x - margin),
		clampf(position.y, margin, arena_size.y - margin)
	)

static func can_pulse(charge: int, cooldown: float, state: String) -> bool:
	return state == "playing" and charge > 0 and cooldown <= 0.0

static func pulled_position(scrap_position: Vector2, player_position: Vector2, range_px: float, pull_px: float) -> Vector2:
	var toward_player: Vector2 = player_position - scrap_position
	var distance: float = toward_player.length()
	if distance <= 0.001 or distance > range_px:
		return scrap_position
	return scrap_position + toward_player.normalized() * minf(pull_px, distance)

static func is_collected(scrap_position: Vector2, player_position: Vector2, radius: float = 26.0) -> bool:
	return scrap_position.distance_to(player_position) <= radius

static func can_extract(parts: int, player_position: Vector2, dock_position: Vector2, dock_radius: float, state: String) -> bool:
	return state == "playing" and parts >= TARGET_PARTS and player_position.distance_to(dock_position) <= dock_radius
