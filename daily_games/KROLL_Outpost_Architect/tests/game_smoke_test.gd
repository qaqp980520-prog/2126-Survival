extends SceneTree

const GameScene = preload("res://main.tscn")

var failures: Array[String] = []
var game: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = GameScene.instantiate() as Control
	_expect(game != null, "main scene instantiates as a Control")
	root.add_child(game)
	await process_frame
	if game == null:
		_finish(1)
		return
	_expect(game.board_buttons.size() == 25, "scene builds the full five-by-five board")
	_expect(game.hand_buttons.size() == 3, "scene builds three playable hand buttons")
	_expect(game.state.get("board", {}).is_empty(), "new scene starts with an empty outpost")
	game.hand_buttons[0].emit_signal("pressed")
	_expect(game.selected_card == 0, "hand button signal selects the first module")
	game.board_buttons[0].emit_signal("pressed")
	_expect(game.state.get("board", {}).has(0), "board button signal places the selected module")
	_expect(int(game.state.get("turns_left", 0)) == 7, "a successful button placement consumes one turn")
	game.restart_button.emit_signal("pressed")
	_expect(game.state.get("board", {}).is_empty() and int(game.state.get("turns_left", 0)) == 8, "restart button restores the initial board and budget")
	game.next_button.emit_signal("pressed")
	_expect(int(game.state.get("layout_index", -1)) == 1, "next button advances to the second deterministic layout")
	_expect(str(game.layout_label.text).contains("Ridge Research"), "layout label updates after advancing")
	_finish(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish(exit_code: int) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("KROLL Outpost Architect runtime smoke test passed.")
	quit(exit_code)
