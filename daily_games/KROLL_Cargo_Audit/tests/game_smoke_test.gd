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
	var scan_result: Dictionary = game.call("_scan_selected")
	_expect(bool(scan_result.get("ok", false)) and bool(scan_result.get("record", {}).get("mismatch", false)), "selected sensor scan reveals the manifest discrepancy")
	(buttons["submit"] as Button).pressed.emit()
	_expect(str(game.get("state").get("status", "")) == "cleared", "actual submit button clears the correct audit")
	_expect(int(game.get("state").get("score", 0)) > 0, "successful case awards a score")
	(buttons["next"] as Button).pressed.emit()
	_expect(int(game.get("case_index")) == 1 and str(game.get("state").get("status", "")) == "investigating", "next button opens the following case")
	(buttons["reset"] as Button).pressed.emit()
	_expect(int(game.get("state").get("scans_used", -1)) == 0, "reset button clears the scan ledger")
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
