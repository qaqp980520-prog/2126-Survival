extends SceneTree
const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_invalid_inputs_and_resource_guards()
    _test_three_mission_campaign()
    _test_failure_boundaries()
    if failures.is_empty():
        print("KROLL Stratosphere Balloonist rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_invalid_inputs_and_resource_guards() -> void:
    var rules := RulesScript.new()
    _expect(rules.create_state(-1).is_empty(), "negative mission index is rejected")
    _expect(rules.create_state(3).is_empty(), "out-of-range mission index is rejected")
    var state: Dictionary = rules.create_state(0)
    var invalid_action: Dictionary = rules.apply_action(state, "teleport")
    _expect(not bool(invalid_action.get("ok", false)) and str(invalid_action.get("reason", "")) == "invalid_action", "unknown flight commands are rejected")
    _expect(float(state.get("altitude", -1.0)) == 0.0, "rejected commands do not mutate the source state")
    var no_ballast: Dictionary = state.duplicate(true)
    no_ballast["ballast"] = 0
    var ballast_result: Dictionary = rules.apply_action(no_ballast, "ascend")
    _expect(not bool(ballast_result.get("ok", false)) and str(ballast_result.get("reason", "")) == "ballast_empty", "ascent is blocked when ballast reserve is empty")
    _expect(int(no_ballast.get("ticks", -1)) == 0, "resource rejection does not advance the flight clock")
    var no_gas: Dictionary = state.duplicate(true)
    no_gas["gas_integrity"] = 1
    var gas_result: Dictionary = rules.apply_action(no_gas, "descend")
    _expect(not bool(gas_result.get("ok", false)) and str(gas_result.get("reason", "")) == "gas_empty", "descent is blocked when the envelope reserve is too low")

func _test_three_mission_campaign() -> void:
    var rules := RulesScript.new()
    var state: Dictionary = rules.create_state(0)
    var expected_ticks: Array[int] = [5, 10, 15]
    for mission_index in range(rules.get_mission_count()):
        _expect(int(state.get("mission_index", -1)) == mission_index, "campaign enters mission %d" % (mission_index + 1))
        for step in range(expected_ticks[mission_index]):
            var climb: Dictionary = rules.apply_action(state, "ascend")
            _expect(bool(climb.get("ok", false)), "mission %d accepts planned ascent %d" % [mission_index + 1, step + 1])
            if not bool(climb.get("ok", false)):
                return
            state = climb["state"]
        for sample_tick in range(rules.get_sample_requirement()):
            var hold: Dictionary = rules.apply_action(state, "hold")
            _expect(bool(hold.get("ok", false)), "mission %d accepts stable sample hold %d" % [mission_index + 1, sample_tick + 1])
            if not bool(hold.get("ok", false)):
                return
            state = hold["state"]
        _expect(str(state.get("status", "")) == "passed", "mission %d reaches a stable sample window" % (mission_index + 1))
        _expect(int(state.get("mission_score", 0)) > 0, "mission %d awards a positive score" % (mission_index + 1))
        var repeated: Dictionary = rules.apply_action(state, "hold")
        _expect(not bool(repeated.get("ok", false)) and str(repeated.get("reason", "")) == "mission_not_active", "passed mission %d cannot be scored twice" % (mission_index + 1))
        var advance: Dictionary = rules.advance_mission(state)
        _expect(bool(advance.get("ok", false)), "mission %d advances only after passing" % (mission_index + 1))
        if not bool(advance.get("ok", false)):
            return
        state = advance["state"]
    _expect(str(state.get("status", "")) == "campaign_complete", "third mission closes the campaign")
    _expect(int(state.get("campaign_score", 0)) > 0, "campaign retains all mission scores")
    var restarted: Dictionary = rules.restart_campaign()
    _expect(bool(restarted.get("ok", false)), "campaign restart succeeds")
    if bool(restarted.get("ok", false)):
        _expect(int(restarted["state"].get("mission_index", -1)) == 0, "restart returns to Cloud Deck")
        _expect(int(restarted["state"].get("campaign_score", -1)) == 0, "restart clears the campaign score")

func _test_failure_boundaries() -> void:
    var rules := RulesScript.new()
    var below_ground: Dictionary = rules.create_state(0)
    var descent: Dictionary = rules.apply_action(below_ground, "descend")
    _expect(bool(descent.get("ok", false)) and str(descent["state"].get("status", "")) == "failed", "descending below ground ends the flight")
    var ceiling_state: Dictionary = rules.create_state(0)
    ceiling_state["altitude"] = 5.4
    var ceiling_result: Dictionary = rules.apply_action(ceiling_state, "ascend")
    _expect(bool(ceiling_result.get("ok", false)) and str(ceiling_result["state"].get("status", "")) == "failed", "crossing the envelope ceiling ends the flight")

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
