extends RefCounted
class_name StratosphereBalloonistRules

const SAMPLE_TICKS: int = 3
const ACTIONS: Array[String] = ["ascend", "hold", "descend"]
const MISSIONS: Array[Dictionary] = [
    {"id":"cloud_deck","title":"CLOUD DECK","briefing":"Climb through the lower cloud layer and hold a stable altitude long enough to capture a clean air sample.","target_altitude":4.0,"altitude_band":0.45,"max_ticks":32,"initial_ballast":12,"wind":[0.0,0.04,-0.04,0.02,-0.02]},
    {"id":"jet_stream","title":"JET STREAM","briefing":"Cross alternating crosswinds. Use short corrections instead of wasting ballast on every gust.","target_altitude":8.0,"altitude_band":0.45,"max_ticks":42,"initial_ballast":18,"wind":[0.06,-0.06,0.0,0.08,-0.08]},
    {"id":"ozone_window","title":"OZONE WINDOW","briefing":"Reach the upper sampling band and keep the envelope inside its safe operating ceiling.","target_altitude":12.0,"altitude_band":0.45,"max_ticks":52,"initial_ballast":24,"wind":[-0.08,0.08,0.04,-0.04,0.0]}
]

func create_state(mission_index: int = 0, campaign_score: int = 0) -> Dictionary:
    if mission_index < 0 or mission_index >= MISSIONS.size() or campaign_score < 0:
        return {}
    var mission: Dictionary = MISSIONS[mission_index]
    return {"mission_index":mission_index,"altitude":0.0,"last_delta":0.0,"ballast":int(mission["initial_ballast"]),"gas_integrity":100,"ticks":0,"sample_progress":0,"mission_score":0,"campaign_score":campaign_score,"status":"playing"}

func get_mission_count() -> int:
    return MISSIONS.size()

func get_sample_requirement() -> int:
    return SAMPLE_TICKS

func get_mission_definition(mission_index: int) -> Dictionary:
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {}
    var definition: Dictionary = MISSIONS[mission_index].duplicate(true)
    definition.erase("wind")
    return definition

func get_current_wind_bias(state: Dictionary) -> float:
    var mission_index: int = int(state.get("mission_index", -1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return 0.0
    var pattern: Array = MISSIONS[mission_index]["wind"]
    if pattern.is_empty():
        return 0.0
    var tick: int = maxi(0, int(state.get("ticks", 0)))
    return float(pattern[tick % pattern.size()])

func apply_action(state: Dictionary, action: String) -> Dictionary:
    var mission_index: int = int(state.get("mission_index", -1))
    if mission_index < 0 or mission_index >= MISSIONS.size():
        return {"ok":false,"reason":"invalid_mission"}
    if str(state.get("status", "")) != "playing":
        return {"ok":false,"reason":"mission_not_active"}
    if not ACTIONS.has(action):
        return {"ok":false,"reason":"invalid_action"}
    var mission: Dictionary = MISSIONS[mission_index]
    var next_state: Dictionary = state.duplicate(true)
    var tick: int = int(next_state.get("ticks", 0))
    var wind: float = get_current_wind_bias(next_state)
    var delta: float = wind
    match action:
        "ascend":
            var ballast: int = int(next_state.get("ballast", 0))
            if ballast <= 0:
                return {"ok":false,"reason":"ballast_empty"}
            next_state["ballast"] = ballast - 1
            delta = 0.8 + wind * 0.25
        "descend":
            var gas: int = int(next_state.get("gas_integrity", 0))
            if gas < 2:
                return {"ok":false,"reason":"gas_empty"}
            next_state["gas_integrity"] = gas - 2
            delta = -0.8 + wind * 0.25
        "hold":
            delta = wind
    var altitude: float = float(next_state.get("altitude", 0.0)) + delta
    var next_tick: int = tick + 1
    next_state["altitude"] = altitude
    next_state["last_delta"] = delta
    next_state["ticks"] = next_tick
    var target: float = float(mission["target_altitude"])
    var band: float = float(mission["altitude_band"])
    var progress: int = int(next_state.get("sample_progress", 0))
    if absf(altitude - target) <= band and absf(delta) <= 0.25:
        progress += 1
    else:
        progress = 0
    next_state["sample_progress"] = progress
    if progress >= SAMPLE_TICKS:
        var gas_spent: int = 100 - int(next_state.get("gas_integrity", 100))
        var score: int = maxi(25, 100 - next_tick * 2 - int(float(gas_spent) * 0.25))
        next_state["status"] = "passed"
        next_state["mission_score"] = score
        next_state["campaign_score"] = int(next_state.get("campaign_score", 0)) + score
    elif altitude < 0.0 or altitude > target + 1.5 or int(next_state.get("gas_integrity", 0)) <= 0 or next_tick >= int(mission["max_ticks"]):
        next_state["status"] = "failed"
    return {"ok":true,"state":next_state,"delta":delta,"wind":wind}

func advance_mission(state: Dictionary) -> Dictionary:
    if str(state.get("status", "")) != "passed":
        return {"ok":false,"reason":"mission_not_passed"}
    var current_index: int = int(state.get("mission_index", -1))
    if current_index < 0 or current_index >= MISSIONS.size():
        return {"ok":false,"reason":"invalid_mission"}
    var campaign_score: int = int(state.get("campaign_score", 0))
    if current_index + 1 >= MISSIONS.size():
        var completed: Dictionary = state.duplicate(true)
        completed["status"] = "campaign_complete"
        return {"ok":true,"state":completed}
    return {"ok":true,"state":create_state(current_index + 1, campaign_score)}

func restart_campaign() -> Dictionary:
    return {"ok":true,"state":create_state(0, 0)}
