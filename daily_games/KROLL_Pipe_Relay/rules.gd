extends RefCounted

const BOARD_SIZE: int = 4
const MAX_MOVES: int = 10

const LAYOUTS = [
	{
		"name": "Docking Spur",
		"source": [0, 1],
		"source_direction": 1,
		"target": [3, 2],
		"tiles": [
			{"cell": [1, 1], "shape": "elbow", "solution_rotation": 2},
			{"cell": [1, 2], "shape": "elbow", "solution_rotation": 0},
			{"cell": [2, 2], "shape": "straight", "solution_rotation": 1}
		]
	},
	{
		"name": "Cargo Descent",
		"source": [0, 0],
		"source_direction": 1,
		"target": [3, 3],
		"tiles": [
			{"cell": [1, 0], "shape": "elbow", "solution_rotation": 2},
			{"cell": [1, 1], "shape": "elbow", "solution_rotation": 0},
			{"cell": [2, 1], "shape": "elbow", "solution_rotation": 2},
			{"cell": [2, 2], "shape": "elbow", "solution_rotation": 0},
			{"cell": [3, 2], "shape": "elbow", "solution_rotation": 2}
		]
	},
	{
		"name": "Crosswind Relay",
		"source": [0, 3],
		"source_direction": 1,
		"target": [3, 0],
		"tiles": [
			{"cell": [1, 3], "shape": "elbow", "solution_rotation": 3},
			{"cell": [1, 2], "shape": "elbow", "solution_rotation": 1},
			{"cell": [2, 2], "shape": "elbow", "solution_rotation": 3},
			{"cell": [2, 1], "shape": "elbow", "solution_rotation": 1},
			{"cell": [3, 1], "shape": "elbow", "solution_rotation": 3}
		]
	}
]

static func create_layout(index: int) -> Dictionary:
	var blueprint: Dictionary = LAYOUTS[posmod(index, LAYOUTS.size())].duplicate(true)
	var source_data: Array = blueprint["source"]
	var target_data: Array = blueprint["target"]
	blueprint["source"] = Vector2i(int(source_data[0]), int(source_data[1]))
	blueprint["target"] = Vector2i(int(target_data[0]), int(target_data[1]))
	var tiles: Array = []
	for tile_value in blueprint["tiles"]:
		var tile: Dictionary = tile_value.duplicate(true)
		var cell_data: Array = tile["cell"]
		tile["cell"] = Vector2i(int(cell_data[0]), int(cell_data[1]))
		var solution_rotation: int = int(tile["solution_rotation"])
		if str(tile["shape"]) == "straight":
			# A straight pipe has 180-degree symmetry; start perpendicular to the solution.
			tile["rotation"] = posmod(solution_rotation + 1, 2)
		else:
			tile["rotation"] = posmod(solution_rotation + 2, 4)
		tiles.append(tile)
	blueprint["tiles"] = tiles
	blueprint["moves"] = 0
	blueprint["max_moves"] = MAX_MOVES
	blueprint["solved"] = false
	return blueprint


static func rotate_tile(state: Dictionary, tile_index: int) -> bool:
	var tiles_value: Variant = state.get("tiles", null)
	if not (tiles_value is Array) or tile_index < 0 or tile_index >= tiles_value.size():
		return false
	if bool(state.get("solved", false)) or int(state.get("moves", 0)) >= int(state.get("max_moves", MAX_MOVES)):
		return false
	var tiles: Array = tiles_value
	var tile_value: Variant = tiles[tile_index]
	if not (tile_value is Dictionary):
		return false
	var tile: Dictionary = tile_value
	tile["rotation"] = posmod(int(tile.get("rotation", 0)) + 1, 4)
	tiles[tile_index] = tile
	state["tiles"] = tiles
	state["moves"] = int(state.get("moves", 0)) + 1
	if bool(evaluate(state).get("connected", false)):
		state["solved"] = true
	return true


static func tile_matches_solution(tile: Dictionary) -> bool:
	var current_ports: Array = _ports_for(tile)
	var solution_tile: Dictionary = tile.duplicate(true)
	solution_tile["rotation"] = int(tile.get("solution_rotation", -1))
	var solution_ports: Array = _ports_for(solution_tile)
	return not current_ports.is_empty() and current_ports == solution_ports


