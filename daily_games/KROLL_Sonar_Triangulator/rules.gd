extends RefCounted

const BOARD_SIZE: int = 8
const MINIMUM_SCANS: int = 3
const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const SENSOR_NAMES: Array[String] = ["NORTHWEST", "NORTHEAST", "SOUTHWEST", "SOUTHEAST"]
const SENSOR_POSITIONS: Array[Vector2i] = [
    Vector2i(0, 0),
    Vector2i(7, 0),
    Vector2i(0, 7),
    Vector2i(7, 7)
]
const MISSIONS: Array[Dictionary] = [
    {
        "id": "nereid_wreck",
        "title": "NEREID WRECK",
        "briefing": "A survey beacon vanished near the old Nereid shipping lane. Triangulate its last acoustic return.",
        "target": Vector2i(2, 2)
    },
    {
        "id": "abyssal_relay",
        "title": "ABYSSAL RELAY",
        "briefing": "Two seabed cells produce the same first three rounded ranges. Use the fourth buoy or eliminate a false return.",
        "target": Vector2i(5, 3)
    },
    {
        "id": "trench_beacon",
        "title": "TRENCH BEACON",
        "briefing": "A deep-current beacon is broadcasting from the eastern trench. Recover its exact grid coordinate.",
        "target": Vector2i(6, 5)
    }
]

func create_state(mission_index: int = 0, campaign_score: int = 0) -> Dictionary:
    if mission_index < 0 or mission_index >= MISSIONS.size() or campaign_score < 0:
        return {}
    return {
        "mission_index": mission_index,
        "scans": {},
        "candidates": _find_candidates({}, []),
        "excluded_cells": [],
        "selected": INVALID_CELL,
        "wrong_guesses": 0,
        "mission_score": 0,
        "campaign_score": campaign_score,
        "status": "playing"
    }

func get_mission_count() -> int:
    return MISSIONS.size()

func get_sensor_count() -> int:
    return SENSOR_POSITIONS.size()

func get_mission_definition(mission_index: int) -> Dictionary:
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {}
    var definition: Dictionary = MISSIONS[mission_index].duplicate(true)
    definition.erase("target")
    return definition

func get_mission_target_for_test(mission_index: int) -> Vector2i:
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return INVALID_CELL
    return MISSIONS[mission_index]["target"]

func get_sensor_position(sensor_index: int) -> Vector2i:
    if sensor_index < 0 or sensor_index >= SENSOR_POSITIONS.size():
        return INVALID_CELL
    return SENSOR_POSITIONS[sensor_index]

func get_sensor_name(sensor_index: int) -> String:
    if sensor_index < 0 or sensor_index >= SENSOR_NAMES.size():
        return "UNKNOWN"
    return SENSOR_NAMES[sensor_index]

