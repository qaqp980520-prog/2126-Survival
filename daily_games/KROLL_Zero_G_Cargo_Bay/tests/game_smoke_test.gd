extends SceneTree

const GameScene = preload("res://main.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get_node_or_null("SafeMargin/MainColumn/CargoGrid") != null, "cargo grid is created")
	_expect(game.get_node("SafeMargin/MainColumn/CargoGrid").get_child_count() == 25, "five-by-five cargo deck has 25 cells")
	_expect(game.get_node_or_null("SafeMargin/MainColumn/ActionControls/PlaceButton") != null, "touch place button is available")
	_expect(game.get_node_or_null("SafeMargin/MainColumn/ActionControls/RotateButton") != null, "touch rotate button is available")
	_expect(game.get_node_or_null("SafeMargin/MainColumn/ActionControls/UndoButton") != null, "touch undo button is available")
	_expect(game.get_node_or_null("SafeMargin/MainColumn/ActionControls/NextButton") != null, "touch next button is available")
	_expect(game.get_node_or_null("SafeMargin/MainColumn/ActionControls/RestartButton") != null, "touch restart button is available")
	var initial: Dictionary = game.call("get_game_state")
	_expect(str(initial.get("status", "")) == "active", "campaign starts in active state")
	_expect(bool(game.call("perform_action", "place")), "first cargo can be placed from the initial cursor")
	var after_place: Dictionary = game.call("get_game_state")
	_expect(after_place.get("placements", []).size() == 1, "runtime action updates the deck")
	_expect(bool(game.call("perform_action", "rotate")), "next cargo can be rotated")
	_expect(int(game.call("get_game_state").get("rotation", -1)) == 1, "runtime rotation updates the selected cargo")
	_expect(bool(game.call("perform_action", "undo")), "runtime undo removes the last placed cargo")
	_expect(game.call("get_game_state").get("placements", []).is_empty(), "runtime undo clears the first placement")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Zero-G Cargo Bay runtime smoke test passed.")
		quit(0)
	else:
		push_error("KROLL Zero-G Cargo Bay runtime smoke failures: " + str(failures))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
