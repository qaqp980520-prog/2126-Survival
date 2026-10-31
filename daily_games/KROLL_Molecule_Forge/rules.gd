extends RefCounted

const LEVEL_COUNT: int = 3
const GRID_SIZE: int = 5
const ELEMENTS: Array[String] = ["H", "O", "N", "C"]

static func get_level(index: int) -> Dictionary:
    match posmod(index, LEVEL_COUNT):
        0:
            return {
                "id": "water",
                "name": "WATER",
                "formula": {"H": 2, "O": 1},
                "formula_text": "H2O",
                "target_bonds": 2,
                "brief": "Build one oxygen bridge with two terminal hydrogen atoms."
            }
        1:
            return {
                "id": "ammonia",
                "name": "AMMONIA",
                "formula": {"H": 3, "N": 1},
                "formula_text": "NH3",
                "target_bonds": 3,
                "brief": "Connect three hydrogen atoms to one nitrogen center."
            }
        _:
            return {
                "id": "methane",
                "name": "METHANE",
                "formula": {"H": 4, "C": 1},
                "formula_text": "CH4",
                "target_bonds": 4,
                "brief": "Complete carbon's four single bonds with hydrogen."
            }

static func new_state(level_index: int) -> Dictionary:
    return {
        "level_index": posmod(level_index, LEVEL_COUNT),
        "atoms": [],
        "cursor": Vector2i(2, 2),
        "selected_element": "H",
        "moves": 0,
        "complete": false,
        "status": "SELECT AN ELEMENT, THEN PLACE IT ON THE GRID"
    }

static func get_valence(element: String) -> int:
    match element:
        "H":
            return 1
        "O":
            return 2
        "N":
            return 3
        "C":
            return 4
    return 0

static func get_element_color(element: String) -> Color:
    match element:
        "H":
            return Color("#dce8f2")
        "O":
            return Color("#f06b69")
        "N":
            return Color("#6e9df2")
        "C":
            return Color("#4c5968")
    return Color("#d84de8")

static func get_formula_text(index: int) -> String:
    return str(get_level(index).get("formula_text", ""))

static func place_atom(state: Dictionary, element: String, cell: Vector2i) -> Dictionary:
    if bool(state.get("complete", false)):
        return {"ok": false, "reason": "already_complete", "state": state.duplicate(true)}
    if not ELEMENTS.has(element):
        return {"ok": false, "reason": "invalid_element", "state": state.duplicate(true)}
    if not _is_valid_cell(cell):
        return {"ok": false, "reason": "invalid_cell", "state": state.duplicate(true)}
    var next: Dictionary = state.duplicate(true)
    var atoms: Array = next.get("atoms", []).duplicate(true)
    var current_counts: Dictionary = _count_elements(atoms)
    var formula: Dictionary = get_level(int(next.get("level_index", 0))).get("formula", {})
    if int(current_counts.get(element, 0)) >= int(formula.get(element, 0)):
        return {"ok": false, "reason": "atom_limit", "state": state.duplicate(true)}
    for atom_value in atoms:
        var atom: Dictionary = atom_value as Dictionary
        if atom.get("cell", Vector2i(-1, -1)) == cell:
            return {"ok": false, "reason": "occupied_cell", "state": state.duplicate(true)}
    atoms.append({"element": element, "cell": cell})
    var analysis: Dictionary = analyze_atoms(atoms)
    if not bool(analysis.get("ok", false)):
        return {"ok": false, "reason": str(analysis.get("reason", "invalid_bond")), "state": state.duplicate(true)}
    next["atoms"] = atoms
    next["moves"] = int(next.get("moves", 0)) + 1
    next["cursor"] = cell
    var report: Dictionary = evaluate(next)
    next["complete"] = bool(report.get("complete", false))
    next["status"] = str(report.get("status", "ATOM PLACED"))
    return {"ok": true, "reason": "placed", "state": next, "report": report}

static func remove_atom(state: Dictionary, cell: Vector2i) -> Dictionary:
    var next: Dictionary = state.duplicate(true)
    var atoms: Array = next.get("atoms", []).duplicate(true)
    for index in range(atoms.size()):
        var atom: Dictionary = atoms[index] as Dictionary
        if atom.get("cell", Vector2i(-1, -1)) == cell:
            atoms.remove_at(index)
            next["atoms"] = atoms
            next["moves"] = int(next.get("moves", 0)) + 1
            next["complete"] = false
            next["status"] = str(evaluate(next).get("status", "ATOM REMOVED"))
            return {"ok": true, "reason": "removed", "state": next}
    return {"ok": false, "reason": "empty_cell", "state": state.duplicate(true)}