static func tile_text(tile: Dictionary) -> String:
	var ports: Array = _ports_for(tile)
	if ports.is_empty():
		return "INVALID"
	var labels := PackedStringArray()
	for direction in ports:
		labels.append(["N", "E", "S", "W"][direction])
	return str(tile.get("shape", "PIPE")).to_upper() + "\n" + " / ".join(labels)


static func evaluate(state: Dictionary) -> Dictionary:
	var tiles_value: Variant = state.get("tiles", null)
	var source_value: Variant = state.get("source", null)
	var target_value: Variant = state.get("target", null)
	if not (tiles_value is Array) or not (source_value is Vector2i) or not (target_value is Vector2i):
		return {"connected": false, "reason": "invalid_board", "visited_tiles": 0}
	var source: Vector2i = source_value
	var target: Vector2i = target_value
	if not _inside(source) or not _inside(target) or source == target:
		return {"connected": false, "reason": "invalid_endpoints", "visited_tiles": 0}

	var tile_by_cell: Dictionary = {}
	for tile_value in tiles_value:
		if not (tile_value is Dictionary):
			return {"connected": false, "reason": "invalid_tile", "visited_tiles": 0}
		var tile: Dictionary = tile_value
		var cell_value: Variant = tile.get("cell", null)
		if not (cell_value is Vector2i):
			return {"connected": false, "reason": "invalid_tile_cell", "visited_tiles": 0}
		var cell: Vector2i = cell_value
		if not _inside(cell) or cell == source or cell == target or tile_by_cell.has(cell) or _ports_for(tile).size() != 2:
			return {"connected": false, "reason": "invalid_tile_layout", "visited_tiles": 0}
		tile_by_cell[cell] = tile

	var direction: int = int(state.get("source_direction", -1))
	if direction < 0 or direction > 3:
		return {"connected": false, "reason": "invalid_source_direction", "visited_tiles": 0}
	var current: Vector2i = source
	var visited: Dictionary = {}
	for _step_index in range(BOARD_SIZE * BOARD_SIZE + 1):
		var next_cell: Vector2i = _step(current, direction)
		if next_cell == target:
			var all_tiles_reached: bool = visited.size() == tiles_value.size()
			return {
				"connected": all_tiles_reached,
				"reason": "connected" if all_tiles_reached else "unpowered_tiles",
				"visited_tiles": visited.size()
			}
		if not _inside(next_cell):
			return {"connected": false, "reason": "out_of_bounds", "visited_tiles": visited.size()}
		if visited.has(next_cell):
			return {"connected": false, "reason": "loop", "visited_tiles": visited.size()}
		if not tile_by_cell.has(next_cell):
			return {"connected": false, "reason": "pipe_gap", "visited_tiles": visited.size()}
		var tile: Dictionary = tile_by_cell[next_cell]
		var ports: Array = _ports_for(tile)
		var incoming: int = posmod(direction + 2, 4)
		if not ports.has(incoming):
			return {"connected": false, "reason": "port_mismatch", "visited_tiles": visited.size()}
		var outgoing: int = -1
		for port in ports:
			if port != incoming:
				outgoing = port
		if outgoing < 0:
			return {"connected": false, "reason": "invalid_pipe", "visited_tiles": visited.size()}
		visited[next_cell] = true
		current = next_cell
		direction = outgoing
	return {"connected": false, "reason": "loop", "visited_tiles": visited.size()}


static func _ports_for(tile: Dictionary) -> Array:
	var shape: String = str(tile.get("shape", ""))
	var rotation: int = int(tile.get("rotation", -1))
	if rotation < 0 or rotation > 3:
		return []
	var base_ports: Array = []
	if shape == "elbow":
		base_ports = [0, 1] # north + east
	elif shape == "straight":
		base_ports = [0, 2] # north + south
	else:
		return []
	var result: Array = []
	for port in base_ports:
		result.append(posmod(port + rotation, 4))
	result.sort()
	return result


static func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE


static func _step(cell: Vector2i, direction: int) -> Vector2i:
	match direction:
		0:
			return cell + Vector2i(0, -1)
		1:
			return cell + Vector2i(1, 0)
		2:
			return cell + Vector2i(0, 1)
		3:
			return cell + Vector2i(-1, 0)
	return cell
