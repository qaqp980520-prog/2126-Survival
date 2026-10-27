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
	game._fire_bullet()
	_expect(game.bullets.size() == 1, "fire action creates a projectile")
	for _index in range(Rules.TARGET_DESTROYS):
		game._register_asteroid_destroyed()
	_expect(str(game.state.get("status", "")) == "won", "game scene transitions to victory at target count")
	game._restart_game()
	_expect(str(game.state.get("status", "")) == "playing", "restart returns scene to playing state")
	_expect(game.asteroids.size() == 4 and game.bullets.is_empty(), "restart resets asteroids and projectiles")
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
