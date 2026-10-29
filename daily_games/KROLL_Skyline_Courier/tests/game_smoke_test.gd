extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    assert(packed != null, "Main scene must load")
    var game: Control = packed.instantiate() as Control
    root.add_child(game)
    await process_frame
    assert(game.state["status"] == "playing" and game.state["lane"] == 1)
    assert(game._buttons.size() == 5, "Touch-friendly lane and route controls are present")

    var key_event := InputEventKey.new()
    key_event.keycode = KEY_LEFT
    key_event.pressed = true
    game._unhandled_key_input(key_event)
    assert(game.state["lane"] == 0, "Left arrow changes lane")
    game.select_lane(2)
    assert(game.state["lane"] == 2, "On-screen lane selector works")

    game.restart_game()
    var before_distance: float = float(game.state["distance"])
    game._process(0.1)
    assert(float(game.state["distance"]) > before_distance, "Runtime frame advances the route")

    game.queue_free()
    await process_frame
    print("KROLL Skyline Courier runtime smoke test passed.")
    quit(0)
