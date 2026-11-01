extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules: RefCounted = RulesScript.new()
    _expect(int(rules.call("scenario_count")) == 3, "three reactor batches are available")
    var solutions: Array[Array] = [
        ["base", "base", "heat", "heat", "stir", "stir", "stir", "stir"],
        ["acid", "acid", "cool", "cool", "cool", "stir", "stir", "stir", "stir"],
        ["base", "base", "heat", "heat", "heat", "stir", "stir", "stir", "stir"]
    ]
    for index in range(3):
        var state: Dictionary = rules.call("create_state", index)
        var definition: Dictionary = rules.call("get_scenario_definition", index)
        _expect(not state.is_empty() and str(state.get("scenario_id", "")) == str(definition.get("id", "")), "scenario %d creates a matching process state" % index)
        for action in solutions[index]:
            var result: Dictionary = rules.call("apply_action", state, action)
            _expect(bool(result.get("ok", false)), "scenario %d accepts action %s" % [index, action])
            state = result["state"]
        _expect(str(state.get("status", "")) == "complete", "scenario %d reaches a stable four-cycle completion" % index)
        _expect(int(state.get("progress", 0)) == 100, "scenario %d reaches 100 percent stabilization" % index)
        _expect(int(state.get("score", 0)) == 100, "scenario %d earns exactly 100 points" % index)
        var advanced: Dictionary = rules.call("advance_scenario", state)
        _expect(bool(advanced.get("ok", false)), "scenario %d can advance after stabilization" % index)
        if index < 2:
            _expect(str(advanced["state"].get("scenario_id", "")) != str(state.get("scenario_id", "")), "scenario %d advances to a new batch" % index)
        else:
            _expect(bool(advanced.get("complete", false)) and str(advanced["state"].get("status", "")) == "campaign_complete", "third batch completes the campaign")

    var state: Dictionary = rules.call("create_state", 0, 50)
    var invalid: Dictionary = rules.call("apply_action", state, "unknown")
    _expect(not bool(invalid.get("ok", true)) and int(invalid["state"]["turn"]) == 0, "unknown action is rejected without mutating the process")
    var unsafe_state: Dictionary = rules.call("create_state", 0)
    unsafe_state["ph"] = 1.0
    var unsafe: Dictionary = rules.call("apply_action", unsafe_state, "acid")
    _expect(bool(unsafe.get("ok", false)) and str(unsafe["state"].get("status", "")) == "failed", "unsafe pH triggers the safety interlock")
    var exhausted_state: Dictionary = rules.call("create_state", 0)
    exhausted_state["turn"] = 11
    var exhausted: Dictionary = rules.call("apply_action", exhausted_state, "vent")
    _expect(bool(exhausted.get("ok", false)) and str(exhausted["state"].get("status", "")) == "failed", "last action without stabilization expires the control window")
    var out_of_window: Dictionary = rules.call("create_state", 0)
    var wrong_stir: Dictionary = rules.call("apply_action", out_of_window, "stir")
    _expect(int(wrong_stir["state"].get("stable_streak", -1)) == 0 and int(wrong_stir["state"].get("progress", -1)) == 0, "stirring outside target windows cannot advance stabilization")
    var reset: Dictionary = rules.call("reset_scenario", unsafe["state"])
    _expect(bool(reset.get("ok", false)) and float(reset["state"].get("ph", -1.0)) == 4.0 and int(reset["state"].get("score", -1)) == 0, "reset restores initial process conditions without altering campaign credit")
    var completed: Dictionary = rules.call("create_state", 0)
    completed["status"] = "complete"
    var blocked_reset: Dictionary = rules.call("reset_scenario", completed)
    _expect(not bool(blocked_reset.get("ok", true)), "completed batch cannot be reset to farm score")

    if failures.is_empty():
        print("KROLL Reactor Balancer rules tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
