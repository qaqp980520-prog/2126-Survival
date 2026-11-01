extends RefCounted
class_name KROLLFossilAssemblyRules

const BOARD_SIZE: int = 5
const LEVELS: Array = [
    {
        "id": "triceratops_skull",
        "title": "TRICERATOPS SKULL",
        "target_cells": [
            Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1),
            Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 4),
            Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(3, 3)
        ],
        "pieces": [
            {"id": "horn", "name": "HORN", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], "solution_origin": Vector2i(0, 0), "solution_rotation": 0},
            {"id": "jaw", "name": "JAW", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)], "solution_origin": Vector2i(0, 2), "solution_rotation": 0},
            {"id": "frill", "name": "FRILL", "cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], "solution_origin": Vector2i(2, 2), "solution_rotation": 0}
        ]
    },
    {
        "id": "ammonite",
        "title": "AMMONITE",
        "target_cells": [
            Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
            Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2),
            Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 4)
        ],
        "pieces": [
            {"id": "spine", "name": "SPINE", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)], "solution_origin": Vector2i(0, 0), "solution_rotation": 0},
            {"id": "rib", "name": "RIB", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)], "solution_origin": Vector2i(2, 0), "solution_rotation": 0},
            {"id": "shell", "name": "SHELL", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "solution_origin": Vector2i(1, 3), "solution_rotation": 0}
        ]
    },
    {
        "id": "raptor_claw",
        "title": "RAPTOR CLAW",
        "target_cells": [
            Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1),
            Vector2i(0, 1), Vector2i(1, 2), Vector2i(3, 1), Vector2i(4, 1),
            Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4)
        ],
        "pieces": [
            {"id": "claw", "name": "CLAW", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], "solution_origin": Vector2i(0, 0), "solution_rotation": 1},
            {"id": "tail", "name": "TAIL", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], "solution_origin": Vector2i(2, 0), "solution_rotation": 0},
            {"id": "plate", "name": "PLATE", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "solution_origin": Vector2i(0, 3), "solution_rotation": 0}
        ]
    }
]

static func level_count() -> int:
    return LEVELS.size()

static func get_level_definition(level_index: int) -> Dictionary:
    if level_index < 0 or level_index >= LEVELS.size():
        return {}
    return LEVELS[level_index].duplicate(true)

static func create_state(level_index: int) -> Dictionary:
    var definition: Dictionary = get_level_definition(level_index)
    if definition.is_empty():
        return {}
    var piece_states: Dictionary = {}
    for piece in definition["pieces"]:
        piece_states[str(piece["id"])] = {
            "placed": false,
            "origin": Vector2i.ZERO,
            "rotation": 0
        }
    return {
        "level_index": level_index,
        "level_id": str(definition["id"]),
        "title": str(definition["title"]),
        "board_size": BOARD_SIZE,
        "target_cells": definition["target_cells"].duplicate(),
        "pieces": piece_states,
        "occupied": {},
        "status": "playing",
        "moves": 0
    }

static func get_piece_definition(level_index: int, piece_id: String) -> Dictionary:
    var definition: Dictionary = get_level_definition(level_index)
    for piece in definition.get("pieces", []):
        if str(piece["id"]) == piece_id:
            return piece.duplicate(true)
    return {}

static func get_reference_solution(level_index: int) -> Array:
    var definition: Dictionary = get_level_definition(level_index)
    var solution: Array = []
    for piece in definition.get("pieces", []):
        solution.append({
            "piece_id": str(piece["id"]),
            "origin": piece["solution_origin"],
            "rotation": int(piece["solution_rotation"])
        })
    return solution

static func transformed_cells(shape: Array, origin: Vector2i, rotation: int) -> Array[Vector2i]:
    var points: Array[Vector2i] = []
    for cell in shape:
        var point: Vector2i = cell
        for _turn in range(posmod(rotation, 4)):
            point = Vector2i(-point.y, point.x)
        points.append(point)
    if points.is_empty():
        return []
    var min_x: int = points[0].x
    var min_y: int = points[0].y
    for point in points:
        min_x = mini(min_x, point.x)
        min_y = mini(min_y, point.y)
    var normalized: Array[Vector2i] = []
    for point in points:
        normalized.append(origin + Vector2i(point.x - min_x, point.y - min_y))
    return normalized

static func can_place(state: Dictionary, piece_id: String, origin: Vector2i, rotation: int) -> Dictionary:
    if state.get("status", "") != "playing":
        return {"ok": false, "reason": "not_playing"}
    var level_index: int = int(state.get("level_index", -1))
    var piece_state: Dictionary = state.get("pieces", {}).get(piece_id, {})
    if piece_state.is_empty():
        return {"ok": false, "reason": "unknown_piece"}
    if bool(piece_state.get("placed", false)):
        return {"ok": false, "reason": "already_placed"}
    var piece: Dictionary = get_piece_definition(level_index, piece_id)
    if piece.is_empty():
        return {"ok": false, "reason": "unknown_piece"}
    var cells: Array[Vector2i] = transformed_cells(piece["cells"], origin, rotation)
    var target_cells: Array = state.get("target_cells", [])
    var occupied: Dictionary = state.get("occupied", {})
    for cell in cells:
        if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_SIZE or cell.y >= BOARD_SIZE:
            return {"ok": false, "reason": "out_of_bounds", "cells": cells}
        if not target_cells.has(cell):
            return {"ok": false, "reason": "outside_specimen", "cells": cells}
        if occupied.has(cell):
            return {"ok": false, "reason": "overlap", "cells": cells}
    return {"ok": true, "cells": cells}

static func place_piece(state: Dictionary, piece_id: String, origin: Vector2i, rotation: int) -> Dictionary:
    var check: Dictionary = can_place(state, piece_id, origin, rotation)
    if not bool(check.get("ok", false)):
        return {"ok": false, "reason": str(check.get("reason", "invalid_placement")), "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    var piece_state: Dictionary = next_state["pieces"][piece_id]
    piece_state["placed"] = true
    piece_state["origin"] = origin
    piece_state["rotation"] = posmod(rotation, 4)
    next_state["pieces"][piece_id] = piece_state
    for cell in check["cells"]:
        next_state["occupied"][cell] = piece_id
    next_state["moves"] = int(next_state.get("moves", 0)) + 1
    if is_complete(next_state):
        next_state["status"] = "won"
    return {"ok": true, "state": next_state, "cells": check["cells"]}

static func remove_piece(state: Dictionary, piece_id: String) -> Dictionary:
    var piece_state: Dictionary = state.get("pieces", {}).get(piece_id, {})
    if piece_state.is_empty() or not bool(piece_state.get("placed", false)):
        return {"ok": false, "reason": "not_placed", "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    for cell in next_state["occupied"].keys():
        if str(next_state["occupied"][cell]) == piece_id:
            next_state["occupied"].erase(cell)
    piece_state = next_state["pieces"][piece_id]
    piece_state["placed"] = false
    piece_state["origin"] = Vector2i.ZERO
    piece_state["rotation"] = 0
    next_state["pieces"][piece_id] = piece_state
    next_state["status"] = "playing"
    next_state["moves"] = int(next_state.get("moves", 0)) + 1
    return {"ok": true, "state": next_state}

static func is_complete(state: Dictionary) -> bool:
    var target_cells: Array = state.get("target_cells", [])
    var occupied: Dictionary = state.get("occupied", {})
    if target_cells.is_empty() or occupied.size() != target_cells.size():
        return false
    for cell in target_cells:
        if not occupied.has(cell):
            return false
    return true
