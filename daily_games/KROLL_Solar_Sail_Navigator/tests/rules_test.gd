extends SceneTree

const RulesScript = preload("res://rules.gd")
const PlansScript = preload("res://tests/flight_plans.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules: RefCounted = RulesScript.new()
    _expect(rules.get_mission_count() == 3,"three solar relay missions")
    for mission_index in range(rules.get_mission_count()):
        var state: Dictionary = rules.initial_state()
        _expect(state.get("position",Vector2.ZERO) == Vector2(10.0,50.0),"mission %d starts at launch coordinate" % mission_index)
        for action_value in PlansScript.PLANS[mission_index]:
            var action: Vector2i = action_value
            var result: Dictionary = rules.step(mission_index,state,action.x,action.y)
            _expect(bool(result.get("accepted",false)),"mission %d accepts valid sail command" % mission_index)
            if not bool(result.get("accepted",false)):
                break
            state = result["state"]
            if str(state.get("status","")) != "flight":
                break
        _expect(str(state.get("status","")) == "success","mission %d deterministic plan captures relay" % mission_index)
        _expect(not bool(rules.step(mission_index,state,0,0).get("accepted",true)),"terminal flight rejects more commands")

    var initial: Dictionary = rules.initial_state()
    _expect(not bool(rules.step(0,initial,4,3).get("accepted",true)),"invalid trim is rejected")
    _expect(not bool(rules.step(0,initial,0,4).get("accepted",true)),"invalid deployment is rejected")
    _expect(not bool(rules.step(99,initial,0,3).get("accepted",true)),"invalid mission is rejected")
    var coast_state: Dictionary = rules.initial_state()
    coast_state["velocity"] = Vector2(2.0,0.0)
    var coast: Dictionary = rules.step(0,coast_state,0,0)
    var coast_velocity: Vector2 = coast["state"]["velocity"]
    _expect(is_equal_approx(coast_velocity.x,1.64),"coasting applies inertial damping")
    var trim_result: Dictionary = rules.step(0,initial,2,3)
    var trim_velocity: Vector2 = trim_result["state"]["velocity"]
    _expect(trim_velocity.y < 0.0,"positive trim steers north")
    var low: Dictionary = rules.step(0,initial,0,1)
    var high: Dictionary = rules.step(0,initial,0,3)
    _expect(Vector2(high["state"]["velocity"]).x > Vector2(low["state"]["velocity"]).x,"deployment increases light pressure")
    var collision_state: Dictionary = rules.initial_state()
    collision_state["position"] = Vector2(43.0,48.0)
    _expect(str(rules.step(2,collision_state,0,0).get("status","")) == "collision","debris contact ends flight")
    var timeout_state: Dictionary = rules.initial_state()
    timeout_state["turn"] = 29
    _expect(str(rules.step(2,timeout_state,0,0).get("status","")) == "timeout","mission turn limit is enforced")
    var invalid_state: Dictionary = rules.initial_state()
    invalid_state["position"] = Vector2(NAN,10.0)
    _expect(not bool(rules.step(0,invalid_state,0,3).get("accepted",true)),"non-finite position is rejected")

    if failures.is_empty():
        print("KROLL Solar Sail Navigator rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect(condition: bool,message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures.append(message)
