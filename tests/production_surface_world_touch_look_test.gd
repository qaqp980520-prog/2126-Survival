extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")

var _failures: Array[String] = []
var _world: Node3D
var _previous_emulate_mouse_from_touch: bool = true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_previous_emulate_mouse_from_touch = Input.emulate_mouse_from_touch
	_world = WorldScene.instantiate() as Node3D
	_expect(_world != null, "production SurfaceWorld instantiates for touch-look coverage")
	if _world == null:
		quit(1)
		return
	root.add_child(_world)
	await process_frame
	_expect(not Input.emulate_mouse_from_touch, "SurfaceWorld routes raw screen touches directly instead of single-pointer mouse emulation")

	var player: CharacterBody3D = _world.get("player") as CharacterBody3D
	var camera: Camera3D = _world.get("camera") as Camera3D
	_expect(player != null and camera != null, "production player and first-person camera are available")
	if player == null or camera == null:
		_finish(1)
		return

	var world_status := _world.get_node_or_null("HUD/WorldStatus") as Label
	var interaction_prompt := _world.get_node_or_null("HUD/InteractionPrompt") as Label
	_expect(world_status != null and interaction_prompt != null, "production HUD exposes both display-only labels")
	_assert_display_label_allows_camera_look(world_status, 8, "WorldStatus label")
	_assert_display_label_allows_camera_look(interaction_prompt, 9, "InteractionPrompt label")

	# This regression exercises raw screen-touch ownership through the production
	# unhandled-input handler. It does not claim physical or mouse-emulated Control
	# activation; that remains a non-headless device-level check.
	var touch_buttons: Dictionary = _world.get("touch_buttons")
	var jump_button: Button = touch_buttons.get("jump") as Button
	_expect(jump_button != null, "production HUD exposes its jump touch button")
	if jump_button != null:
		var jump_rect: Rect2 = jump_button.get_global_rect()
		var ui_position: Vector2 = jump_rect.get_center()
		_expect(jump_rect.size.x > 0.0 and jump_rect.size.y > 0.0, "jump touch button has a laid-out GUI rectangle")
		_expect(bool(_world.call("_is_touch_over_hud_control", ui_position)), "HUD hit test recognizes the jump button center in viewport coordinates")

		var ui_touch := InputEventScreenTouch.new()
		ui_touch.index = 0
		ui_touch.position = ui_position
		ui_touch.pressed = true
		_world.call("_input", ui_touch)
		var ui_look_indices: Array = _world.get("_touch_look_indices")
		_expect(not ui_look_indices.has(ui_touch.index), "a screen touch starting over a HUD Control is excluded from camera-look ownership")

		var yaw_before_ui_drag: float = float(_world.get("_yaw"))
		var pitch_before_ui_drag: float = float(_world.get("_pitch"))
		var ui_drag := InputEventScreenDrag.new()
		ui_drag.index = ui_touch.index
		ui_drag.position = ui_position + Vector2(8.0, 0.0)
		ui_drag.relative = Vector2(40.0, -20.0)
		_world.call("_input", ui_drag)
		_expect(is_equal_approx(float(_world.get("_yaw")), yaw_before_ui_drag), "dragging a HUD-owned touch cannot rotate the player")
		_expect(is_equal_approx(float(_world.get("_pitch")), pitch_before_ui_drag), "dragging a HUD-owned touch cannot rotate the camera")

		var ui_release := InputEventScreenTouch.new()
		ui_release.index = ui_touch.index
		ui_release.position = ui_position
		ui_release.pressed = false
		_world.call("_input", ui_release)

	_assert_touch_button_contract(touch_buttons)
	await _assert_native_multitouch_delivery(touch_buttons)
	_assert_focus_loss_clears_held_inputs(touch_buttons)

	var initial_yaw: float = float(_world.get("_yaw"))
	var initial_pitch: float = float(_world.get("_pitch"))
	var untracked_ui_drag := InputEventScreenDrag.new()
	untracked_ui_drag.index = 1
	untracked_ui_drag.relative = Vector2(40.0, -20.0)
	_world.call("_input", untracked_ui_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), initial_yaw), "a drag whose initial UI-owned touch was handled cannot rotate the player")
	_expect(is_equal_approx(float(_world.get("_pitch")), initial_pitch), "an untracked UI touch cannot rotate the camera")

	var world_touch := InputEventScreenTouch.new()
	world_touch.index = 2
	world_touch.pressed = true
	world_touch.position = Vector2(1100.0, 300.0)
	_world.call("_input", world_touch)
	var active_touch_indices: Array = _world.get("_touch_look_indices")
	_expect(active_touch_indices.has(world_touch.index), "a touch beginning in the unobstructed world viewport is registered for camera look")
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 2
	touch_drag.relative = Vector2(40.0, -20.0)
	_world.call("_input", touch_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), initial_yaw - 0.12), "screen drag changes player yaw using the shared look sensitivity")
	_expect(is_equal_approx(float(_world.get("_pitch")), initial_pitch + 0.06), "screen drag changes camera pitch with inverted vertical look")
	_expect(is_equal_approx(player.rotation.y, float(_world.get("_yaw"))), "touch look applies yaw to the CharacterBody3D")
	_expect(is_equal_approx(camera.rotation.x, float(_world.get("_pitch"))), "touch look applies pitch to the first-person camera")

	var upper_clamp_drag := InputEventScreenDrag.new()
	upper_clamp_drag.index = 2
	upper_clamp_drag.relative = Vector2(0.0, -1000.0)
	_world.set("_pitch", 0.9)
	camera.rotation.x = 0.9
	_world.call("_input", upper_clamp_drag)
	_expect(is_equal_approx(float(_world.get("_pitch")), 1.05), "touch look clamps the upward pitch limit")
	_expect(is_equal_approx(camera.rotation.x, 1.05), "camera pitch follows the upper clamp")

	var lower_clamp_drag := InputEventScreenDrag.new()
	lower_clamp_drag.index = 2
	lower_clamp_drag.relative = Vector2(0.0, 1000.0)
	_world.call("_input", lower_clamp_drag)
	_expect(is_equal_approx(float(_world.get("_pitch")), -1.05), "touch look clamps the downward pitch limit")
	_expect(is_equal_approx(camera.rotation.x, -1.05), "camera pitch follows the lower clamp")

	var queued_world_touch := InputEventScreenTouch.new()
	queued_world_touch.index = 3
	queued_world_touch.pressed = true
	_world.call("_input", queued_world_touch)
	var world_touch_release := InputEventScreenTouch.new()
	world_touch_release.index = 2
	world_touch_release.pressed = false
	_world.call("_input", world_touch_release)
	var queued_touch_drag := InputEventScreenDrag.new()
	queued_touch_drag.index = 3
	queued_touch_drag.relative = Vector2(-10.0, 0.0)
	var yaw_before_queued_touch := float(_world.get("_yaw"))
	_world.call("_input", queued_touch_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), yaw_before_queued_touch + 0.03), "the next eligible world touch takes over look after the active finger releases")
	var queued_touch_release := InputEventScreenTouch.new()
	queued_touch_release.index = 3
	queued_touch_release.pressed = false
	_world.call("_input", queued_touch_release)
	var stale_touch_drag := InputEventScreenDrag.new()
	stale_touch_drag.index = 3
	stale_touch_drag.relative = Vector2(40.0, 0.0)
	var yaw_after_release := float(_world.get("_yaw"))
	_world.call("_input", stale_touch_drag)
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

