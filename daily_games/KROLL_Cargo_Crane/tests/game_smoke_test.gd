extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := MainScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.get("state") is Dictionary, "main scene creates a crane state")
    _expect(str(game.get("state").get("status", "")) == "playing", "scene starts in playing state")
    _expect(game.get_node_or_null("LeftButton") != null and game.get_node_or_null("DropButton") != null, "touch-safe controls are created")

    for index in range(6):
        game.state["hook_x"] = _top_center(game.state)
        _expect(bool(game.call("drop_load")), "scene accepts aligned load %d" % (index + 1))
    _expect(str(game.get("state").get("status", "")) == "won", "live scene reaches the win state")
    game.call("restart_game")
    _expect(str(game.get("state").get("status", "")) == "playing" and int(game.get("state").get("level", -1)) == 0, "restart restores the initial manifest")
    game.call("next_manifest")
    _expect(int(game.get("state").get("seed", 0)) == 8, "next manifest advances the deterministic seed")

    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Cargo Crane runtime smoke test passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _top_center(state: Dictionary) -> float:
    var placed: Array = state["placed"]
    if placed.is_empty():
        return float(state["base_left"]) + float(state["base_width"]) * 0.5
    var top: Dictionary = placed.back()
    return float(top["left"]) + float(top["width"]) * 0.5

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
