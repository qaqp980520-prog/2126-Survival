extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "scene initializes game state")
	_expect(game.find_child("Dial1Minus", true, false) is Button, "dial A decrement button exists")
	_expect(game.find_child("Dial2Plus", true, false) is Button, "dial B increment button exists")
	_expect(game.find_child("Dial3Minus", true, false) is Button, "dial C decrement button exists")
	_expect(game.find_child("TargetOutput1", true, false) is Label, "target output labels exist")
	_expect(game.find_child("CurrentOutput3", true, false) is Label, "current output labels exist")

	var dial_a_plus: Button = game.find_child("Dial1Plus", true, false)
	var before_dial_a: int = int(game.get("state")["frequencies"][0])
	dial_a_plus.emit_signal("pressed")
	_expect(int(game.get("state")["frequencies"][0]) == posmod(before_dial_a + 1, 10), "dial button signal is wired to the tuning action")
	game.call("restart_game")

	var state: Dictionary = game.get("state")
	var targets: Array = state["target_frequencies"]
	for dial in range(3):
		var forward_steps: int = posmod(int(targets[dial]) - int(state["frequencies"][dial]), 10)
		var delta: int = 1
		if forward_steps > 5:
			forward_steps = 10 - forward_steps
			delta = -1
		for step in range(forward_steps):
			game.call("_tune", dial, delta)
			state = game.get("state")
	_expect(str(state["status"]) == "won", "live scene reaches the signal lock through UI action handlers")
	game.call("restart_game")
	_expect(str(game.get("state")["status"]) == "playing" and int(game.get("state")["moves"]) == 0, "restart resets the current layout")
	game.call("next_layout")
	_expect(int(game.get("state")["seed"]) == 27, "next layout advances to the next fixed seed")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Frequency Tuner runtime smoke test passed.")
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
