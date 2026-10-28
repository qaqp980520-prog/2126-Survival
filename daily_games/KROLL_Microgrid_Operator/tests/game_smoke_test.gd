extends SceneTree

const MainScene = preload("res://main.tscn")
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
	var state: Dictionary = game.get("state")
	_expect(not state.is_empty(), "main scene initializes the microgrid")
	_expect(str(state.get("status", "")) == "running", "new shift starts in running state")
	var turn_before := int(state.get("turn", -1))
	game.call("_choose_action", "cool")
	state = game.get("state")
	_expect(int(state.get("turn", -1)) == turn_before + 1, "action updates state and advances one cycle")
	game.call("_reset_game")
	state = game.get("state")
	_expect(int(state.get("turn", -1)) == 0, "reset restores a fresh shift")
	_expect(str(state.get("status", "")) == "running", "reset restores the running state")
	if failures.is_empty():
		print("KROLL Microgrid Operator runtime smoke test passed.")
		_finish(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		_finish(1)

func _on_timeout() -> void:
	failures.append("runtime smoke test watchdog timed out")
	_finish(1)

func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	quit(exit_code)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
