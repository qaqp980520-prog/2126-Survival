extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    _expect(game != null, "Paleo Track Lab main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.call("get_title_text") == "KROLL // PALEO TRACK LAB", "game displays the correct title")
    _expect(game.call("get_answer_button_count") == 13, "game builds thirteen species, gait and heading controls")
    _expect(str(game.call("get_current_state").get("site_id", "")) == "fern_basin", "game starts at Fern Basin")
    _expect(game.call("get_metrics_text").contains("FOOT LENGTH"), "game displays measurable trackway evidence")

    _expect(bool(game.call("select_answer", "species", "sauropod")), "game accepts a trackmaker selection")
    _expect(bool(game.call("select_answer", "gait", "walk")), "game accepts a gait selection")
    _expect(bool(game.call("select_answer", "heading", "E")), "game accepts a heading selection")
    _expect(bool(game.call("submit_survey")), "game submits a complete field report")
    _expect(str(game.call("get_current_state").get("status", "")) == "failed", "incorrect field report fails the site")
    _expect(bool(game.call("reset_survey")), "game can reset a failed site")

    _expect(bool(game.call("select_answer", "species", "small_ornithopod")), "retry selects the measured small ornithopod")
    _expect(bool(game.call("select_answer", "gait", "walk")), "retry selects the measured walking gait")
    _expect(bool(game.call("select_answer", "heading", "E")), "retry selects the measured eastward heading")
    _expect(bool(game.call("submit_survey")), "game accepts the correct field report")
    _expect(str(game.call("get_current_state").get("status", "")) == "complete", "correct report completes Fern Basin")
    _expect(bool(game.call("advance_survey")), "game advances to the next site")
    _expect(str(game.call("get_current_state").get("site_id", "")) == "ridge_pass", "game opens Ridge Pass after Fern Basin")

    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Paleo Track Lab runtime smoke test passed.")
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
