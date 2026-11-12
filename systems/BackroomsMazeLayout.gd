extends RefCounted
class_name BackroomsMazeLayout

## Pure deterministic topology rules shared by the Backrooms playground and
## future production maze runtimes. Geometry, materials and Node ownership stay
## with the runtime that consumes this layout contract.
const EXTRA_PASSAGE_CHANCE_PERCENT: int = 34
const EDGE_HASH_SALT: int = 13
const HASH_X_MULTIPLIER: int = 73856093
const HASH_Z_MULTIPLIER: int = 19349663
const HASH_SALT_MULTIPLIER: int = 83492791

static func is_valid_cell_size(cell_size: float) -> bool:
	return is_finite(cell_size) and cell_size > 0.0

static func try_cell_for_position(world_position: Vector3, cell_size: float) -> Dictionary:
	if not is_valid_cell_size(cell_size):
		return {"ok": false, "reason": "invalid_cell_size"}
	if not is_finite(world_position.x) or not is_finite(world_position.z):
		return {"ok": false, "reason": "invalid_world_position"}
	return {
		"ok": true,
		"cell": Vector2i(
			floori((world_position.x + cell_size * 0.5) / cell_size),
			floori((world_position.z + cell_size * 0.5) / cell_size)
		)
	}

## Compatibility helper for callers that already guarantee finite positions.
## Invalid input fails closed to the origin; use try_cell_for_position() when the
## caller needs to distinguish invalid input from the real origin cell.
static func cell_for_position(world_position: Vector3, cell_size: float) -> Vector2i:
	var result: Dictionary = try_cell_for_position(world_position, cell_size)
	var raw_cell: Variant = result.get("cell", Vector2i.ZERO)
	if raw_cell is Vector2i:
		return raw_cell
	return Vector2i.ZERO

## Select a deterministic spanning-tree parent. Every non-origin cell moves
## exactly one Manhattan step closer to (0, 0), guaranteeing connectivity.
static func parent_toward_origin(cell: Vector2i) -> Vector2i:
	if cell == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(cell.x) >= absi(cell.y) and cell.x != 0:
		return Vector2i(-1 if cell.x > 0 else 1, 0)
	return Vector2i(0, -1 if cell.y > 0 else 1)

## Stable integer hash. Keep the constants and operation order compatible with
## the original playground layout so existing deterministic maps do not shift.
static func hash_value(x: int, z: int, salt: int, world_seed: int) -> int:
	var value: int = abs((x * HASH_X_MULTIPLIER) ^ (z * HASH_Z_MULTIPLIER) ^ (salt * HASH_SALT_MULTIPLIER) ^ world_seed)
	return value

## Shared edges are keyed by their unordered endpoint pair. The spanning-tree
## parent edge is always open; remaining edges are opened by a seeded 34% roll.
## Invalid/non-cardinal directions fail closed.
static func edge_is_open(cell: Vector2i, direction: Vector2i, world_seed: int) -> bool:
	if not _is_cardinal_direction(direction):
		return false
	var neighbor: Vector2i = cell + direction
	if parent_toward_origin(cell) == direction:
		return true
	if parent_toward_origin(neighbor) == -direction:
		return true
	var ax: int = mini(cell.x, neighbor.x)
	var az: int = mini(cell.y, neighbor.y)
	var bx: int = maxi(cell.x, neighbor.x)
	var bz: int = maxi(cell.y, neighbor.y)
	return hash_value(ax * 31 + bx, az * 31 + bz, EDGE_HASH_SALT, world_seed) % 100 < EXTRA_PASSAGE_CHANCE_PERCENT

static func _is_cardinal_direction(direction: Vector2i) -> bool:
	return absi(direction.x) + absi(direction.y) == 1
