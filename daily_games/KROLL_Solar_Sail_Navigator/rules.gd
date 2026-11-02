extends RefCounted

const MISSIONS: Array[Dictionary] = [
    {"id":"solar_wake","name":"SOLAR WAKE","brief":"Trim the sail to bend light pressure toward the relay.","target":Vector2(68.0,42.0),"target_radius":8.5,"max_turns":22,"max_speed":5.5,"gust_strength":0.0,"hazards":[]},
    {"id":"lagrange_drift","name":"LAGRANGE DRIFT","brief":"A weak solar gust changes pressure each turn. Coast before arrival.","target":Vector2(74.0,28.0),"target_radius":8.5,"max_turns":26,"max_speed":5.5,"gust_strength":0.12,"hazards":[{"position":Vector2(44.0,45.0),"radius":7.0}]},
    {"id":"dust_ribbon","name":"DUST RIBBON","brief":"Thread the debris corridor, then reduce drift inside the relay radius.","target":Vector2(82.0,62.0),"target_radius":10.0,"max_turns":30,"max_speed":5.8,"gust_strength":0.18,"hazards":[{"position":Vector2(43.0,48.0),"radius":7.0},{"position":Vector2(63.0,48.0),"radius":8.0},{"position":Vector2(72.0,40.0),"radius":7.0}]}
]

func get_mission_count() -> int:
    return MISSIONS.size()

func get_mission(index: int) -> Dictionary:
    if index < 0 or index >= MISSIONS.size():
        return {}
    return MISSIONS[index].duplicate(true)

func initial_state() -> Dictionary:
    return {"position":Vector2(10.0,50.0),"velocity":Vector2.ZERO,"turn":0,"status":"flight","reason":""}

func step(index: int, state: Dictionary, trim: int, deployment: int) -> Dictionary:
    var mission: Dictionary = get_mission(index)
    if mission.is_empty():
        return {"accepted":false,"reason":"invalid_mission"}
    if trim < -3 or trim > 3 or deployment < 0 or deployment > 3:
        return {"accepted":false,"reason":"invalid_controls"}
    if str(state.get("status","flight")) != "flight":
        return {"accepted":false,"reason":"terminal_state"}
    var position_value: Variant = state.get("position",null)
    var velocity_value: Variant = state.get("velocity",null)
    if not (position_value is Vector2) or not (velocity_value is Vector2):
        return {"accepted":false,"reason":"invalid_state"}
    var old_position: Vector2 = position_value
    var old_velocity: Vector2 = velocity_value
    if not _finite_vector(old_position) or not _finite_vector(old_velocity):
        return {"accepted":false,"reason":"invalid_state"}
    var old_turn: int = int(state.get("turn",-1))
    if old_turn < 0:
        return {"accepted":false,"reason":"invalid_state"}

    var next_turn: int = old_turn + 1
    var angle: float = deg_to_rad(float(trim) * 10.0)
    var gust: float = 1.0 + float(mission["gust_strength"]) * sin(float(next_turn + 1) * 0.73)
    var cosine: float = cos(angle)
    var force: float = 0.82 * (float(deployment) / 3.0) * cosine * cosine * gust
    var acceleration := Vector2(cosine,-sin(angle)) * force
    var velocity: Vector2 = (old_velocity + acceleration) * 0.82
    var position: Vector2 = old_position + velocity
    var status: String = "flight"
    var reason: String = ""
    var distance: float = position.distance_to(mission["target"])

    for hazard_value in mission["hazards"]:
        var hazard: Dictionary = hazard_value
        var hazard_position: Vector2 = hazard["position"]
        if position.distance_to(hazard_position) <= float(hazard["radius"]):
            status = "collision"
            reason = "debris_collision"
            break
    if status == "flight" and distance <= float(mission["target_radius"]) and velocity.length() <= float(mission["max_speed"]):
        status = "success"
        reason = "relay_captured"
    if status == "flight" and (position.x < 0.0 or position.x > 100.0 or position.y < 0.0 or position.y > 100.0):
        status = "out_of_bounds"
        reason = "flight_path_lost"
    if status == "flight" and next_turn >= int(mission["max_turns"]):
        status = "timeout"
        reason = "turn_limit_reached"

    var next_state := {"position":position,"velocity":velocity,"turn":next_turn,"status":status,"reason":reason}
    return {"accepted":true,"state":next_state,"status":status,"reason":reason,"distance_to_target":distance}

func _finite_vector(value: Vector2) -> bool:
    return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y)
