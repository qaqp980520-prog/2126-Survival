extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(str(game.state.get("status", "")) == "playing", "scene starts in playing state")
	_expect(game.asteroids.size() == 4, "scene creates the initial asteroid field")
	_expect(game.energy_cells.size() == Rules.REQUIRED_CELLS, "scene creates the required energy cells")
	game._activate_shield()
	_expect(game.shield_left > 0.0 and game.shield_cooldown > 0.0, "shield activation starts its duration and cooldown")
	for _index in range(Rules.REQUIRED_CELLS):
		game._register_cell_collected()
	_expect(str(game.state.get("status", "")) == "won", "game scene transitions to victory after cell recovery")
	game._restart_game()
	_expect(str(game.state.get("status", "")) == "playing", "restart returns scene to playing state")
	_expect(game.asteroids.size() == 4 and game.energy_cells.size() == Rules.REQUIRED_CELLS, "restart resets asteroids and energy cells")
	_expect(is_equal_approx(game.shield_left, 0.0) and is_equal_approx(game.shield_cooldown, 0.0), "restart resets shield state")
	game.queue_free()
	await process_frame
	print("KROLL Orbit Warden runtime smoke test passed." if failures.is_empty() else "KROLL Orbit Warden runtime smoke test failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
