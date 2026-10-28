extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := GameScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.state.get("status") == "playing", "scene starts in a playable state")
    _expect(game.get_child_count() >= 2, "scene builds the game interface")
    _expect(game._perform_action("cast"), "live scene accepts a cast")
    _expect(game.state["mode"] == "waiting", "cast updates the live scene state")
    game.restart_game()
    _expect(game.state["turns"] == 0 and game.state["catches"] == 0, "restart resets the fishing state")

    var guard: int = 0
    while game.state["status"] == "playing" and guard < Rules.MAX_TURNS:
        guard += 1
        match str(game.state["mode"]):
            "idle":
                game._perform_action("cast")
            "waiting":
                game._perform_action("wait")
            "bite":
                game._perform_action("hook")
            "fight":
                game._perform_action("ease" if float(game.state["tension"]) >= 65.0 else "reel")
    _expect(game.state["status"] == "won", "live scene can complete a three-fish expedition")
    _expect(game.state["catches"] == 3, "live scene tracks all three catches")
    game.next_tide()
    _expect(game.state["seed"] == 34 and game.state["status"] == "playing", "next tide changes the deterministic seed")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Deep Current Angler runtime smoke test passed.")
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
