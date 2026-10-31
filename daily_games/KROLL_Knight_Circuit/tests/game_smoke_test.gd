extends SceneTree
const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Knight Circuit scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its board state")
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("level_id", "")) == "hangar_circuit", "game starts on Hangar Circuit")
	_expect(int(initial.get("moves", -1)) == 0, "game begins with zero moves")
	var hint_button := game.get_node_or_null("HintButton") as Button
	_expect(hint_button != null, "hint button exists")
	if hint_button != null:
		hint_button.emit_signal("pressed")
	_expect(game.call("get_hint_target") == Vector2i(2,1), "hint button highlights the next authored knight square")
	game.call("_attempt_move", Vector2i(2,1))
	var moved: Dictionary = game.call("get_current_state")
	_expect(int(moved.get("moves", 0)) == 1, "board input method records a legal jump")
	var undo_button := game.get_node_or_null("UndoButton") as Button
	_expect(undo_button != null, "undo button exists")
	if undo_button != null:
		undo_button.emit_signal("pressed")
	var undone: Dictionary = game.call("get_current_state")
	_expect(int(undone.get("moves", -1)) == 0, "undo button restores the initial move count")
	game.call("_attempt_move", Vector2i(2,1))
	var reset_button := game.get_node_or_null("ResetButton") as Button
	_expect(reset_button != null, "reset button exists")
	if reset_button != null:
		reset_button.emit_signal("pressed")
	var reset_state: Dictionary = game.call("get_current_state")
	_expect(int(reset_state.get("moves", -1)) == 0 and reset_state["position"] == Vector2i(0,0), "reset button restores the starting square")
	_expect(Rules.validate_solution(Rules.get_level(0)["solution"]), "smoke test confirms the built-in route remains valid")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Knight Circuit runtime smoke test passed.")
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