func _assert_touch_button_contract(buttons: Dictionary) -> void:
	var direction_keys: Array[String] = ["left", "right", "forward", "back"]
	for key in direction_keys:
		var button: Button = buttons.get(key) as Button
		_expect(button != null, "movement touch button exists: %s" % key)
		if button == null:
			continue
		var button_rect: Rect2 = button.get_global_rect()
		_expect(button_rect.size.x > 0.0 and button_rect.size.y > 0.0, "movement touch button has a valid GUI rectangle: %s" % key)
		_expect(button.mouse_filter != Control.MOUSE_FILTER_IGNORE, "movement touch button participates in HUD input ownership: %s" % key)
		_expect(bool(_world.call("_is_touch_over_hud_control", button_rect.get_center())), "HUD hit test recognizes movement button: %s" % key)
		_expect(str(_world.call("_touch_button_key_at_position", button_rect.get_center())) == key, "native touch router maps movement button: %s" % key)
		_expect(_has_signal_binding(button, &"button_down", &"_set_touch_direction", [key]), "movement button down signal is bound correctly: %s" % key)
		_expect(_has_signal_binding(button, &"button_up", &"_clear_touch_direction", [key]), "movement button up signal is bound correctly: %s" % key)
		button.emit_signal("button_down")
		var active_directions: Dictionary = _world.get("_touch_directions")
		_expect(bool(active_directions.get(key, false)), "holding movement button activates direction: %s" % key)
		button.emit_signal("button_up")
		active_directions = _world.get("_touch_directions")
		_expect(not active_directions.has(key), "releasing movement button clears direction: %s" % key)

	var jump_button: Button = buttons.get("jump") as Button
	_expect(jump_button != null, "jump touch button exists for hold-state coverage")
	if jump_button != null:
		_expect(_has_signal_binding(jump_button, &"button_down", &"_set_touch_jump", [true]), "jump button down signal enables jump hold")
		_expect(_has_signal_binding(jump_button, &"button_up", &"_set_touch_jump", [false]), "jump button up signal clears jump hold")
		jump_button.emit_signal("button_down")
		_expect(bool(_world.get("_touch_jump")), "holding jump button activates jump input")
		jump_button.emit_signal("button_up")
		_expect(not bool(_world.get("_touch_jump")), "releasing jump button clears jump input")

	var sprint_button: Button = buttons.get("sprint") as Button
	_expect(sprint_button != null, "sprint touch button exists for hold-state coverage")
	if sprint_button != null:
		_expect(_has_signal_binding(sprint_button, &"button_down", &"_set_touch_sprint", [true]), "sprint button down signal enables sprint hold")
		_expect(_has_signal_binding(sprint_button, &"button_up", &"_set_touch_sprint", [false]), "sprint button up signal clears sprint hold")
		sprint_button.emit_signal("button_down")
		_expect(bool(_world.get("_touch_sprint")), "holding sprint button activates sprint input")
		sprint_button.emit_signal("button_up")
		_expect(not bool(_world.get("_touch_sprint")), "releasing sprint button clears sprint input")

	var action_handlers: Dictionary = {
		"crop": &"_on_touch_crop_pressed",
		"crate": &"_on_touch_crate_pressed",
		"terrain": &"_on_touch_terrain_pressed",
		"shaft": &"_on_touch_shaft_pressed",
		"deeper": &"_on_touch_deeper_pressed"
	}
	for key in action_handlers:
		var button: Button = buttons.get(key) as Button
		_expect(button != null, "world-action touch button exists: %s" % key)
		if button != null:
			var mapped_action_key: String = str(_world.call("_touch_button_key_at_position", button.get_global_rect().get_center()))
			_expect(mapped_action_key == ("" if button.disabled else key), "native touch router respects world-action availability: %s" % key)
			_expect(_has_signal_binding(button, &"pressed", action_handlers[key], []), "world-action button is wired to its production handler: %s" % key)

	for slot_index in range(4):
		var key: String = "quick_%d" % (slot_index + 1)
		var button: Button = buttons.get(key) as Button
		_expect(button != null, "quick-use touch button exists: %s" % key)
		if button != null:
			var mapped_quick_key: String = str(_world.call("_touch_button_key_at_position", button.get_global_rect().get_center()))
			_expect(mapped_quick_key == ("" if button.disabled else key), "native touch router respects quick-use availability: %s" % key)
			_expect(_has_signal_binding(button, &"pressed", &"_consume_quick_slot", [slot_index]), "quick-use button is bound to the correct slot: %s" % key)


