extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := MainScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.get("state") is Dictionary, "main scene creates a market state")
    _expect(int(game.get("state").get("day", 0)) == 1, "scene starts on day one")
    _expect(game.get("status_label") != null and game.get("stats_label") != null, "market HUD is built")
    _expect(game.dispatch_action("buy", "copper", 10), "scene dispatches a valid purchase")
    _expect(int(game.get("state")["cargo"]["copper"]) == 10, "purchase appears in scene state")
    _expect(game.dispatch_action("advance", "", 0), "scene advances the market")
    _expect(game.dispatch_action("sell", "copper", 10), "scene dispatches a valid sale")
    _expect(int(game.get("state")["credits"]) == 210, "scene reflects realized trade profit")
    game.restart_game()
    _expect(int(game.get("state")["day"]) == 1 and int(game.get("state")["credits"]) == 100, "restart resets cash, cargo and day")
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("KROLL Salvage Exchange runtime smoke test passed.")
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
