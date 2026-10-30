extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "cargo audit scene creates an active case")
	var buttons: Dictionary = game.get("touch_buttons")
	for key in ["container_0", "container_1", "container_2", "container_3", "field_mass", "field_seal", "field_count", "scan", "submit", "reset", "next"]:
		_expect(buttons.has(key), "mouse/touch control exists: " + key)
	(buttons["container_1"] as Button).pressed.emit()
	(buttons["field_mass"] as Button).pressed.emit()
	(buttons["scan"] as Button).pressed.emit()
	var scan_record: Dictionary = game.get("state").get("scans", {}).get("1:mass", {})
	_expect(bool(scan_record.get("mismatch", false)), "actual scan button reveals the manifest discrepancy")
	(buttons["submit"] as Button).pressed.emit()
	_expect(str(game.get("state").get("status", "")) == "cleared", "actual submit button clears the correct audit")
	_expect(int(game.get("state").get("score", 0)) > 0, "successful case awards a score")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("case_index")) == 1 and str(game.get("state").get("status", "")) == "investigating", "next button opens the following case")
	(buttons["reset"] as Button).pressed.emit()
	_expect(int(game.get("state").get("scans_used", -1)) == 0, "reset button clears the scan ledger")
	var container_key := InputEventKey.new()
	container_key.pressed = true
	container_key.keycode = KEY_3
	game.call("_unhandled_input", container_key)
	_expect(int(game.get("selected_container")) == 2, "keyboard number key selects a container")
	var field_key := InputEventKey.new()
	field_key.pressed = true
	field_key.keycode = KEY_C
	game.call("_unhandled_input", field_key)
	_expect(str(game.get("selected_field")) == "count", "keyboard letter key selects an inspection field")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Cargo Audit runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
