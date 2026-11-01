extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules: RefCounted = RulesScript.new() as RefCounted
    _expect(int(rules.call("specimen_count")) == 3, "three specimen calibration profiles are available")
    for index in range(3):
        var state: Dictionary = rules.call("create_state", index)
        var definition: Dictionary = rules.call("get_specimen_definition", index)
        _expect(not state.is_empty() and str(state.get("specimen_id", "")) == str(definition.get("id", "")), "specimen %d creates a matching state" % index)
        state["focus"] = int(definition["focus"])
        state["magnification"] = int(definition["magnification"])
        state["illumination"] = int(definition["illumination"])
        state["stain"] = int(definition["stain"])
        var evaluation: Dictionary = rules.call("evaluate", state)
        _expect(bool(evaluation.get("success", false)) and int(evaluation.get("clarity", 0)) == 100, "specimen %d exact calibration yields 100%% clarity" % index)
        var capture: Dictionary = rules.call("capture", state)
        _expect(bool(capture.get("captured", false)), "specimen %d exact calibration captures successfully" % index)
        state = capture["state"]
        var next: Dictionary = rules.call("next_specimen", state)
        _expect(bool(next.get("ok", false)), "specimen %d can advance after capture" % index)
        if index < 2:
            _expect(str(next["state"].get("specimen_id", "")) != str(state.get("specimen_id", "")), "specimen %d advances to a different specimen" % index)
        else:
            _expect(bool(next.get("complete", false)) and str(next["state"].get("status", "")) == "complete", "last specimen completes the campaign")

    var state: Dictionary = rules.call("create_state", 0)
    var invalid: Dictionary = rules.call("set_parameter", state, "unknown", 10)
    _expect(not bool(invalid.get("ok", true)) and state["focus"] == 50, "unknown parameter is rejected without mutation")
    var clamped: Dictionary = rules.call("set_parameter", state, "focus", 999)
    _expect(bool(clamped.get("ok", false)) and int(clamped["state"]["focus"]) == 100, "focus value clamps to the instrument range")
    var magnification: Dictionary = rules.call("set_parameter", state, "magnification", -2)
    _expect(int(magnification["state"]["magnification"]) == 1, "magnification clamps to its minimum")
    var wrong_capture: Dictionary = rules.call("capture", state)
    _expect(bool(wrong_capture.get("ok", false)) and not bool(wrong_capture.get("captured", true)), "incorrect calibration consumes one capture attempt")
    _expect(int(wrong_capture["state"]["attempts_left"]) == 4 and wrong_capture["evaluation"]["errors"].size() > 0, "miss reports calibration errors and remaining attempts")
    state = wrong_capture["state"]
    for _attempt in range(4):
        wrong_capture = rules.call("capture", state)
        state = wrong_capture["state"]
    _expect(str(state.get("status", "")) == "failed" and int(state["attempts_left"]) == 0, "five failed captures lock the specimen")
    var locked_adjustment: Dictionary = rules.call("adjust_parameter", state, "focus", 2)
    _expect(not bool(locked_adjustment.get("ok", true)), "failed specimen cannot be adjusted")
    var reset: Dictionary = rules.call("reset_specimen", state)
    _expect(str(reset.get("status", "")) == "active" and int(reset["attempts_left"]) == 5 and int(reset["focus"]) == 50, "reset restores the current specimen calibration state")
    var invalid_index: Dictionary = rules.call("create_state", 99)
    _expect(invalid_index.is_empty(), "unknown specimen index is rejected")

    if failures.is_empty():
        print("KROLL Microbe Scope rules tests passed.")
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
