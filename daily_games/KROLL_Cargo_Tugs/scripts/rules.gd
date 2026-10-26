extends RefCounted

const BOARD_SIZE: int = 8
const LEVEL_COUNT: int = 3

static func make_level(level_index: int) -> Dictionary:
	var rows: Array[String] = [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"########"
	]
	var player: Vector2i = Vector2i(1, 2)
	var crates: Array[Vector2i] = [Vector2i(2, 2)]
	var goals: Array[Vector2i] = [Vector2i(5, 2)]
	match clampi(level_index, 0, LEVEL_COUNT - 1):
		0:
			player = Vector2i(1, 2)
			crates = [Vector2i(2, 2)]
			goals = [Vector2i(5, 2)]
		1:
			player = Vector2i(1, 3)
			crates = [Vector2i(2, 2), Vector2i(2, 4)]
			goals = [Vector2i(5, 2), Vector2i(5, 4)]
		2:
			player = Vector2i(1, 3)
			crates = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]
			goals = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	return {
		"rows": rows,
		"player": player,
		"crates": crates,
		"goals": goals
	}

static func tile_at(rows: Array[String], position: Vector2i) -> String:
	if position.y < 0 or position.y >= rows.size():
		return "#"
	var row: String = rows[position.y]
	if position.x < 0 or position.x >= row.length():
		return "#"
	return row.substr(position.x, 1)

static func is_walkable(rows: Array[String], position: Vector2i) -> bool:
	return tile_at(rows, position) != "#"

static func attempt_move(rows: Array[String], player: Vector2i, crates: Array[Vector2i], direction: Vector2i) -> Dictionary:
	if direction == Vector2i.ZERO or (direction.x != 0 and direction.y != 0):
		return _unchanged(player, crates)
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return _unchanged(player, crates)
	var target: Vector2i = player + direction
	if not is_walkable(rows, target):
		return _unchanged(player, crates)
	var next_crates: Array[Vector2i] = crates.duplicate()
	var crate_index: int = next_crates.find(target)
	if crate_index >= 0:
		var beyond: Vector2i = target + direction
		if not is_walkable(rows, beyond) or next_crates.has(beyond):
			return _unchanged(player, crates)
		next_crates[crate_index] = beyond
	return {
		"moved": true,
		"player": target,
		"crates": next_crates
	}

static func is_solved(crates: Array[Vector2i], goals: Array[Vector2i]) -> bool:
	if crates.size() != goals.size():
		return false
	for crate in crates:
		if not goals.has(crate):
			return false
	return true

static func _unchanged(player: Vector2i, crates: Array[Vector2i]) -> Dictionary:
	return {
		"moved": false,
		"player": player,
		"crates": crates.duplicate()
	}
