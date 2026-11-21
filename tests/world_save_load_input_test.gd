extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SAVE_PATH: String = "user://2126_survival_world.json"

var failures: Array[String] = []
var world: Node3D
var watchdog: Timer


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 90.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	watchdog.start()

	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "production SurfaceWorld scene instantiates for Save/Load input coverage")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await process_frame
	_expect(bool(world.call("_is_world_save_integer", 1.0, 1)), "world envelope integer validator accepts exact finite integers")
	_expect(not bool(world.call("_is_world_save_integer", 1e308, 1)), "world envelope integer validator rejects huge finite numbers without integer overflow")

	# The HUD is assembled dynamically under its CanvasLayer; read the production
	# controls from SurfaceWorld's owned references instead of assuming a scene path.
	var save_button: Button = world.get("save_button") as Button
	var load_button: Button = world.get("load_button") as Button
	var dialog: ConfirmationDialog = world.get("load_confirmation_dialog") as ConfirmationDialog
	_expect(save_button != null and load_button != null, "production HUD exposes touch Save and Load buttons")
	if save_button != null and load_button != null:
		_expect(save_button.name == "SaveWorld" and load_button.name == "LoadWorld", "touch Save/Load controls retain their stable node names")
		_expect(
			save_button.get_signal_connection_list("pressed").size() > 0
			and load_button.get_signal_connection_list("pressed").size() > 0,
			"touch Save/Load controls are connected to their production handlers"
		)
	_expect(dialog != null, "production HUD exposes a Load confirmation dialog")
	if save_button == null or load_button == null or dialog == null:
		_finish()
		return
	_expect(not save_button.disabled and load_button.disabled, "Save is enabled and Load is disabled until a world file exists")

	save_button.emit_signal("pressed")
	await process_frame
	var save_report: Dictionary = world.call("get_last_world_file_report")
	_expect(bool(save_report.get("success", false)), "touch Save button writes the production world envelope")
	_expect(FileAccess.file_exists(SAVE_PATH), "touch Save button creates the default user:// world file")
	_expect(not load_button.disabled, "Load becomes available after the first successful save")

	load_button.emit_signal("pressed")
	_expect(dialog.visible, "touch Load button opens the explicit overwrite confirmation")
	var before_confirmation: Dictionary = world.call("get_last_world_file_report")
	_expect(str(before_confirmation.get("phase", "")) == "complete", "opening Load confirmation does not execute a load")
	var f9 := InputEventKey.new()
	f9.keycode = KEY_F9
	f9.pressed = true
	world.call("_unhandled_input", f9)
	_expect(dialog.visible, "desktop F9 also requests confirmation instead of loading immediately")
	dialog.confirmed.emit()
	await process_frame
	var load_report: Dictionary = world.call("get_last_world_file_report")
	_expect(bool(load_report.get("success", false)), "confirmed Load restores the production world file")
	_expect(str(load_report.get("phase", "")) == "primary_restored", "confirmed Load reports primary-file restoration")
	_expect(not dialog.visible, "confirmation dialog closes after Load is confirmed")

	var f5 := InputEventKey.new()
	f5.keycode = KEY_F5
	f5.pressed = true
	world.call("_unhandled_input", f5)
	await process_frame
	var keyboard_save_report: Dictionary = world.call("get_last_world_file_report")
	_expect(bool(keyboard_save_report.get("success", false)), "desktop F5 writes the production world file")
	_expect(str(keyboard_save_report.get("phase", "")) == "complete", "desktop F5 reports a completed atomic save")

	world.set("_surface_stream_pending", true)
	world.call("_refresh_hud")
	_expect(save_button.disabled and load_button.disabled, "both Save and Load controls disable during SurfaceWorld streaming")
	world.set("_surface_stream_pending", false)
	world.set("_is_in_backrooms", true)
	world.call("_refresh_hud")
	_expect(load_button.disabled, "Load control disables while a Backrooms visit is active")
	world.set("_is_in_backrooms", false)
	world.call("_refresh_hud")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAILED: " + message)


func _on_timeout() -> void:
	_expect(false, "Save/Load input regression watchdog timed out")
	_finish()


func _finish() -> void:
	if world != null:
		world.queue_free()
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		var path: String = SAVE_PATH + suffix
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
			DirAccess.remove_absolute(absolute)
	if watchdog != null:
		watchdog.queue_free()
	await process_frame
	if failures.is_empty():
		print("World save/load keyboard and touch input tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
