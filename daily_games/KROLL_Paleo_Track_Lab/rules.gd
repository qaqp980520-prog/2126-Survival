extends RefCounted
class_name KROLLPaleoTrackLabRules

const SPECIES_OPTIONS: Array[Dictionary] = [
    {"id": "small_ornithopod", "label": "SMALL ORNITHOPOD"},
    {"id": "large_theropod", "label": "LARGE THEROPOD"},
    {"id": "sauropod", "label": "SAUROPOD"}
]
const GAIT_OPTIONS: Array[Dictionary] = [
    {"id": "walk", "label": "WALK"},
    {"id": "run", "label": "RUN"}
]
const HEADING_OPTIONS: Array[Dictionary] = [
    {"id": "N", "label": "N"}, {"id": "NE", "label": "NE"},
    {"id": "E", "label": "E"}, {"id": "SE", "label": "SE"},
    {"id": "S", "label": "S"}, {"id": "SW", "label": "SW"},
    {"id": "W", "label": "W"}, {"id": "NW", "label": "NW"}
]
const SITES: Array[Dictionary] = [
    {"id": "fern_basin", "title": "FERN BASIN", "foot_length_cm": 22.0, "foot_width_cm": 16.0, "stride_cm": 154.0, "track_gauge_cm": 28.0, "bearing_deg": 92.0, "print_count": 5},
    {"id": "ridge_pass", "title": "RIDGE PASS", "foot_length_cm": 46.0, "foot_width_cm": 34.0, "stride_cm": 460.0, "track_gauge_cm": 38.0, "bearing_deg": 315.0, "print_count": 5},
    {"id": "river_plain", "title": "RIVER PLAIN", "foot_length_cm": 68.0, "foot_width_cm": 60.0, "stride_cm": 408.0, "track_gauge_cm": 104.0, "bearing_deg": 180.0, "print_count": 5}
]

func site_count() -> int:
    return SITES.size()

func get_site_definition(index: int) -> Dictionary:
    if index < 0 or index >= SITES.size():
        return {}
    return SITES[index].duplicate(true)

func get_species_options() -> Array[Dictionary]:
    return SPECIES_OPTIONS.duplicate(true)

func get_gait_options() -> Array[Dictionary]:
    return GAIT_OPTIONS.duplicate(true)

func get_heading_options() -> Array[Dictionary]:
    return HEADING_OPTIONS.duplicate(true)

func create_state(index: int, carried_score: int = 0) -> Dictionary:
    var site: Dictionary = get_site_definition(index)
    if site.is_empty():
        return {}
    return {"site_index": index, "site_id": str(site["id"]), "title": str(site["title"]), "answers": {"species": "", "gait": "", "heading": ""}, "status": "scanning", "score": carried_score, "last_message": "Measure the trackway, then identify its maker, gait and heading."}

func infer_species(site: Dictionary) -> String:
    var foot_length: float = float(site.get("foot_length_cm", 0.0))
    var track_gauge: float = float(site.get("track_gauge_cm", 0.0))
    if foot_length >= 56.0 and track_gauge >= 80.0:
        return "sauropod"
    if foot_length >= 32.0:
        return "large_theropod"
    return "small_ornithopod"

func infer_gait(site: Dictionary) -> String:
    var foot_length: float = float(site.get("foot_length_cm", 0.0))
    if foot_length <= 0.0:
        return ""
    return "run" if float(site.get("stride_cm", 0.0)) / foot_length >= 8.5 else "walk"

func infer_heading(site: Dictionary) -> String:
    var normalized_bearing: float = fposmod(float(site.get("bearing_deg", 0.0)), 360.0)
    var heading_index: int = int(round(normalized_bearing / 45.0)) % HEADING_OPTIONS.size()
    return str(HEADING_OPTIONS[heading_index]["id"])

func get_correct_answer(index: int) -> Dictionary:
    var site: Dictionary = get_site_definition(index)
    if site.is_empty():
        return {}
    return {"species": infer_species(site), "gait": infer_gait(site), "heading": infer_heading(site)}

func set_answer(state: Dictionary, field: String, value: String) -> Dictionary:
    if str(state.get("status", "")) != "scanning":
        return {"ok": false, "reason": "survey_not_open", "state": state.duplicate(true)}
    var valid_value: bool = false
    match field:
        "species":
            valid_value = _contains_option(SPECIES_OPTIONS, value)
        "gait":
            valid_value = _contains_option(GAIT_OPTIONS, value)
        "heading":
            valid_value = _contains_option(HEADING_OPTIONS, value)
        _:
            return {"ok": false, "reason": "invalid_field", "state": state.duplicate(true)}
    if not valid_value:
        return {"ok": false, "reason": "invalid_value", "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    var answers: Dictionary = next_state.get("answers", {}).duplicate(true)
    answers[field] = value
    next_state["answers"] = answers
    next_state["last_message"] = "%s answer recorded." % field.capitalize()
    return {"ok": true, "state": next_state}

func submit_survey(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "scanning":
        return {"ok": false, "reason": "survey_not_open", "state": state.duplicate(true)}
    var answers: Dictionary = state.get("answers", {})
    for field in ["species", "gait", "heading"]:
        if not answers.has(field) or str(answers[field]).is_empty():
            return {"ok": false, "reason": "incomplete_answer", "state": state.duplicate(true)}
    var correct: Dictionary = get_correct_answer(int(state.get("site_index", -1)))
    if correct.is_empty():
        return {"ok": false, "reason": "invalid_site", "state": state.duplicate(true)}
    var next_state: Dictionary = state.duplicate(true)
    var matched: bool = str(answers.get("species", "")) == str(correct["species"]) and str(answers.get("gait", "")) == str(correct["gait"]) and str(answers.get("heading", "")) == str(correct["heading"])
    if matched:
        next_state["status"] = "complete"
        next_state["score"] = int(next_state.get("score", 0)) + 100
        next_state["last_message"] = "Trackway classified. Field report bonus: 100 points."
    else:
        next_state["status"] = "failed"
        next_state["last_message"] = "Classification mismatch. Reset the site and inspect the measurements again."
    return {"ok": true, "completed": matched, "state": next_state}

func advance_survey(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "complete":
        return {"ok": false, "reason": "survey_not_complete", "state": state.duplicate(true)}
    var next_index: int = int(state.get("site_index", -1)) + 1
    if next_index >= SITES.size():
        var finished: Dictionary = state.duplicate(true)
        finished["status"] = "campaign_complete"
        finished["last_message"] = "All three trackways have been documented."
        return {"ok": true, "complete": true, "state": finished}
    return {"ok": true, "complete": false, "state": create_state(next_index, int(state.get("score", 0)))}

func reset_survey(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) in ["complete", "campaign_complete"]:
        return {"ok": false, "reason": "already_complete", "state": state.duplicate(true)}
    var index: int = int(state.get("site_index", -1))
    if index < 0 or index >= SITES.size():
        return {"ok": false, "reason": "invalid_site", "state": state.duplicate(true)}
    return {"ok": true, "state": create_state(index, int(state.get("score", 0)))}

func _contains_option(options: Array[Dictionary], value: String) -> bool:
    for option in options:
        if str(option.get("id", "")) == value:
            return true
    return false
