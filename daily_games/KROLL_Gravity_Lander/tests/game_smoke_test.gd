extends SceneTree

const MainScene = preload("res://Main.tscn")
var failures: Array[String] = []

var watchdog: Timer

func _initialize() -> void:
    watchdog = Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 20.0
    root.add_child(watchdog)
    watchdog.timeout.connect(_on_timeout)
    call_deferred("_start_watchdog")
    call_deferred("_run_smoke_test")

func _start_watchdog() -> void:
    if is_instance_valid(watchdog) and watchdog.is_inside_tree():
        watchdog.start()

func _run_smoke_test() -> void:
    var game = MainScene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(str(game.call("get_round_state")) == "playing", "new round starts")
    _expect(is_equal_approx(float(game.get("fuel")), 100.0), "fuel starts full")

    game.set("lander_position", Vector2(480.0, 550.0))
    game.set("lander_velocity", Vector2(0.0, 70.0))
    game.call("resolve_landing")
    _expect(str(game.call("get_round_state")) == "won", "safe landing succeeds")

    game.call("restart_round")
    game.set("lander_position", Vector2(100.0, 550.0))
    game.set("lander_velocity", Vector2(0.0, 20.0))
    game.call("resolve_landing")
    _expect(str(game.call("get_round_state")) == "lost", "landing outside pad fails")

    game.call("restart_round")
    game.set("lander_position", Vector2(480.0, 550.0))
    game.set("lander_velocity", Vector2(0.0, 120.0))
    game.call("resolve_landing")
    _expect(str(game.call("get_round_state")) == "lost", "excessive descent speed fails")

    var exit_code: int = 0
    if failures.is_empty():
        print("KROLL Gravity Lander runtime smoke test passed.")
    else:
        exit_code = 1
    if is_instance_valid(watchdog):
        watchdog.stop()
        watchdog.queue_free()
    await process_frame
    quit(exit_code)

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

func _on_timeout() -> void:
    push_error("KROLL Gravity Lander smoke test timed out.")
    quit(2)