func _assert_native_multitouch_delivery(buttons: Dictionary) -> void:
	var forward_button: Button = buttons.get("forward") as Button
	var jump_button: Button = buttons.get("jump") as Button
	var sprint_button: Button = buttons.get("sprint") as Button
	_expect(forward_button != null and jump_button != null and sprint_button != null, "native multitouch coverage has forward, jump and sprint controls")
	if forward_button == null or jump_button == null or sprint_button == null:
		return
	var forward_center: Vector2 = forward_button.get_global_rect().get_center()
	var jump_center: Vector2 = jump_button.get_global_rect().get_center()
	var sprint_center: Vector2 = sprint_button.get_global_rect().get_center()

	await _send_screen_touch(0, forward_center, true)
	var directions: Dictionary = _world.get("_touch_directions")
	_expect(bool(directions.get("forward", false)), "first raw screen touch activates forward movement")
	await _send_screen_touch(1, jump_center, true)
	directions = _world.get("_touch_directions")
	_expect(bool(directions.get("forward", false)) and bool(_world.get("_touch_jump")), "two simultaneous screen touches hold movement and jump")
	await _send_screen_touch(0, forward_center, false)
	directions = _world.get("_touch_directions")
	_expect(not bool(directions.get("forward", false)) and bool(_world.get("_touch_jump")), "releasing movement finger preserves the independent jump hold")
	await _send_screen_touch(1, jump_center, false)
	_expect(not bool(_world.get("_touch_jump")), "releasing the final jump finger clears jump hold")

	await _send_screen_touch(0, forward_center, true)
	await _send_screen_touch(1, forward_center, true)
	var owner_counts: Dictionary = _world.get("_touch_button_owner_counts")
	_expect(int(owner_counts.get("forward", 0)) == 2, "two fingers can independently own the same movement control")
	await _send_screen_touch(0, forward_center, false)
	directions = _world.get("_touch_directions")
	_expect(bool(directions.get("forward", false)), "one finger release does not clear a movement control still owned by another finger")
	await _send_screen_touch(1, forward_center, false)
	directions = _world.get("_touch_directions")
	_expect(not bool(directions.get("forward", false)), "movement control clears after its final owning finger releases")

	var world_look_position := Vector2(1100.0, 300.0)
	await _send_screen_touch(0, world_look_position, true)
	await _send_screen_touch(1, sprint_center, true)
	var look_indices: Array = _world.get("_touch_look_indices")
	_expect(look_indices.has(0) and bool(_world.get("_touch_sprint")), "world look and sprint can be held by separate fingers")
	var yaw_before_drag: float = float(_world.get("_yaw"))
	var look_drag := InputEventScreenDrag.new()
	look_drag.index = 0
	look_drag.position = world_look_position + Vector2(10.0, 0.0)
	look_drag.relative = Vector2(10.0, 0.0)
	Input.parse_input_event(look_drag)
	await process_frame
	_expect(is_equal_approx(float(_world.get("_yaw")), yaw_before_drag - 0.03), "world-look finger continues rotating while another finger holds sprint")
	_expect(bool(_world.get("_touch_sprint")), "world-look drag does not release the independent sprint finger")
	await _send_screen_touch(0, world_look_position, false)
	await _send_screen_touch(1, sprint_center, false)
	_expect(not bool(_world.get("_touch_sprint")), "releasing the final sprint finger clears sprint hold")

	var diagnostics_panel: Node = _world.get("streaming_diagnostics_panel") as Node
	if diagnostics_panel != null:
		diagnostics_panel.call("set_open", true)
		await process_frame
		var export_button: Button = diagnostics_panel.call("get_export_button") as Button
		_expect(export_button != null and str(_world.call("_touch_button_key_at_position", export_button.get_global_rect().get_center())) == "diagnostics_export", "diagnostics export remains reachable through native touch routing")
		if diagnostics_panel is Control:
			var panel_rect: Rect2 = (diagnostics_panel as Control).get_global_rect()
			var background_point: Vector2 = panel_rect.position + Vector2(4.0, 4.0)
			_expect(bool(_world.call("_is_touch_over_hud_control", background_point)), "diagnostics panel background blocks accidental camera-look input")
		diagnostics_panel.call("set_open", false)

