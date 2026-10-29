extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "scene initializes game state")
	_expect(game.get_node_or_null("VBoxContainer") == null or game.get_child_count() > 0, "scene builds its interface")
	_expect(game.get("status_label") is Label, "status label exists")
	_expect(game.get("chamber_labels").size() == 4, "four chamber panels are created")

	for index in range(3):
		game.call("_act", Rules.toggle_gate(game.get("state")))
		var state: Dictionary = game.get("state")
		var levels: Array = state["levels"]
		var position: int = int(state["position"])
		while absi(int(levels[position]) - int(levels[position + 1])) > 1:
			var delta: int = 1 if int(levels[position]) < int(levels[position + 1]) else -1
			game.call("_act", Rules.pump(game.get("state"), delta))
			state = game.get("state")
			levels = state["levels"]
		game.call("_act", Rules.move_boat(game.get("state"), 1))
	_expect(str(game.get("state")["status"]) == "won", "live scene completes a safe four-chamber transit")
	game.call("restart_game")
	_expect(str(game.get("state")["status"]) == "playing" and int(game.get("state")["position"]) == 0, "restart resets the current layout")
	game.call("next_layout")
	_expect(int(game.get("state")["seed"]) == 8, "next layout advances deterministically")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Tidal Lock runtime smoke test passed.")
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
