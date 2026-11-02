extends RefCounted

const BOARD_WIDTH := 6
const BOARD_HEIGHT := 6
const PIECE_ORDER: Array[String] = ["ION", "FORK", "HOOK", "CORE"]
const BASE_SHAPES: Dictionary = {
	"ION": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	"FORK": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	"HOOK": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
	"CORE": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
}
const PIECE_NAMES: Dictionary = {"ION": "Ion Rail", "FORK": "Fork Module", "HOOK": "Hook Module", "CORE": "Core Block"}
const LEVELS: Array[Dictionary] = [
	{"id":"dockside","name":"Dockside Matrix","placements":{
		"ION":{"origin":Vector2i(1,1),"rotation":3},
		"FORK":{"origin":Vector2i(2,4),"rotation":0},
		"HOOK":{"origin":Vector2i(4,0),"rotation":0},
		"CORE":{"origin":Vector2i(2,1),"rotation":0}}},
	{"id":"fracture","name":"Fracture Bay","placements":{
		"ION":{"origin":Vector2i(1,2),"rotation":0},
		"FORK":{"origin":Vector2i(0,3),"rotation":1},
		"HOOK":{"origin":Vector2i(4,3),"rotation":2},
		"CORE":{"origin":Vector2i(3,4),"rotation":2}}},
	{"id":"orbital","name":"Orbital Hold","placements":{
		"ION":{"origin":Vector2i(5,2),"rotation":1},
		"FORK":{"origin":Vector2i(1,1),"rotation":1},
		"HOOK":{"origin":Vector2i(2,4),"rotation":3},
		"CORE":{"origin":Vector2i(3,1),"rotation":0}}}
]

static func get_level_count() -> int:
	return LEVELS.size()

static func get_piece_ids() -> Array[String]:
	return PIECE_ORDER.duplicate()

static func get_piece_name(piece_id: String) -> String:
	return str(PIECE_NAMES.get(piece_id, piece_id))

static func get_piece_cells(piece_id: String, rotation: int = 0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw_cell in BASE_SHAPES.get(piece_id, []):
		var cell: Vector2i = raw_cell
		for _turn in range(posmod(rotation, 4)):
			cell = Vector2i(-cell.y, cell.x)
		cells.append(cell)
	if cells.is_empty():
		return cells
	var min_x: int = cells[0].x
	var min_y: int = cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for index in range(cells.size()):
		cells[index] -= Vector2i(min_x, min_y)
	return cells

static func get_placement_cells(piece_id: String, placement: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin: Vector2i = placement.get("origin", Vector2i.ZERO)
	for cell in get_piece_cells(piece_id, int(placement.get("rotation", 0))):
		result.append(origin + cell)
	return result

static func get_level_data(level_index: int) -> Dictionary:
	if level_index < 0 or level_index >= LEVELS.size():
		return {}
	var source: Dictionary = LEVELS[level_index]
	var targets: Array[Vector2i] = []
	for piece_id in PIECE_ORDER:
		for cell in get_placement_cells(piece_id, source["placements"][piece_id]):
			if not targets.has(cell):
				targets.append(cell)
	return {"id": source["id"], "name": source["name"], "target_cells": targets}

static func can_place(level_index: int, placements: Dictionary, piece_id: String, origin: Vector2i, rotation: int) -> Dictionary:
	if level_index < 0 or level_index >= LEVELS.size():
		return {"ok": false, "reason": "invalid_level", "cells": []}
	if not BASE_SHAPES.has(piece_id):
		return {"ok": false, "reason": "invalid_piece", "cells": []}
	if placements.has(piece_id):
		return {"ok": false, "reason": "already_placed", "cells": []}
	var targets: Array[Vector2i] = get_level_data(level_index)["target_cells"]
	var occupied: Dictionary = {}
	for existing_id in placements:
		for cell in get_placement_cells(str(existing_id), placements[existing_id]):
			occupied[cell] = true
	var candidate: Array[Vector2i] = get_placement_cells(piece_id, {"origin": origin, "rotation": posmod(rotation, 4)})
	for cell in candidate:
		if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_WIDTH or cell.y >= BOARD_HEIGHT:
			return {"ok": false, "reason": "outside_board", "cells": candidate}
		if not targets.has(cell):
			return {"ok": false, "reason": "blocked_cell", "cells": candidate}
		if occupied.has(cell):
			return {"ok": false, "reason": "overlap", "cells": candidate}
	return {"ok": true, "reason": "", "cells": candidate}

static func place_piece(level_index: int, placements: Dictionary, piece_id: String, origin: Vector2i, rotation: int) -> Dictionary:
	var check: Dictionary = can_place(level_index, placements, piece_id, origin, rotation)
	if not bool(check.get("ok", false)):
		return check
	var next: Dictionary = placements.duplicate(true)
	next[piece_id] = {"origin": origin, "rotation": posmod(rotation, 4)}
	return {"ok": true, "reason": "", "placements": next, "cells": check["cells"]}

static func remove_piece(placements: Dictionary, piece_id: String) -> Dictionary:
	var next: Dictionary = placements.duplicate(true)
	next.erase(piece_id)
	return next

static func is_solved(level_index: int, placements: Dictionary) -> bool:
	if level_index < 0 or level_index >= LEVELS.size() or placements.size() != PIECE_ORDER.size():
		return false
	var targets: Array[Vector2i] = get_level_data(level_index)["target_cells"]
	var occupied: Dictionary = {}
	for piece_id in PIECE_ORDER:
		if not placements.has(piece_id):
			return false
		for cell in get_placement_cells(piece_id, placements[piece_id]):
			if not targets.has(cell) or occupied.has(cell):
				return false
			occupied[cell] = true
	return occupied.size() == targets.size()
