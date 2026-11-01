extends RefCounted
class_name KROLLReactorBalancerRules

const STABLE_CYCLES_REQUIRED: int = 4
const ACTIONS: Array[String] = ["acid", "base", "heat", "cool", "vent", "stir"]
const SCENARIOS: Array[Dictionary] = [
    {
        "id": "polymer_batch",
        "title": "POLYMER BATCH",
        "start": {"ph": 4.0, "temperature": 20.0, "pressure": 1.0},
        "target": {"ph": 7.0, "temperature": 50.0, "pressure": 1.6},
        "max_turns": 12
    },
    {
        "id": "cryo_solvent",
        "title": "CRYO SOLVENT",
        "start": {"ph": 9.0, "temperature": 65.0, "pressure": 2.5},
        "target": {"ph": 6.0, "temperature": 22.0, "pressure": 2.1},
        "max_turns": 12
    },
    {
        "id": "ceramic_sinter",
        "title": "CERAMIC SINTER",
        "start": {"ph": 5.0, "temperature": 35.0, "pressure": 0.5},
        "target": {"ph": 8.0, "temperature": 82.0, "pressure": 1.3},
        "max_turns": 12
    }
]

func scenario_count() -> int:
    return SCENARIOS.size()

func get_scenario_definition(index: int) -> Dictionary:
    if index < 0 or index >= SCENARIOS.size():
        return {}
    return SCENARIOS[index].duplicate(true)

func create_state(index: int, carried_score: int = 0) -> Dictionary:
    var definition: Dictionary = get_scenario_definition(index)
    if definition.is_empty():
        return {}
    var start: Dictionary = definition["start"]
    return {
        "scenario_index": index,
        "scenario_id": str(definition["id"]),
        "title": str(definition["title"]),
        "ph": float(start["ph"]),
        "temperature": float(start["temperature"]),
        "pressure": float(start["pressure"]),
        "turn": 0,
        "max_turns": int(definition["max_turns"]),
        "stable_streak": 0,
        "progress": 0,
        "score": carried_score,
        "status": "active",
        "last_action": "",
        "last_message": "Adjust the process, then stir four stable cycles."
    }

func is_within_target(state: Dictionary) -> bool:
    var definition: Dictionary = get_scenario_definition(int(state.get("scenario_index", -1)))
    if definition.is_empty():
        return false
    var target: Dictionary = definition["target"]
    return (
        absf(float(state.get("ph", -999.0)) - float(target["ph"])) <= 0.5
        and absf(float(state.get("temperature", -999.0)) - float(target["temperature"])) <= 10.0
        and absf(float(state.get("pressure", -999.0)) - float(target["pressure"])) <= 0.35
    )

func apply_action(state: Dictionary, action: String) -> Dictionary:
    if str(state.get("status", "")) != "active":
        return {"ok": false, "reason": "not_active", "state": state.duplicate(true)}
    if not ACTIONS.has(action):
        return {"ok": false, "reason": "unknown_action", "state": state.duplicate(true)}
    if int(state.get("turn", -1)) >= int(state.get("max_turns", 0)):
        var exhausted: Dictionary = state.duplicate(true)
        exhausted["status"] = "failed"
        exhausted["last_message"] = "The control window has expired."
        return {"ok": false, "reason": "turn_limit", "state": exhausted}

    var next_state: Dictionary = state.duplicate(true)
    next_state["turn"] = int(next_state["turn"]) + 1
    next_state["last_action"] = action
    match action:
        "acid":
            next_state["ph"] = maxf(0.0, float(next_state["ph"]) - 1.5)
            next_state["temperature"] = float(next_state["temperature"]) + 1.0
            next_state["pressure"] = float(next_state["pressure"]) + 0.1
        "base":
            next_state["ph"] = minf(14.0, float(next_state["ph"]) + 1.5)
            next_state["temperature"] = float(next_state["temperature"]) + 1.0
            next_state["pressure"] = float(next_state["pressure"]) + 0.1
        "heat":
            next_state["temperature"] = float(next_state["temperature"]) + 15.0
            next_state["pressure"] = float(next_state["pressure"]) + 0.2
        "cool":
            next_state["temperature"] = float(next_state["temperature"]) - 15.0
            next_state["pressure"] = float(next_state["pressure"]) - 0.2
        "vent":
            next_state["pressure"] = maxf(0.0, float(next_state["pressure"]) - 0.7)
            next_state["temperature"] = float(next_state["temperature"]) - 2.0
        "stir":
            pass

    var ph_value: float = float(next_state["ph"])
    var temperature_value: float = float(next_state["temperature"])
    var pressure_value: float = float(next_state["pressure"])
    if ph_value <= 0.5 or ph_value >= 13.5 or temperature_value <= -15.0 or temperature_value >= 160.0 or pressure_value <= 0.05 or pressure_value >= 5.5:
        next_state["status"] = "failed"
        next_state["stable_streak"] = 0
        next_state["progress"] = 0
        next_state["last_message"] = "Safety interlock: the batch exceeded its safe operating envelope."
        return {"ok": true, "state": next_state, "completed": false, "hazard": true}

    if action == "stir":
        if is_within_target(next_state):
            next_state["stable_streak"] = int(next_state["stable_streak"]) + 1
            next_state["progress"] = mini(100, int(next_state["stable_streak"]) * 25)
            next_state["score"] = int(next_state["score"]) + 25
            next_state["last_message"] = "Stable cycle %d / %d." % [int(next_state["stable_streak"]), STABLE_CYCLES_REQUIRED]
            if int(next_state["stable_streak"]) >= STABLE_CYCLES_REQUIRED:
                next_state["status"] = "complete"
                next_state["last_message"] = "Batch stabilized. Proceed to the next process."
        else:
            next_state["stable_streak"] = 0
            next_state["progress"] = 0
            next_state["last_message"] = "Do not stir yet: pH, temperature or pressure is outside tolerance."
    else:
        if not is_within_target(next_state):
            next_state["stable_streak"] = 0
            next_state["progress"] = 0
        next_state["last_message"] = "Process adjustment recorded. Check all three target windows."

    if str(next_state["status"]) == "active" and int(next_state["turn"]) >= int(next_state["max_turns"]):
        next_state["status"] = "failed"
        next_state["last_message"] = "Control window expired before the batch stabilized."
    return {"ok": true, "state": next_state, "completed": str(next_state["status"]) == "complete", "hazard": false}

func advance_scenario(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "complete":
        return {"ok": false, "reason": "scenario_not_complete", "state": state.duplicate(true)}
    var next_index: int = int(state.get("scenario_index", -1)) + 1
    if next_index >= SCENARIOS.size():
        var finished: Dictionary = state.duplicate(true)
        finished["status"] = "campaign_complete"
        finished["last_message"] = "All three reactor batches are stable."
        return {"ok": true, "complete": true, "state": finished}
    return {
        "ok": true,
        "complete": false,
        "state": create_state(next_index, int(state.get("score", 0)))
    }

func reset_scenario(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) == "complete" or str(state.get("status", "")) == "campaign_complete":
        return {"ok": false, "reason": "already_complete", "state": state.duplicate(true)}
    var index: int = int(state.get("scenario_index", -1))
    if index < 0 or index >= SCENARIOS.size():
        return {"ok": false, "reason": "invalid_scenario", "state": state.duplicate(true)}
    return {"ok": true, "state": create_state(index, int(state.get("score", 0)))}
