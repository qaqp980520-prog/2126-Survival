extends SceneTree

const MainScript = preload("res://main.gd")
const EXPECTED_PAR: Array = [[1, 1, 2, 2], [0, 1, 0, 1], [1, 0, 0, 1]]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://main.tscn").instantiate() as Control
	_expect(scene != null, "thermal containment scene instantiates")
	if scene == null:
		quit(1)
		return
	root.add_child(scene)
	await process_frame
	_expect(scene.find_child("ThermalGrid", true, false) != null, "4x4 thermal grid is present")
	_expect(scene.find_child("VentRow1", true, false) != null and scene.find_child("VentRow4", true, false) != null, "all four row controls are present")
	_expect(scene.find_child("AdvanceButton", true, false) != null, "cycle advance control is present")
	_expect(scene.get_game_state().get("grid", []).size() == 4, "initial temperature field is loaded")

	for level_index in range(EXPECTED_PAR.size()):
		if level_index > 0:
			_expect(scene.next_level(), "next chamber loads after successful containment")
		for row in EXPECTED_PAR[level_index]:
			scene.select_row(int(row))
			_expect(scene.advance_cycle(), "selected vent row advances one cycle")
		var state: Dictionary = scene.get_game_state()
		_expect(bool(state.get("completed", false)), "authored chamber reaches stable containment")
	_expect(int(scene.get_game_state().get("campaign_score", 0)) == 300, "runtime campaign awards the 300-point maximum")

	var reset_key := InputEventKey.new()
	reset_key.pressed = true
	reset_key.keycode = KEY_C
	scene._unhandled_input(reset_key)
	_expect(int(scene.get_game_state().get("campaign_score", -1)) == 0, "keyboard campaign restart resets the ledger")
	var row_key := InputEventKey.new()
	row_key.pressed = true
	row_key.keycode = KEY_3
	scene._unhandled_input(row_key)
	_expect(int(scene.get_game_state().get("selected_row", -1)) == 2, "keyboard row selection updates the vent target")

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Thermal Containment runtime smoke test passed.")
		quit(0)
	else:
		push_error("KROLL Thermal Containment runtime smoke failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
