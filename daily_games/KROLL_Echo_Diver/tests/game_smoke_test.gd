extends SceneTree

const MainScene = preload("res://main.tscn")
var _finished: bool = false
var _watchdog: Timer

func _initialize() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = 15.0
	root.add_child(_watchdog)
	_watchdog.timeout.connect(_on_timeout)
	call_deferred("_start")
	call_deferred("_run_test")

func _start() -> void:
	if not _finished and is_instance_valid(_watchdog):
		_watchdog.start()

func _run_test() -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(main != null, "main scene instantiates")
	if main == null:
		_finish(1)
		return
	_expect(main.get("state") is Dictionary, "game initializes state")
	var initial_state: Dictionary = main.get("state")
	_expect(initial_state.get("status") == "playing", "game starts in playing state")
	main.call("_pulse_sonar")
	var pulsed_state: Dictionary = main.get("state")
	_expect(int(pulsed_state.get("sonar_charges", -1)) == 3, "runtime sonar action consumes a charge")
	_expect(float(main.get("sonar_remaining")) > 0.0, "runtime sonar displays a reveal window")
	main.call("_reset_game")
	var reset_state: Dictionary = main.get("state")
	_expect(int(reset_state.get("sonar_charges", -1)) == 4, "restart restores sonar charges")
	_expect(is_equal_approx(float(main.get("remaining_time")), 75.0), "restart restores timer")
	main.free()
	_finish(0 if not _finished else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
		root.remove_child(_watchdog)
		_watchdog.free()
	quit(exit_code)

func _on_timeout() -> void:
	push_error("KROLL Echo Diver runtime smoke test timed out.")
	_finish(2)
