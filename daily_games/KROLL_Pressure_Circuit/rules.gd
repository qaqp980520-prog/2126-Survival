extends RefCounted
class_name PressureCircuitRules

const COLS: int = 6
const ROWS: int = 6
const MAX_MOVES: int = 30

const DIR_N: int = 1
const DIR_E: int = 2
const DIR_S: int = 4
const DIR_W: int = 8
const ALL_DIRECTIONS: int = 15

static func create_puzzle(seed_value: int = 20261028) -> Dictionary:
	var solution_masks: Array = []
	for _index in range(COLS * ROWS):
		solution_masks.append(0)

	var path: Array[Vector2i] = [
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(3, 1),
		Vector2i(3, 2),
		Vector2i(3, 3),
		Vector2i(4, 3),
		Vector2i(5, 3)
	]
	for index in range(path.size()):
		var mask := 0
		if index > 0:
			# Connector bits point outward from this cell, so the previous
			# path cell is the reverse of the forward path delta.
			mask |= _direction_bit(path[index - 1] - path[index])
		if index < path.size() - 1:
			mask |= _direction_bit(path[index + 1] - path[index])
		solution_masks[_cell_index(path[index])] = mask

	var masks: Array = solution_masks.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cell in path:
		var index := _cell_index(cell)
		var turns := rng.randi_range(1, 3)
		for _turn in range(turns):
			masks[index] = rotate_mask(int(masks[index]))

	return {
		"cols": COLS,
		"rows": ROWS,
		"seed": seed_value,
		"source": path[0],
		"target": path[path.size() - 1],
		"path": path,
		"masks": masks,
		"solution_masks": solution_masks,
		"moves": 0
	}

static func rotate_mask(mask: int) -> int:
	var normalized := mask & ALL_DIRECTIONS
	return ((normalized << 1) & ALL_DIRECTIONS) | ((normalized >> 3) & 1)

static func rotate_tile(state: Dictionary, cell: Vector2i) -> bool:
	if int(state.get("moves", 0)) >= MAX_MOVES or is_solved(state):
		return false
	if not _inside_board(cell):
		return false
	var masks: Variant = state.get("masks", null)
	if not (masks is Array):
		return false
	var index := _cell_index(cell)
	if index < 0 or index >= masks.size() or int(masks[index]) == 0:
		return false
	masks[index] = rotate_mask(int(masks[index]))
	state["moves"] = int(state.get("moves", 0)) + 1
	return true

static func is_solved(state: Dictionary) -> bool:
	var target_value: Variant = state.get("target", null)
	if not (target_value is Vector2i) or not _inside_board(target_value):
		return false
	return _reachable_cells(state).has(_cell_index(target_value))

static func is_failed(state: Dictionary) -> bool:
	return int(state.get("moves", 0)) >= MAX_MOVES and not is_solved(state)

static func get_mask(state: Dictionary, cell: Vector2i) -> int:
	if not _inside_board(cell):
		return 0
	var masks: Variant = state.get("masks", null)
	if not (masks is Array):
		return 0
	var index := _cell_index(cell)
	if index < 0 or index >= masks.size():
		return 0
	return int(masks[index])

static func _reachable_cells(state: Dictionary) -> Dictionary:
	var masks: Variant = state.get("masks", null)
	var source_value: Variant = state.get("source", null)
	if not (masks is Array) or masks.size() != COLS * ROWS:
		return {}
	if not (source_value is Vector2i) or not _inside_board(source_value):
		return {}
	var queue: Array[Vector2i] = [source_value]
	var visited: Dictionary = {_cell_index(source_value): true}
	var directions: Array = [
		[Vector2i(0, -1), DIR_N, DIR_S],
		[Vector2i(1, 0), DIR_E, DIR_W],
		[Vector2i(0, 1), DIR_S, DIR_N],
		[Vector2i(-1, 0), DIR_W, DIR_E]
	]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_index := _cell_index(current)
		if current_index < 0 or current_index >= masks.size():
			continue
		var current_mask := int(masks[current_index])
		for direction in directions:
			var delta: Vector2i = direction[0]
			var outgoing_bit: int = int(direction[1])
			var incoming_bit: int = int(direction[2])
			if (current_mask & outgoing_bit) == 0:
				continue
			var next_cell := current + delta
			if not _inside_board(next_cell):
				continue
			var next_index := _cell_index(next_cell)
			if next_index < 0 or next_index >= masks.size() or visited.has(next_index):
				continue
			if (int(masks[next_index]) & incoming_bit) == 0:
				continue
			visited[next_index] = true
			queue.append(next_cell)
	return visited

static func _inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS

static func _cell_index(cell: Vector2i) -> int:
	return cell.y * COLS + cell.x

static func _direction_bit(delta: Vector2i) -> int:
	if delta == Vector2i(0, -1):
		return DIR_N
	if delta == Vector2i(1, 0):
		return DIR_E
	if delta == Vector2i(0, 1):
		return DIR_S
	if delta == Vector2i(-1, 0):
		return DIR_W
	return 0
