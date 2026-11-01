extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    _expect(game != null, "Microbe Scope main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_state"), "game exposes its specimen calibration state")
    _expect(game.has_method("get_parameter_control_count"), "game exposes four parameter control rows")
    _expect(game.has_method("get_action_button_count"), "game exposes capture/reset/next controls")
    if game.has_method("get_current_state"):
        var state: Dictionary = game.call("get_current_state")
        _expect(str(state.get("specimen_id", "")) == "diatom", "game starts the Diatom Valve specimen")
        _expect(game.call("get_parameter_control_count") == 4, "game builds four calibration control rows")
        _expect(game.call("get_action_button_count") == 3, "game builds three action buttons")
        _expect(bool(game.call("set_parameter_value", "focus", 52)), "runtime can adjust focus through the public control API")
        _expect(bool(game.call("set_parameter_value", "magnification", 3)), "runtime can adjust magnification through the public control API")
        _expect(bool(game.call("set_parameter_value", "illumination", 68)), "runtime can adjust illumination through the public control API")
        _expect(bool(game.call("set_parameter_value", "stain", 2)), "runtime can adjust stain through the public control API")
        game.call("_capture_sample")
        var captured: Dictionary = game.call("get_current_state")
        _expect(str(captured.get("status", "")) == "captured" and int(captured.get("score", 0)) == 100 and int(captured.get("captures", 0)) == 1, "runtime captures and credits a correctly calibrated specimen")
        game.call("_reset_specimen")
        var rolled_back: Dictionary = game.call("get_current_state")
        _expect(str(rolled_back.get("status", "")) == "active" and int(rolled_back.get("score", -1)) == 0 and int(rolled_back.get("captures", -1)) == 0, "runtime reset reverses the current specimen capture credit")
        _expect(game.call("set_parameter_value", "focus", 52), "runtime can recalibrate focus after reset")
        _expect(game.call("set_parameter_value", "magnification", 3), "runtime can recalibrate magnification after reset")
        _expect(game.call("set_parameter_value", "illumination", 68), "runtime can recalibrate illumination after reset")
        _expect(game.call("set_parameter_value", "stain", 2), "runtime can recalibrate stain after reset")
        game.call("_capture_sample")
        var recaptured: Dictionary = game.call("get_current_state")
        _expect(str(recaptured.get("status", "")) == "captured" and int(recaptured.get("score", 0)) == 100 and int(recaptured.get("captures", 0)) == 1, "runtime can recapture without duplicate campaign credit")
        game.call("_next_specimen")
        var next_state: Dictionary = game.call("get_current_state")
        _expect(str(next_state.get("specimen_id", "")) == "pollen", "runtime advances to the next specimen")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Microbe Scope runtime smoke test passed.")
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
