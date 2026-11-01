extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules: RefCounted = RulesScript.new()
    _expect(int(rules.call("survey_count")) == 3, "three mineral surveys are available")
    var campaign_state: Dictionary = rules.call("create_state", 0)
    var expected_targets: Array[Vector2i] = [Vector2i(2, 4), Vector2i(5, 1), Vector2i(3, 3)]
    for index in range(3):
        var state: Dictionary = campaign_state
        var definition: Dictionary = rules.call("get_survey_definition", index)
        _expect(str(state.get("survey_id", "")) == str(definition.get("id", "")), "survey %d creates the correct hidden deposit" % index)
        var invalid_probe: Dictionary = rules.call("activate_probe", state, "CENTER")
        _expect(not bool(invalid_probe.get("ok", true)), "unknown probe is rejected")
        var premature_submit: Dictionary = rules.call("submit_guess", state)
        _expect(not bool(premature_submit.get("ok", true)), "guess is rejected before all probes are fired")
        var previous_count: int = 49
        var first_probe: Dictionary = rules.call("activate_probe", state, "NW")
        _expect(bool(first_probe.get("ok", false)), "survey %d accepts the first NW probe" % index)
        state = first_probe["state"]
        var duplicate_probe: Dictionary = rules.call("activate_probe", state, "NW")
        _expect(not bool(duplicate_probe.get("ok", true)) and str(duplicate_probe.get("reason", "")) == "probe_already_used", "survey %d rejects duplicate probe activation" % index)
        var first_candidates: Array[Vector2i] = rules.call("get_candidate_cells", state)
        _expect(first_candidates.size() < previous_count, "survey %d first probe narrows the candidate set" % index)
        previous_count = first_candidates.size()
        for probe_id in ["NE", "SW"]:
            var result: Dictionary = rules.call("activate_probe", state, probe_id)
            _expect(bool(result.get("ok", false)), "survey %d accepts probe %s" % [index, probe_id])
            state = result["state"]
            var candidates: Array[Vector2i] = rules.call("get_candidate_cells", state)
            _expect(candidates.size() <= previous_count, "survey %d probe %s never expands candidate set" % [index, probe_id])
            previous_count = candidates.size()
        var final_candidates: Array[Vector2i] = rules.call("get_candidate_cells", state)
        _expect(str(state.get("status", "")) == "locate" and final_candidates.size() == 1, "survey %d triangulates to exactly one cell" % index)
        _expect(final_candidates[0] == expected_targets[index], "survey %d identifies the authored deposit coordinate" % index)
        var selected: Dictionary = rules.call("select_cell", state, final_candidates[0])
        _expect(bool(selected.get("ok", false)), "survey %d allows selecting the unique candidate" % index)
        state = selected["state"]
        var confirmed: Dictionary = rules.call("submit_guess", state)
        _expect(bool(confirmed.get("ok", false)) and str(confirmed["state"].get("status", "")) == "complete", "survey %d confirms the deposit" % index)
        state = confirmed["state"]
        _expect(int(state.get("score", 0)) == (index + 1) * 100, "survey %d awards one 100-point mapping bonus" % index)
        var advanced: Dictionary = rules.call("advance_survey", state)
        _expect(bool(advanced.get("ok", false)), "survey %d advances after confirmation" % index)
        if index < 2:
            campaign_state = advanced["state"]
            _expect(int(campaign_state.get("score", 0)) == (index + 1) * 100, "survey %d carries mapping credit forward" % index)
        else:
            _expect(bool(advanced.get("complete", false)) and str(advanced["state"].get("status", "")) == "campaign_complete", "third survey completes the campaign")

    var partial: Dictionary = rules.call("create_state", 0, 100)
    var first_pulse: Dictionary = rules.call("activate_probe", partial, "NW")
    partial = first_pulse["state"]
    var reset: Dictionary = rules.call("reset_survey", partial)
    _expect(bool(reset.get("ok", false)) and (reset["state"]["readings"] as Dictionary).is_empty(), "reset clears partial probe readings")
    _expect(int(reset["state"].get("score", -1)) == 100, "reset preserves credit from earlier completed surveys")
    var wrong_state: Dictionary = rules.call("create_state", 0)
    wrong_state["status"] = "locate"
    wrong_state["selected_cell"] = Vector2i(1, 1)
    var wrong_guess: Dictionary = rules.call("submit_guess", wrong_state)
    _expect(str(wrong_guess["state"].get("status", "")) == "failed", "incorrect coordinate closes the survey")

    if failures.is_empty():
        print("KROLL Faultline Cartographer rules tests passed.")
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
