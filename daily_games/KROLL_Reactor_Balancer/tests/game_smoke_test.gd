extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    _expect(game != null, "Reactor Balancer main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_state"), "game exposes its process state")
    _expect(game.has_method("get_action_button_count"), "game exposes six process controls")
    _expect(game.get_title_text() == "KROLL // REACTOR BALANCER", "game displays the correct title")
    _expect(game.get_action_button_count() == 6, "game builds six action buttons")
    if game.has_method("get_current_state"):
        var state: Dictionary = game.call("get_current_state")
        _expect(str(state.get("scenario_id", "")) == "polymer_batch", "game starts Polymer Batch")
        for action in ["base", "base", "heat", "heat", "stir", "stir", "stir", "stir"]:
            _expect(bool(game.call("perform_action", action)), "runtime accepts action %s" % action)
        var completed: Dictionary = game.call("get_current_state")
        _expect(str(completed.get("status", "")) == "complete" and int(completed.get("score", 0)) == 100, "runtime stabilizes the first batch and credits its score")
        game.call("_advance_scenario")
        var next_state: Dictionary = game.call("get_current_state")
        _expect(str(next_state.get("scenario_id", "")) == "cryo_solvent", "runtime advances to Cryo Solvent")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Reactor Balancer runtime smoke test passed.")
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
