extends SceneTree

const PlaygroundScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")

var failures: Array[String] = []
var watchdog: Timer

func _initialize() -> void:
    watchdog = Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 15.0
    root.add_child(watchdog)
    watchdog.timeout.connect(_on_timeout)
    call_deferred("_run")

func _run() -> void:
    watchdog.start()
    var world: Node = PlaygroundScene.instantiate()
    root.add_child(world)
    await process_frame
    var player: Node = world.get_node("Player")
    var camera: Camera3D = player.get_node("Camera3D")
    var initial_yaw: float = player.rotation.y

    var right_press := InputEventMouseButton.new()
    right_press.button_index = MOUSE_BUTTON_RIGHT
    right_press.pressed = true
    player.call("_input", right_press)
    _expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "right mouse captures pointer")

    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(40.0, -1000.0)
    player.call("_input", motion)
    _expect(not is_equal_approx(player.rotation.y, initial_yaw), "mouse motion changes player yaw")
    var pitch_limit := deg_to_rad(82.0)
    _expect(camera.rotation.x <= pitch_limit + 0.0001, "camera pitch stays below upper limit")
    _expect(camera.rotation.x >= -pitch_limit - 0.0001, "camera pitch stays above lower limit")

    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    player.call("_input", escape)
    _expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases pointer")

    var window: Window = player.get_window()
    _expect(window != null, "player resolves a window")
    if window != null:
        var original_mode: int = window.mode
        var f11_echo := InputEventKey.new()
        f11_echo.keycode = KEY_F11
        f11_echo.pressed = true
        f11_echo.echo = true
        player.call("_input", f11_echo)
        _expect(window.mode == original_mode, "F11 key echo does not toggle window mode")

    world.queue_free()
    await process_frame
    watchdog.stop()
    watchdog.queue_free()
    var exit_code := 0
    if failures.is_empty():
        print("Backrooms player mouse-look input tests passed.")
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        exit_code = 1
    quit(exit_code)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _on_timeout() -> void:
    push_error("FAIL: player input test timed out")
    quit(1)