func _send_screen_touch(index: int, position: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = position
	touch.pressed = pressed
	Input.parse_input_event(touch)
	await process_frame

func _assert_focus_loss_clears_held_inputs(buttons: Dictionary) -> void:
	var left_button: Button = buttons.get("left") as Button
	var jump_button: Button = buttons.get("jump") as Button
	var sprint_button: Button = buttons.get("sprint") as Button
	_expect(left_button != null and jump_button != null and sprint_button != null, "focus-loss coverage has movement, jump and sprint controls")
	if left_button == null or jump_button == null or sprint_button == null:
		return

	left_button.emit_signal("button_down")
	jump_button.emit_signal("button_down")
	sprint_button.emit_signal("button_down")
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 77
	look_touch.position = Vector2(400.0, 300.0)
	look_touch.pressed = true
	_world.call("_input", look_touch)
	var held_button_touch := InputEventScreenTouch.new()
	held_button_touch.index = 76
	held_button_touch.position = left_button.get_global_rect().get_center()
	held_button_touch.pressed = true
	_world.call("_input", held_button_touch)
	var held_touch_owners: Dictionary = _world.get("_touch_button_owners")
	_expect(held_touch_owners.has(76), "focus-loss setup registers a held gameplay touch owner")
	_world.set("_jump_was_down", true)
	_world.set("_sprint_active", true)
	_world.set("_mouse_look_active", true)
	_world.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_assert_focus_reset_state("application focus loss")

	_world.call("_set_touch_direction", "right")
	_world.call("_set_touch_jump", true)
	_world.call("_set_touch_sprint", true)
	var paused_touch := InputEventScreenTouch.new()
	paused_touch.index = 78
	paused_touch.position = Vector2(400.0, 300.0)
	paused_touch.pressed = true
	_world.call("_input", paused_touch)
	_world.set("_jump_was_down", true)
	_world.set("_sprint_active", true)
	_world.set("_mouse_look_active", true)
	_world.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	_assert_focus_reset_state("mobile application pause")

	_world.call("_set_touch_direction", "forward")
	_world.call("_set_touch_jump", true)
	_world.call("_set_touch_sprint", true)
	var window_touch := InputEventScreenTouch.new()
	window_touch.index = 79
	window_touch.position = Vector2(400.0, 300.0)
	window_touch.pressed = true
	_world.call("_input", window_touch)
	_world.set("_jump_was_down", true)
	_world.set("_sprint_active", true)
	_world.set("_mouse_look_active", true)
	_world.call("_notification", Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_assert_focus_reset_state("window focus loss")

	var yaw_after_focus_loss: float = float(_world.get("_yaw"))
	var pitch_after_focus_loss: float = float(_world.get("_pitch"))
	var stale_drag := InputEventScreenDrag.new()
	stale_drag.index = window_touch.index
	stale_drag.relative = Vector2(60.0, -30.0)
	_world.call("_input", stale_drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), yaw_after_focus_loss), "a stale drag after window focus loss cannot rotate the player")
	_expect(is_equal_approx(float(_world.get("_pitch")), pitch_after_focus_loss), "a stale drag after window focus loss cannot rotate the camera")
	var resumed_touch := InputEventScreenTouch.new()
	resumed_touch.index = 80
	resumed_touch.position = left_button.get_global_rect().get_center()
	resumed_touch.pressed = true
	_world.call("_input", resumed_touch)
	var resumed_directions: Dictionary = _world.get("_touch_directions")
	_expect(bool(resumed_directions.get("left", false)), "a fresh touch can reacquire movement after focus loss")
	resumed_touch.pressed = false
	_world.call("_input", resumed_touch)
	resumed_directions = _world.get("_touch_directions")
	_expect(not resumed_directions.has("left"), "resumed movement touch releases cleanly")

