extends RefCounted
class_name KROLLDefenseRules

const COLUMNS: int = 13
const ROWS: int = 8
const TOWER_COST: int = 35

static func is_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLUMNS and cell.y < ROWS

static func is_path_cell(cell: Vector2i, path_cells: Array[Vector2i]) -> bool:
	return path_cells.has(cell)

static func can_build(cell: Vector2i, path_cells: Array[Vector2i], tower_cells: Array[Vector2i], credits: int) -> bool:
	if not is_inside_board(cell):
		return false
	if credits < TOWER_COST:
		return false
	if is_path_cell(cell, path_cells):
		return false
	if tower_cells.has(cell):
		return false
	return true

static func wave_enemy_count(wave: int) -> int:
	return 4 + maxi(1, wave) * 2

static func enemy_health_for_wave(wave: int) -> int:
	return 1 + int(maxi(0, wave - 1) / 2)

static func enemy_speed_for_wave(wave: int) -> float:
	return 36.0 + float(maxi(0, wave - 1)) * 8.0
