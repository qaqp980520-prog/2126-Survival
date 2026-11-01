extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    _expect(game != null, "Fossil Assembly main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_state"), "game exposes its deterministic specimen state")
    _expect(game.has_method("get_piece_button_count"), "game exposes its fragment controls")
    _expect(game.has_method("get_board_cell_count"), "game exposes its reconstruction grid")
    if game.has_method("get_current_state"):
        var state: Dictionary = game.call("get_current_state")
        _expect(str(state.get("level_id", "")) == "triceratops_skull", "game starts the Triceratops Skull specimen")
        _expect(game.call("get_piece_button_count") == 3, "game builds three fragment controls")
        _expect(game.call("get_board_cell_count") == 25, "game builds a five-by-five reconstruction grid")
        _expect(game.call("get_title_text") == "KROLL // FOSSIL ASSEMBLY LAB", "game shows the correct title")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Fossil Assembly runtime smoke test passed.")
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