func _assert_focus_reset_state(context: String) -> void:
	var directions: Dictionary = _world.get("_touch_directions")
	var look_indices: Array = _world.get("_touch_look_indices")
	var touch_button_owners: Dictionary = _world.get("_touch_button_owners")
	var touch_button_owner_counts: Dictionary = _world.get("_touch_button_owner_counts")
	var blocked_touch_indices: Dictionary = _world.get("_touch_blocked_indices")
	_expect(touch_button_owners.is_empty(), "%s clears held touch-button ownership" % context)
	_expect(touch_button_owner_counts.is_empty(), "%s clears per-control touch ownership counts" % context)
	_expect(blocked_touch_indices.is_empty(), "%s clears blocked HUD touch indices" % context)
	_expect(directions.is_empty(), "%s clears held movement directions" % context)
	_expect(not bool(_world.get("_touch_jump")), "%s clears held jump input" % context)
	_expect(not bool(_world.get("_touch_sprint")), "%s clears held sprint input" % context)
	_expect(look_indices.is_empty(), "%s clears active world-look fingers" % context)
	_expect(not bool(_world.get("_jump_was_down")), "%s clears the jump edge latch" % context)
	_expect(not bool(_world.get("_sprint_active")), "%s clears the active sprint state" % context)
	_expect(not bool(_world.get("_mouse_look_active")), "%s disables captured mouse-look state" % context)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "%s releases mouse capture" % context)

