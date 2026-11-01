extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules = RulesScript.new()
    _expect(rules.site_count() == 3, "rules expose three authored trackway sites")
    _expect(rules.get_site_definition(-1).is_empty(), "invalid site index returns no definition")
    _expect(rules.infer_heading({"bearing_deg": 359.0}) == "N", "heading quantization wraps bearings near north")
    _expect(rules.infer_heading({"bearing_deg": 315.0}) == "NW", "heading quantization identifies northwest")
    _expect(rules.infer_gait({"foot_length_cm": 46.0, "stride_cm": 460.0}) == "run", "high stride-to-foot ratio identifies a running trackway")
    _expect(rules.infer_gait({"foot_length_cm": 68.0, "stride_cm": 408.0}) == "walk", "lower stride-to-foot ratio identifies a walking trackway")

    var first_state: Dictionary = rules.create_state(0, 40)
    var incomplete: Dictionary = rules.submit_survey(first_state)
    _expect(str(incomplete.get("reason", "")) == "incomplete_answer", "submission requires all three field conclusions")
    var invalid: Dictionary = rules.set_answer(first_state, "species", "pterodactyl")
    _expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "invalid_value", "unknown trackmaker option is rejected")
    invalid = rules.set_answer(first_state, "unknown", "walk")
    _expect(not bool(invalid.get("ok", true)) and str(invalid.get("reason", "")) == "invalid_field", "unknown answer field is rejected")

    var wrong_state: Dictionary = first_state
    wrong_state = rules.set_answer(wrong_state, "species", "sauropod")["state"]
    wrong_state = rules.set_answer(wrong_state, "gait", "walk")["state"]
    wrong_state = rules.set_answer(wrong_state, "heading", "E")["state"]
    var wrong_result: Dictionary = rules.submit_survey(wrong_state)
    _expect(str(wrong_result.get("state", {}).get("status", "")) == "failed", "incorrect trackmaker fails the current field report")
    var reset_result: Dictionary = rules.reset_survey(wrong_result["state"])
    _expect(bool(reset_result.get("ok", false)), "failed survey can be reset")
    _expect(int(reset_result.get("state", {}).get("score", -1)) == 40, "reset preserves score earned before the current site")
    _expect(str(reset_result.get("state", {}).get("status", "")) == "scanning", "reset returns the site to scanning")

    var campaign_score: int = 0
    var campaign_state: Dictionary = {}
    for index in range(rules.site_count()):
        var answer: Dictionary = rules.get_correct_answer(index)
        _expect(not answer.is_empty(), "site %d derives a complete classification from measurements" % index)
        _expect(str(answer.get("species", "")) == str(["small_ornithopod", "large_theropod", "sauropod"][index]), "site %d derives the expected trackmaker" % index)
        _expect(str(answer.get("gait", "")) == str(["walk", "run", "walk"][index]), "site %d derives the expected gait" % index)
        _expect(str(answer.get("heading", "")) == str(["E", "NW", "S"][index]), "site %d derives the expected heading" % index)
        var state: Dictionary = rules.create_state(index, campaign_score)
        for field in ["species", "gait", "heading"]:
            var update: Dictionary = rules.set_answer(state, field, str(answer[field]))
            _expect(bool(update.get("ok", false)), "site %d accepts the %s conclusion" % [index, field])
            state = update.get("state", {})
        var result: Dictionary = rules.submit_survey(state)
        _expect(bool(result.get("completed", false)), "site %d accepts its measured trackway classification" % index)
        campaign_state = result.get("state", {})
        campaign_score = int(campaign_state.get("score", 0))
        _expect(campaign_score == (index + 1) * 100, "site %d awards exactly 100 points" % index)
        var advance: Dictionary = rules.advance_survey(campaign_state)
        _expect(bool(advance.get("ok", false)), "site %d advances only after a correct report" % index)
        campaign_state = advance.get("state", {})
        if index < rules.site_count() - 1:
            _expect(str(campaign_state.get("site_id", "")) == str(["ridge_pass", "river_plain"][index]), "campaign advances to the next authored site")
    _expect(str(campaign_state.get("status", "")) == "campaign_complete", "third site ends the campaign")
    _expect(int(campaign_state.get("score", 0)) == 300, "campaign carries all three field report bonuses")
    var completed_reset: Dictionary = rules.reset_survey(campaign_state)
    _expect(not bool(completed_reset.get("ok", true)) and str(completed_reset.get("reason", "")) == "already_complete", "completed campaign cannot be reset for repeat score")

    if failures.is_empty():
        print("KROLL Paleo Track Lab rules tests passed.")
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
