extends RefCounted
class_name KROLLMicrobeScopeRules

const SPECIMENS: Array[Dictionary] = [
    {"id":"diatom","title":"DIATOM VALVE","focus":52,"magnification":3,"illumination":68,"stain":2},
    {"id":"pollen","title":"POLLEN GRAIN","focus":64,"magnification":2,"illumination":48,"stain":1},
    {"id":"tardigrade","title":"TARDIGRADE","focus":38,"magnification":4,"illumination":76,"stain":3}
]
const PARAMETER_LIMITS: Dictionary = {
    "focus": Vector2i(0, 100),
    "magnification": Vector2i(1, 5),
    "illumination": Vector2i(0, 100),
    "stain": Vector2i(0, 3)
}
const CAPTURES_PER_SPECIMEN: int = 5
const FOCUS_TOLERANCE: int = 4
const ILLUMINATION_TOLERANCE: int = 6

func specimen_count() -> int:
    return SPECIMENS.size()

func get_specimen_definition(index: int) -> Dictionary:
    if index < 0 or index >= SPECIMENS.size():
        return {}
    return SPECIMENS[index].duplicate(true)

func create_state(index: int, carried_score: int = 0, carried_captures: int = 0) -> Dictionary:
    var definition: Dictionary = get_specimen_definition(index)
    if definition.is_empty():
        return {}
    return {
        "specimen_index": index,
        "specimen_id": str(definition["id"]),
        "focus": 50,
        "magnification": 2,
        "illumination": 50,
        "stain": 0,
        "attempts_left": CAPTURES_PER_SPECIMEN,
        "status": "active",
        "score": carried_score,
        "captures": carried_captures,
        "last_clarity": 0,
        "last_errors": []
    }

func get_parameter_value(state: Dictionary, parameter: String) -> int:
    return int(state.get(parameter, -1))

func set_parameter(state: Dictionary, parameter: String, value: int) -> Dictionary:
    if str(state.get("status", "")) != "active":
        return {"ok": false, "reason": "not_active", "state": state.duplicate(true)}
    if not PARAMETER_LIMITS.has(parameter):
        return {"ok": false, "reason": "unknown_parameter", "state": state.duplicate(true)}
    var limits: Vector2i = PARAMETER_LIMITS[parameter]
    var next_state: Dictionary = state.duplicate(true)
    next_state[parameter] = clampi(value, limits.x, limits.y)
    return {"ok": true, "state": next_state}

func adjust_parameter(state: Dictionary, parameter: String, delta: int) -> Dictionary:
    if not PARAMETER_LIMITS.has(parameter):
        return {"ok": false, "reason": "unknown_parameter", "state": state.duplicate(true)}
    return set_parameter(state, parameter, get_parameter_value(state, parameter) + delta)

func evaluate(state: Dictionary) -> Dictionary:
    var definition: Dictionary = get_specimen_definition(int(state.get("specimen_index", -1)))
    if definition.is_empty():
        return {"ok": false, "success": false, "clarity": 0, "errors": ["unknown_specimen"]}
    var focus_error: int = abs(get_parameter_value(state, "focus") - int(definition["focus"]))
    var magnification_error: int = abs(get_parameter_value(state, "magnification") - int(definition["magnification"]))
    var illumination_error: int = abs(get_parameter_value(state, "illumination") - int(definition["illumination"]))
    var stain_error: int = abs(get_parameter_value(state, "stain") - int(definition["stain"]))
    var errors: Array[String] = []
    if focus_error > FOCUS_TOLERANCE:
        errors.append("focus")
    if magnification_error != 0:
        errors.append("magnification")
    if illumination_error > ILLUMINATION_TOLERANCE:
        errors.append("illumination")
    if stain_error != 0:
        errors.append("stain")
    var clarity: int = clampi(
        100 - focus_error * 2 - magnification_error * 18 - illumination_error - stain_error * 24,
        0,
        100
    )
    return {
        "ok": true,
        "success": errors.is_empty(),
        "clarity": clarity,
        "errors": errors,
        "focus_error": focus_error,
        "magnification_error": magnification_error,
        "illumination_error": illumination_error,
        "stain_error": stain_error
    }

func capture(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "active":
        return {"ok": false, "reason": "not_active", "state": state.duplicate(true)}
    var evaluation: Dictionary = evaluate(state)
    if not bool(evaluation.get("ok", false)):
        return {"ok": false, "reason": "invalid_specimen", "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    next_state["last_clarity"] = int(evaluation["clarity"])
    next_state["last_errors"] = evaluation["errors"].duplicate()
    if bool(evaluation["success"]):
        next_state["status"] = "captured"
        next_state["score"] = int(next_state.get("score", 0)) + int(evaluation["clarity"])
        next_state["captures"] = int(next_state.get("captures", 0)) + 1
        return {"ok": true, "captured": true, "state": next_state, "evaluation": evaluation}
    next_state["attempts_left"] = int(next_state.get("attempts_left", 0)) - 1
    if int(next_state["attempts_left"]) <= 0:
        next_state["attempts_left"] = 0
        next_state["status"] = "failed"
    return {"ok": true, "captured": false, "state": next_state, "evaluation": evaluation}

func next_specimen(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "captured":
        return {"ok": false, "reason": "specimen_not_captured", "state": state.duplicate(true)}
    var next_index: int = int(state.get("specimen_index", -1)) + 1
    if next_index >= SPECIMENS.size():
        var completed: Dictionary = state.duplicate(true)
        completed["status"] = "complete"
        return {"ok": true, "complete": true, "state": completed}
    return {
        "ok": true,
        "complete": false,
        "state": create_state(next_index, int(state.get("score", 0)), int(state.get("captures", 0)))
    }

func reset_specimen(state: Dictionary) -> Dictionary:
    var index: int = int(state.get("specimen_index", -1))
    if index < 0 or index >= SPECIMENS.size():
        return {"ok": false, "reason": "invalid_specimen", "state": state.duplicate(true)}
    var status: String = str(state.get("status", ""))
    if status == "complete":
        return {"ok": false, "reason": "campaign_complete", "state": state.duplicate(true)}
    if not ["active", "failed", "captured"].has(status):
        return {"ok": false, "reason": "invalid_status", "state": state.duplicate(true)}
    var carried_score: int = maxi(0, int(state.get("score", 0)))
    var carried_captures: int = maxi(0, int(state.get("captures", 0)))
    if status == "captured":
        var credited_clarity: int = clampi(int(state.get("last_clarity", 0)), 0, 100)
        carried_score = maxi(0, carried_score - credited_clarity)
        carried_captures = maxi(0, carried_captures - 1)
    return {
        "ok": true,
        "state": create_state(index, carried_score, carried_captures)
    }
