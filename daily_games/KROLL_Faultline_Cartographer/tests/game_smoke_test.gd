extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    _expect(game != null, "Faultline Cartographer main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_state"), "game exposes its survey state")
    _expect(game.call("get_title_text") == "KROLL // FAULTLINE CARTOGRAPHER", "game displays the correct title")
    _expect(game.call("get_probe_button_count") == 3, "game builds three seismic probe controls")
    _expect(game.call("get_grid_button_count") == 49, "game builds a 7x7 survey grid")
    if game.has_method("get_current_state"):
        _expect(int(game.call("get_grid_button_disabled_count")) == 49, "runtime keeps grid guesses disabled until all probes are fired")
        _expect(str(game.call("get_rule_hint_text")).contains("rounded Euclidean"), "runtime explains the probe distance rule")
        for probe_id in ["NW", "NE", "SW"]:
            _expect(bool(game.call("perform_probe", probe_id)), "runtime accepts probe %s" % probe_id)
        var state: Dictionary = game.call("get_current_state")
        var candidates: Array[Vector2i] = state.get("candidate_cells", [])
        _expect(candidates.size() == 1, "runtime triangulates to one possible deposit")
        _expect(int(game.call("get_grid_button_disabled_count")) == 0, "runtime allows guesses across all 49 cells after triangulation")
        if candidates.size() == 1:
            _expect(str(game.call("get_grid_button_text_at", candidates[0])) == ".", "runtime does not reveal the hidden deposit cell")
            var wrong_cell := Vector2i(0, 0)
            _expect(bool(game.call("select_cell", wrong_cell)), "runtime accepts a deliberate wrong coordinate guess")
            _expect(bool(game.call("submit_guess")), "runtime submits the wrong coordinate")
            var failed: Dictionary = game.call("get_current_state")
            _expect(str(failed.get("status", "")) == "failed", "runtime marks an incorrect coordinate as failed")
            game.call("_reset_survey")
            for probe_id in ["NW", "NE", "SW"]:
                _expect(bool(game.call("perform_probe", probe_id)), "runtime allows retry probe %s" % probe_id)
            state = game.call("get_current_state")
            candidates = state.get("candidate_cells", [])
            if candidates.size() == 1:
                _expect(bool(game.call("select_cell", candidates[0])), "runtime allows the inferred deposit coordinate to be selected")
                _expect(bool(game.call("submit_guess")), "runtime accepts the correct coordinate")
                var completed: Dictionary = game.call("get_current_state")
                _expect(str(completed.get("status", "")) == "complete" and int(completed.get("score", 0)) == 100, "runtime completes the Iron Vein survey after a correct guess")
                game.call("_advance_survey")
                var next_state: Dictionary = game.call("get_current_state")
                _expect(str(next_state.get("survey_id", "")) == "quartz_seam", "runtime advances to Quartz Seam")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Faultline Cartographer runtime smoke test passed.")
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
