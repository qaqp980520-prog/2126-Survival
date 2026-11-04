extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	_expect(scene.call("get_grid_button_count") == 64, "runtime builds all sixty-four excavation cells")
	_expect(scene.call("select_tool", "scan"), "scanner can be selected from the runtime interface")
	var mission: Dictionary = Rules.mission_at(0)
	_expect(scene.call("apply_tool_at", "scan", mission["center"]), "runtime accepts a scanner action")
	_expect(scene.call("apply_tool_at", "air", mission["center"]), "runtime accepts an air-scribe action")
	var initial_state: Dictionary = scene.call("get_game_state")
	for fossil_cell in initial_state["fossil_cells"]:
		_expect(scene.call("apply_tool_at", "brush", fossil_cell), "runtime accepts a precision brush action")
	_expect(str(scene.call("get_game_state")["status"]) == "complete", "runtime completes the first specimen")
	_expect(scene.call("next_mission"), "runtime advances to the next fossil site")
	_expect(int(scene.call("get_game_state")["mission_index"]) == 1, "next site loads the second specimen")
	scene.call("restart_campaign")
	_expect(int(scene.call("get_game_state")["mission_index"]) == 0, "new expedition returns to the first site")
	_expect(int(scene.call("get_game_state")["campaign_score"]) == 0, "new expedition resets campaign score")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Fossil Extraction Lab runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