static func evaluate(state: Dictionary) -> Dictionary:
    var atoms: Array = state.get("atoms", [])
    var analysis: Dictionary = analyze_atoms(atoms)
    if not bool(analysis.get("ok", false)):
        return {"complete": false, "status": "INVALID BOND: %s" % str(analysis.get("reason", "unknown")), "analysis": analysis}
    var level: Dictionary = get_level(int(state.get("level_index", 0)))
    var formula: Dictionary = level.get("formula", {})
    var counts: Dictionary = analysis.get("counts", {})
    var formula_ok: bool = _formula_matches(counts, formula)
    var connected: bool = bool(analysis.get("connected", false))
    var target_bonds: int = int(level.get("target_bonds", 0))
    var bonds: Array = analysis.get("edges", [])
    var saturated: bool = true
    var degrees: Array = analysis.get("degrees", [])
    for index in range(atoms.size()):
        var atom: Dictionary = atoms[index] as Dictionary
        var element: String = str(atom.get("element", ""))
        if index >= degrees.size() or int(degrees[index]) != get_valence(element):
            saturated = false
            break
    var complete: bool = formula_ok and connected and bonds.size() == target_bonds and saturated
    var status: String = "PLACE THE REQUIRED ATOMS"
    if formula_ok and not connected:
        status = "CONNECT EVERY ATOM INTO ONE MOLECULE"
    elif formula_ok and connected and not saturated:
        status = "COMPLETE EVERY AVAILABLE VALENCE"
    elif formula_ok and connected and bonds.size() != target_bonds:
        status = "BOND COUNT %d / %d" % [bonds.size(), target_bonds]
    elif complete:
        status = "%s STABLE · MOLECULE VERIFIED" % str(level.get("name", "MOLECULE"))
    return {
        "complete": complete,
        "status": status,
        "formula_ok": formula_ok,
        "connected": connected,
        "saturated": saturated,
        "bond_count": bonds.size(),
        "target_bonds": target_bonds,
        "counts": counts,
        "analysis": analysis
    }

static func analyze_atoms(atoms: Array) -> Dictionary:
    var counts: Dictionary = {"H": 0, "O": 0, "N": 0, "C": 0}
    var occupied: Dictionary = {}
    var degrees: Array[int] = []
    for index in range(atoms.size()):
        var atom_value: Variant = atoms[index]
        if not (atom_value is Dictionary):
            return {"ok": false, "reason": "invalid_atom"}
        var atom: Dictionary = atom_value as Dictionary
        var element: String = str(atom.get("element", ""))
        var cell_value: Variant = atom.get("cell", null)
        if not ELEMENTS.has(element) or not (cell_value is Vector2i):
            return {"ok": false, "reason": "invalid_atom"}
        var cell: Vector2i = cell_value
        if not _is_valid_cell(cell) or occupied.has(cell):
            return {"ok": false, "reason": "invalid_or_duplicate_cell"}
        occupied[cell] = index
        counts[element] = int(counts[element]) + 1
        degrees.append(0)
    var edges: Array[Vector2i] = []
    var adjacency: Array = []
    for _index in range(atoms.size()):
        adjacency.append([])
    var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
    for index in range(atoms.size()):
        var atom: Dictionary = atoms[index] as Dictionary
        var cell: Vector2i = atom["cell"]
        for direction in directions:
            var neighbor_cell: Vector2i = cell + direction
            if not occupied.has(neighbor_cell):
                continue
            var neighbor_index: int = int(occupied[neighbor_cell])
            edges.append(Vector2i(index, neighbor_index))
            degrees[index] = int(degrees[index]) + 1
            degrees[neighbor_index] = int(degrees[neighbor_index]) + 1
            adjacency[index].append(neighbor_index)
            adjacency[neighbor_index].append(index)
    for index in range(atoms.size()):
        var element: String = str((atoms[index] as Dictionary).get("element", ""))
        if int(degrees[index]) > get_valence(element):
            return {"ok": false, "reason": "valence_exceeded", "counts": counts, "degrees": degrees, "edges": edges}
    return {
        "ok": true,
        "reason": "valid",
        "counts": counts,
        "degrees": degrees,
        "edges": edges,
        "connected": _is_connected(adjacency, atoms.size())
    }

static func _count_elements(atoms: Array) -> Dictionary:
    var counts: Dictionary = {"H": 0, "O": 0, "N": 0, "C": 0}
    for atom_value in atoms:
        if atom_value is Dictionary:
            var element: String = str((atom_value as Dictionary).get("element", ""))
            if counts.has(element):
                counts[element] = int(counts[element]) + 1
    return counts

static func _formula_matches(counts: Dictionary, formula: Dictionary) -> bool:
    for element in ELEMENTS:
        if int(counts.get(element, 0)) != int(formula.get(element, 0)):
            return false
    return true

static func _is_connected(adjacency: Array, atom_count: int) -> bool:
    if atom_count <= 0:
        return false
    var pending: Array[int] = [0]
    var visited: Dictionary = {0: true}
    while not pending.is_empty():
        var current: int = pending.pop_front()
        for neighbor_value in adjacency[current]:
            var neighbor: int = int(neighbor_value)
            if visited.has(neighbor):
                continue
            visited[neighbor] = true
            pending.append(neighbor)
    return visited.size() == atom_count

static func _is_valid_cell(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE
