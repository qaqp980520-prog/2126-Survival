extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []
var watchdog: Timer
var game: Node2D

func _initialize() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 15.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run")

func _start_watchdog() -> void:
	if is_instance_valid(watchdog) and watchdog.is_inside_tree():
		watchdog.start()

func _run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.state is Dictionary and not game.state.is_empty(), "main scene initializes a puzzle state")
	_expect(not Rules.is_solved(game.state), "runtime puzzle starts unsolved")
	var initial_moves := int(game.state.get("moves", -1))
	game.call("_rotate_selected")
	_expect(int(game.state.get("moves", -1)) == initial_moves + 1, "keyboard-selected pipe rotation updates the move count")

	var masks: Array = game.state["masks"]
	var solution_masks: Array = game.state["solution_masks"]
	for index in range(masks.size()):
		masks[index] = solution_masks[index]
	game.call("_update_banner")
	game.queue_redraw()
	_expect(Rules.is_solved(game.state), "solved pipe layout connects inlet to outlet")
	_expect(str(game.banner) == "FLOW RESTORED", "HUD state changes when the flow is restored")

	game.call("_reset_game")
	_expect(int(game.state.get("moves", -1)) == 0, "reset starts a fresh move counter")
	_expect(not Rules.is_solved(game.state), "reset creates a fresh scrambled puzzle")

	if failures.is_empty():
		print("KROLL Pressure Circuit runtime smoke test passed.")
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	_finish(0 if failures.is_empty() else 1)

func _on_timeout() -> void:
	push_error("KROLL Pressure Circuit runtime smoke test timed out.")
	_finish(2)

func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	quit(exit_code)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
