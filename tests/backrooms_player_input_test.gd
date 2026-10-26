extends SceneTree

const PlaygroundScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
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
    assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(40.0, -1000.0)
    player.call("_input", motion)
    assert(not is_equal_approx(player.rotation.y, initial_yaw))
    var pitch_limit := deg_to_rad(82.0)
    assert(camera.rotation.x <= pitch_limit + 0.0001)
    assert(camera.rotation.x >= -pitch_limit - 0.0001)

    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    player.call("_input", escape)
    assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

    var window: Window = player.get_window()
    var original_mode: int = window.mode
    var f11_echo := InputEventKey.new()
    f11_echo.keycode = KEY_F11
    f11_echo.pressed = true
    f11_echo.echo = true
    player.call("_input", f11_echo)
    assert(window.mode == original_mode)

    world.queue_free()
    await process_frame
    print("Backrooms player mouse-look input tests passed.")
    quit(0)