func scan_sensor(state: Dictionary, sensor_index: int) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return {"ok": false, "reason": "survey_not_active"}
    if sensor_index < 0 or sensor_index >= SENSOR_POSITIONS.size():
        return {"ok": false, "reason": "invalid_sensor"}
    var existing_scans: Variant = state.get("scans", {})
    if not (existing_scans is Dictionary):
        return {"ok": false, "reason": "invalid_scan_state"}
    if existing_scans.has(sensor_index):
        return {"ok": false, "reason": "sensor_already_used"}
    var mission_index: int = int(state.get("mission_index", -1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {"ok": false, "reason": "invalid_mission"}
    var target: Vector2i = MISSIONS[mission_index]["target"]
    var reading: int = _range_for(target, sensor_index)
    var next_state: Dictionary = state.duplicate(true)
    var scans: Dictionary = existing_scans.duplicate(true)
    scans[sensor_index] = reading
    next_state["scans"] = scans
    next_state["candidates"] = _find_candidates(scans, _get_excluded_cells(next_state))
    next_state["selected"] = INVALID_CELL
    return {
        "ok": true,
        "state": next_state,
        "reading": reading,
        "candidate_count": get_candidate_positions(next_state).size()
    }

func select_cell(state: Dictionary, cell: Vector2i) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return {"ok": false, "reason": "survey_not_active"}
    var scans: Variant = state.get("scans", {})
    if not (scans is Dictionary) or scans.size() < MINIMUM_SCANS:
        return {"ok": false, "reason": "scans_incomplete"}
    if cell.x < 0 or cell.x >= BOARD_SIZE or cell.y < 0 or cell.y >= BOARD_SIZE:
        return {"ok": false, "reason": "cell_out_of_bounds"}
    if not get_candidate_positions(state).has(cell):
        return {"ok": false, "reason": "cell_not_a_candidate"}
    var next_state: Dictionary = state.duplicate(true)
    next_state["selected"] = cell
    return {"ok": true, "state": next_state}

func submit_target(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "playing":
        return {"ok": false, "reason": "survey_not_active"}
    var scans: Variant = state.get("scans", {})
    if not (scans is Dictionary) or scans.size() < MINIMUM_SCANS:
        return {"ok": false, "reason": "scans_incomplete"}
    var selected_value: Variant = state.get("selected", INVALID_CELL)
    if not (selected_value is Vector2i) or not get_candidate_positions(state).has(selected_value):
        return {"ok": false, "reason": "no_valid_selection"}
    var mission_index: int = int(state.get("mission_index", -1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {"ok": false, "reason": "invalid_mission"}
    var next_state: Dictionary = state.duplicate(true)
    var target: Vector2i = MISSIONS[mission_index]["target"]
    if selected_value == target:
        var scans_used: int = scans.size()
        var wrong_guesses: int = int(next_state.get("wrong_guesses", 0))
        var penalty: int = maxi(0, scans_used - MINIMUM_SCANS) * 15 + wrong_guesses * 20
        var score: int = maxi(25, 100 - penalty)
        next_state["status"] = "passed"
        next_state["mission_score"] = score
        next_state["campaign_score"] = int(next_state.get("campaign_score", 0)) + score
        return {"ok": true, "hit": true, "score": score, "state": next_state}
    var wrong_guesses: int = int(next_state.get("wrong_guesses", 0)) + 1
    next_state["wrong_guesses"] = wrong_guesses
    var excluded: Array[Vector2i] = _get_excluded_cells(next_state)
    excluded.append(selected_value)
    next_state["excluded_cells"] = excluded
    next_state["candidates"] = _find_candidates(scans, excluded)
    next_state["selected"] = INVALID_CELL
    if get_candidate_positions(next_state).is_empty():
        next_state["status"] = "failed"
        return {"ok": true, "hit": false, "reason": "no_candidates_remain", "state": next_state}
    return {
        "ok": true,
        "hit": false,
        "reason": "false_return",
        "state": next_state,
        "candidate_count": get_candidate_positions(next_state).size()
    }

func advance_mission(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "passed":
        return {"ok": false, "reason": "mission_not_passed"}
    var current_index: int = int(state.get("mission_index", -1))
    if current_index < 0 or current_index >= MISSIONS.size():
        return {"ok": false, "reason": "invalid_mission"}
    var campaign_score: int = int(state.get("campaign_score", 0))
    if current_index + 1 >= MISSIONS.size():
        var completed: Dictionary = state.duplicate(true)
        completed["status"] = "campaign_complete"
        return {"ok": true, "state": completed}
    return {"ok": true, "state": create_state(current_index + 1, campaign_score)}

func restart_campaign() -> Dictionary:
    return {"ok": true, "state": create_state(0, 0)}

func get_candidate_positions(state: Dictionary) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    var raw: Variant = state.get("candidates", [])
    if raw is Array:
        for value in raw:
            if value is Vector2i:
                candidates.append(value)
    return candidates

func get_excluded_cells(state: Dictionary) -> Array[Vector2i]:
    return _get_excluded_cells(state)

func get_scan_count(state: Dictionary) -> int:
    var scans: Variant = state.get("scans", {})
    return scans.size() if scans is Dictionary else 0

func get_scan_reading(state: Dictionary, sensor_index: int) -> int:
    var scans: Variant = state.get("scans", {})
    if not (scans is Dictionary) or not scans.has(sensor_index):
        return -1
    return int(scans[sensor_index])

func get_candidate_count(state: Dictionary) -> int:
    return get_candidate_positions(state).size()

func get_mission_score(state: Dictionary) -> int:
    return int(state.get("mission_score", 0))

func get_campaign_score(state: Dictionary) -> int:
    return int(state.get("campaign_score", 0))

func get_status(state: Dictionary) -> String:
    return str(state.get("status", ""))

func _get_excluded_cells(state: Dictionary) -> Array[Vector2i]:
    var excluded: Array[Vector2i] = []
    var raw: Variant = state.get("excluded_cells", [])
    if raw is Array:
        for value in raw:
            if value is Vector2i:
                excluded.append(value)
    return excluded

func _find_candidates(scans: Dictionary, excluded: Array[Vector2i]) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    for x in range(BOARD_SIZE):
        for y in range(BOARD_SIZE):
            var cell := Vector2i(x, y)
            if excluded.has(cell):
                continue
            var matches: bool = true
            for sensor_key in scans.keys():
                var sensor_index: int = int(sensor_key)
                if _range_for(cell, sensor_index) != int(scans[sensor_key]):
                    matches = false
                    break
            if matches:
                candidates.append(cell)
    return candidates

func _range_for(cell: Vector2i, sensor_index: int) -> int:
    var sensor: Vector2i = SENSOR_POSITIONS[sensor_index]
    var cell_position := Vector2(float(cell.x), float(cell.y))
    var sensor_position := Vector2(float(sensor.x), float(sensor.y))
    return int(roundf(cell_position.distance_to(sensor_position)))
