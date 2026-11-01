extends RefCounted
class_name KROLLFaultlineCartographerRules

const GRID_SIZE: int = 7
const PROBE_DEFINITIONS: Array[Dictionary] = [
    {"id": "NW", "label": "NORTHWEST", "position": Vector2i(0, 0)},
    {"id": "NE", "label": "NORTHEAST", "position": Vector2i(6, 0)},
    {"id": "SW", "label": "SOUTHWEST", "position": Vector2i(0, 6)}
]
const SURVEYS: Array[Dictionary] = [
    {"id": "iron_vein", "title": "IRON VEIN", "target": Vector2i(2, 4)},
    {"id": "quartz_seam", "title": "QUARTZ SEAM", "target": Vector2i(5, 1)},
    {"id": "uranium_pocket", "title": "URANIUM POCKET", "target": Vector2i(3, 3)}
]

func survey_count() -> int:
    return SURVEYS.size()

func get_survey_definition(index: int) -> Dictionary:
    if index < 0 or index >= SURVEYS.size():
        return {}
    return SURVEYS[index].duplicate(true)

func get_probe_definitions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for probe in PROBE_DEFINITIONS:
        result.append(probe.duplicate(true))
    return result

func create_state(index: int, carried_score: int = 0) -> Dictionary:
    var definition: Dictionary = get_survey_definition(index)
    if definition.is_empty():
        return {}
    return {
        "survey_index": index,
        "survey_id": str(definition["id"]),
        "title": str(definition["title"]),
        "readings": {},
        "candidate_cells": _all_cells(),
        "selected_cell": Vector2i(-1, -1),
        "status": "scanning",
        "score": carried_score,
        "last_message": "Activate the three perimeter probes to triangulate the deposit."
    }

func activate_probe(state: Dictionary, probe_id: String) -> Dictionary:
    if str(state.get("status", "")) != "scanning":
        return {"ok": false, "reason": "not_scanning", "state": state.duplicate(true)}
    var probe: Dictionary = _find_probe(probe_id)
    if probe.is_empty():
        return {"ok": false, "reason": "unknown_probe", "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    var readings: Dictionary = next_state["readings"]
    if readings.has(probe_id):
        return {"ok": false, "reason": "probe_already_used", "state": state.duplicate(true)}
    var survey: Dictionary = get_survey_definition(int(next_state.get("survey_index", -1)))
    if survey.is_empty():
        return {"ok": false, "reason": "invalid_survey", "state": state.duplicate(true)}
    var target: Vector2i = survey["target"]
    var probe_position: Vector2i = probe["position"]
    readings[probe_id] = _rounded_euclidean_distance(probe_position, target)
    next_state["readings"] = readings
    next_state["candidate_cells"] = get_candidates(next_state)
    next_state["selected_cell"] = Vector2i(-1, -1)
    if readings.size() >= PROBE_DEFINITIONS.size():
        next_state["status"] = "locate"
        next_state["last_message"] = "Triangulation complete: %d candidate cell(s) remain." % next_state["candidate_cells"].size()
    else:
        next_state["last_message"] = "%s probe returned %d grid units. %d candidate cell(s) remain." % [
            str(probe["label"]), int(readings[probe_id]), next_state["candidate_cells"].size()
        ]
    return {"ok": true, "state": next_state}

func get_candidates(state: Dictionary) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    var readings: Dictionary = state.get("readings", {})
    var survey: Dictionary = get_survey_definition(int(state.get("survey_index", -1)))
    if survey.is_empty():
        return candidates
    for y in range(GRID_SIZE):
        for x in range(GRID_SIZE):
            var cell := Vector2i(x, y)
            var matches: bool = true
            for probe_id in readings.keys():
                var probe: Dictionary = _find_probe(str(probe_id))
                if probe.is_empty():
                    matches = false
                    break
                var expected: int = _rounded_euclidean_distance(probe["position"], cell)
                if expected != int(readings[probe_id]):
                    matches = false
                    break
            if matches:
                candidates.append(cell)
    return candidates

func get_candidate_cells(state: Dictionary) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for cell in state.get("candidate_cells", []):
        result.append(cell)
    return result

func select_cell(state: Dictionary, cell: Vector2i) -> Dictionary:
    if str(state.get("status", "")) != "locate":
        return {"ok": false, "reason": "triangulation_incomplete", "state": state.duplicate(true)}
    if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
        return {"ok": false, "reason": "out_of_bounds", "state": state.duplicate(true)}
    # Allow any in-bounds guess so an incorrect triangulation can fail the survey.
    var next_state: Dictionary = state.duplicate(true)
    next_state["selected_cell"] = cell
    next_state["last_message"] = "Candidate selected at (%d, %d). Submit to confirm the survey." % [cell.x, cell.y]
    return {"ok": true, "state": next_state}

func submit_guess(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "locate":
        return {"ok": false, "reason": "triangulation_incomplete", "state": state.duplicate(true)}
    var selected: Vector2i = state.get("selected_cell", Vector2i(-1, -1))
    if selected == Vector2i(-1, -1):
        return {"ok": false, "reason": "no_cell_selected", "state": state.duplicate(true)}
    var survey: Dictionary = get_survey_definition(int(state.get("survey_index", -1)))
    if survey.is_empty():
        return {"ok": false, "reason": "invalid_survey", "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    if selected == survey["target"]:
        next_state["status"] = "complete"
        next_state["score"] = int(next_state.get("score", 0)) + 100
        next_state["last_message"] = "Deposit located. Survey bonus: 100 points."
    else:
        next_state["status"] = "failed"
        next_state["last_message"] = "Incorrect location. The survey window is closed."
    return {"ok": true, "state": next_state, "completed": str(next_state["status"]) == "complete"}

func advance_survey(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "complete":
        return {"ok": false, "reason": "survey_not_complete", "state": state.duplicate(true)}
    var next_index: int = int(state.get("survey_index", -1)) + 1
    if next_index >= SURVEYS.size():
        var finished: Dictionary = state.duplicate(true)
        finished["status"] = "campaign_complete"
        finished["last_message"] = "All three deposits have been mapped."
        return {"ok": true, "complete": true, "state": finished}
    return {"ok": true, "complete": false, "state": create_state(next_index, int(state.get("score", 0)))}

func reset_survey(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) in ["complete", "campaign_complete"]:
        return {"ok": false, "reason": "already_complete", "state": state.duplicate(true)}
    var index: int = int(state.get("survey_index", -1))
    if index < 0 or index >= SURVEYS.size():
        return {"ok": false, "reason": "invalid_survey", "state": state.duplicate(true)}
    return {"ok": true, "state": create_state(index, int(state.get("score", 0)))}

func _find_probe(probe_id: String) -> Dictionary:
    for probe in PROBE_DEFINITIONS:
        if str(probe["id"]) == probe_id:
            return probe
    return {}

func _rounded_euclidean_distance(first: Vector2i, second: Vector2i) -> int:
    var delta := Vector2(float(first.x - second.x), float(first.y - second.y))
    return roundi(delta.length())

func _all_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(GRID_SIZE):
        for x in range(GRID_SIZE):
            cells.append(Vector2i(x, y))
    return cells
