extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node2D = MainScene.instantiate() as Node2D
    _expect(game != null, "Molecule Forge main scene instantiates")
    if game == null:
        quit(1)
        return
    root.add_child(game)
    await process_frame
    _expect(game.has_method("get_current_level") and game.has_method("get_state"), "scene exposes level and board state")
    _expect(str(game.call("get_current_level").get("id", "")) == "water", "first challenge is water")
    _expect(not bool(game.call("next_level")), "campaign cannot advance before a molecule is verified")

    var touch_select := InputEventScreenTouch.new()
    touch_select.pressed = true
    var oxygen_button: Rect2 = game.call("_element_button_rect", "O")
    touch_select.position = oxygen_button.get_center()
    game.call("_unhandled_input", touch_select)
    _expect(str(game.get("selected_element")) == "O", "touch palette selects oxygen")

    var center_cell: Vector2i = Vector2i(2, 2)
    var center_rect: Rect2 = game.call("_cell_rect", center_cell)
    var touch_place := InputEventScreenTouch.new()
    touch_place.pressed = true
    touch_place.position = center_rect.get_center()
    game.call("_unhandled_input", touch_place)
    var touch_state: Dictionary = game.call("get_state")
    var touch_atoms: Array = touch_state.get("atoms", [])
    _expect(touch_atoms.size() == 1, "touch grid tap places the selected atom")
    _expect(bool(game.call("_undo")), "undo accepts the previous board edit")
    var undone_state: Dictionary = game.call("get_state")
    var undone_atoms: Array = undone_state.get("atoms", [])
    _expect(undone_atoms.is_empty(), "undo restores the prior empty board")

    var water_solution: Array = [
        ["O", Vector2i(2, 2)],
        ["H", Vector2i(2, 1)],
        ["H", Vector2i(2, 3)]
    ]
    for step in water_solution:
        game.call("_select_element", str(step[0]))
        _expect(bool(game.call("_place_at", step[1])), "scene places the next water atom")
    _expect(bool(game.call("get_state").get("complete", false)), "scene verifies the completed water molecule")
    _expect(bool(game.call("next_level")), "completed water advances to ammonia")
    _expect(str(game.call("get_current_level").get("id", "")) == "ammonia", "second challenge loads ammonia")

    game.call("reset_level")
    var ammonia_solution: Array = [
        ["N", Vector2i(2, 2)],
        ["H", Vector2i(1, 2)],
        ["H", Vector2i(2, 1)],
        ["H", Vector2i(3, 2)]
    ]
    for step in ammonia_solution:
        game.call("_select_element", str(step[0]))
        game.call("_place_at", step[1])
    _expect(bool(game.call("get_state").get("complete", false)), "scene verifies the ammonia molecule")

    game.call("reset_level")
    var touch_reset := InputEventScreenTouch.new()
    touch_reset.pressed = true
    var reset_rect: Rect2 = game.call("_action_button_rect", "reset")
    touch_reset.position = reset_rect.get_center()
    game.call("_unhandled_input", touch_reset)
    var reset_state: Dictionary = game.call("get_state")
    var reset_atoms: Array = reset_state.get("atoms", [])
    _expect(reset_atoms.is_empty(), "touch RESET clears the current molecule")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Molecule Forge runtime smoke test passed.")
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
