extends RefCounted
class_name SignalSweepRules

const GRID_SIZE := 8
const DIFFICULTIES := [
	{"name": "簡單", "cores": 2, "scans": 30},
	{"name": "標準", "cores": 3, "scans": 22},
	{"name": "困難", "cores": 4, "scans": 18}
]

static func difficulty(index: int) -> Dictionary:
	if index < 0 or index >= DIFFICULTIES.size():
		return {}
	return DIFFICULTIES[index].duplicate(true)

static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func nearest_core_distance(cell: Vector2i, cores: Array[Vector2i]) -> int:
	if cores.is_empty():
		return -1
	var nearest := GRID_SIZE * 2
	for core in cores:
		nearest = mini(nearest, manhattan_distance(cell, core))
	return nearest

static func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE and cell.y < GRID_SIZE
