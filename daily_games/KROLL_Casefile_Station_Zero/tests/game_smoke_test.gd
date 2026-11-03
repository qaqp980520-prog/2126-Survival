extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // CASEFILE: STATION ZERO", "scene displays the Casefile title")
	_expect(int(game.call("get_case_count")) == 3, "scene exposes three case files")
	_expect(int(game.call("get_suspect_button_count")) == 3, "scene builds three suspect buttons")
	_expect(int(game.call("get_evidence_button_count")) == 3, "scene builds three evidence buttons")
	_expect(int(game.call("get_action_button_count")) == 5, "scene builds five campaign action buttons")
	_expect(not str(game.call("get_status_text")).is_empty(), "scene displays case instructions and status")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Casefile Station Zero runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
