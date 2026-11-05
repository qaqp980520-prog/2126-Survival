extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")

var _failures: Array[String] = []
var _world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = WorldScene.instantiate() as Node3D
	_expect(_world != null, "production SurfaceWorld instantiates for touch-look coverage")
	if _world == null:
		quit(1)
		return
	root.add_child(_world)
	await process_frame

	var player: CharacterBody3D = _world.get("player") as CharacterBody3D
	var camera: Camera3D = _world.get("camera") as Camera3D
	_expect(player != null and camera != null, "production player and first-person camera are available")
	if player == null or camera == null:
		_finish(1)
		return

	var initial_yaw: float = float(_world.get("_yaw"))
	var initial_pitch: float = float(_world.get("_pitch"))
	var untracked_ui_drag := InputEventScreenDrag.new()
	untracked_ui_drag.index = 1
	untracked_ui_drag.relative = Vector2(40.0, -20.0)
	_world.call("_unhandled_input", untracked_ui_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), initial_yaw), "a drag whose initial UI-owned touch was handled cannot rotate the player")
	_expect(is_equal_approx(float(_world.get("_pitch")), initial_pitch), "an untracked UI touch cannot rotate the camera")

	var world_touch := InputEventScreenTouch.new()
	world_touch.index = 2
	world_touch.pressed = true
	_world.call("_unhandled_input", world_touch)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 2
	touch_drag.relative = Vector2(40.0, -20.0)
	_world.call("_unhandled_input", touch_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), initial_yaw - 0.12), "screen drag changes player yaw using the shared look sensitivity")
	_expect(is_equal_approx(float(_world.get("_pitch")), initial_pitch + 0.06), "screen drag changes camera pitch with inverted vertical look")
	_expect(is_equal_approx(player.rotation.y, float(_world.get("_yaw"))), "touch look applies yaw to the CharacterBody3D")
	_expect(is_equal_approx(camera.rotation.x, float(_world.get("_pitch"))), "touch look applies pitch to the first-person camera")

	var upper_clamp_drag := InputEventScreenDrag.new()
	upper_clamp_drag.relative = Vector2(0.0, -1000.0)
	_world.set("_pitch", 0.9)
	camera.rotation.x = 0.9
	_world.call("_unhandled_input", upper_clamp_drag)
	_expect(is_equal_approx(float(_world.get("_pitch")), 1.05), "touch look clamps the upward pitch limit")
	_expect(is_equal_approx(camera.rotation.x, 1.05), "camera pitch follows the upper clamp")

	var lower_clamp_drag := InputEventScreenDrag.new()
	lower_clamp_drag.relative = Vector2(0.0, 1000.0)
	_world.call("_unhandled_input", lower_clamp_drag)
	_expect(is_equal_approx(float(_world.get("_pitch")), -1.05), "touch look clamps the downward pitch limit")
	_expect(is_equal_approx(camera.rotation.x, -1.05), "camera pitch follows the lower clamp")

	var queued_world_touch := InputEventScreenTouch.new()
	queued_world_touch.index = 3
	queued_world_touch.pressed = true
	_world.call("_unhandled_input", queued_world_touch)
	var world_touch_release := InputEventScreenTouch.new()
	world_touch_release.index = 2
	world_touch_release.pressed = false
	_world.call("_unhandled_input", world_touch_release)
	var queued_touch_drag := InputEventScreenDrag.new()
	queued_touch_drag.index = 3
	queued_touch_drag.relative = Vector2(-10.0, 0.0)
	var yaw_before_queued_touch := float(_world.get("_yaw"))
	_world.call("_unhandled_input", queued_touch_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), yaw_before_queued_touch + 0.03), "the next eligible world touch takes over look after the active finger releases")
	var queued_touch_release := InputEventScreenTouch.new()
	queued_touch_release.index = 3
	queued_touch_release.pressed = false
	_world.call("_unhandled_input", queued_touch_release)
	var stale_touch_drag := InputEventScreenDrag.new()
	stale_touch_drag.index = 3
	stale_touch_drag.relative = Vector2(40.0, 0.0)
	var yaw_after_release := float(_world.get("_yaw"))
	_world.call("_unhandled_input", stale_touch_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), yaw_after_release), "releasing a world touch disables further camera-look deltas for that finger")

	_world.set("_yaw", 0.0)
	_world.set("_mouse_look_active", true)
	player.rotation.y = 0.0
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(-10.0, 5.0)
	_world.call("_unhandled_input", mouse_motion)
	_expect(is_equal_approx(float(_world.get("_yaw")), 0.03), "existing mouse look uses the same yaw helper")
	_expect(is_equal_approx(float(_world.get("_pitch")), -1.05), "existing mouse look retains the shared pitch clamp")

	_finish(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	await process_frame
	if exit_code == 0 and _failures.is_empty():
		print("Production SurfaceWorld touch-look tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAILED: " + failure)
		quit(1)