func _has_signal_binding(button: Button, signal_name: StringName, expected_method: StringName, expected_bound_arguments: Array) -> bool:
	for connection in button.get_signal_connection_list(signal_name):
		var callback: Callable = connection.get("callable", Callable())
		if (
			callback.is_valid()
			and callback.get_method() == expected_method
			and callback.get_bound_arguments() == expected_bound_arguments
		):
			return true
	return false

func _assert_display_label_allows_camera_look(label: Label, touch_index: int, label_name: String) -> void:
	if label == null:
		return
	var viewport_position: Vector2 = label.get_global_transform_with_canvas() * (label.size * 0.5)
	_expect(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s is configured as display-only input passthrough" % label_name)
	_expect(not bool(_world.call("_is_touch_over_hud_control", viewport_position)), "%s does not claim HUD touch ownership" % label_name)
	var touch := InputEventScreenTouch.new()
	touch.index = touch_index
	touch.position = viewport_position
	touch.pressed = true
	_world.call("_unhandled_input", touch)
	var active_indices: Array = _world.get("_touch_look_indices")
	_expect(active_indices.has(touch_index), "%s permits world-look touch registration" % label_name)
	var yaw_before: float = float(_world.get("_yaw"))
	var drag := InputEventScreenDrag.new()
	drag.index = touch_index
	drag.relative = Vector2(10.0, 0.0)
	_world.call("_unhandled_input", drag)
	_expect(is_equal_approx(float(_world.get("_yaw")), yaw_before - 0.03), "%s permits camera-look drag" % label_name)
	var release := InputEventScreenTouch.new()
	release.index = touch_index
	release.pressed = false
	_world.call("_unhandled_input", release)

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
	_expect(Input.emulate_mouse_from_touch == _previous_emulate_mouse_from_touch, "SurfaceWorld restores the previous touch-to-mouse setting on exit")
	if exit_code == 0 and _failures.is_empty():
		print("Production SurfaceWorld touch-look tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAILED: " + failure)
		quit(1)
