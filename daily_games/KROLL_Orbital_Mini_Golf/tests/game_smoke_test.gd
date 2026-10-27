extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_check(str(game.status) == "playing", "Game should start in playing state.")
	_check(int(game.course_index) == 0 and game.obstacles.size() >= 3, "First course should load its obstacles.")
	game._launch(Vector2(120.0, 0.0))
	_check(int(game.shots_this_course) == 1 and int(game.total_shots) == 1, "A valid shot should increment stroke counters.")
	_check(float(game.ball_velocity.length()) <= Rules.MAX_SHOT_SPEED, "Shot velocity must stay within the configured maximum.")
	var obstacle := Rect2(200.0, 200.0, 80.0, 40.0)
	game.ball_position = Vector2(220.0, 220.0)
	game.ball_velocity = Vector2(0.0, 10.0)
	game._collide_obstacle(obstacle)
	_check(not obstacle.has_point(game.ball_position), "A ball starting inside an obstacle must be ejected outside its bounds.")
	game.ball_position = game.hole_position
	game.ball_velocity = Vector2.ZERO
	game.shots_this_course = 1
	game._physics_process(0.016)
	_check(int(game.course_index) == 1, "Sinking a course should advance to the next course.")
	_check(int(game.shots_this_course) == 0, "Advancing should reset per-course strokes.")
	game._reset_game()
	_check(int(game.course_index) == 0 and int(game.total_shots) == 0, "Restart should reset course and total strokes.")
	game.elapsed_seconds = Rules.TIME_LIMIT
	game._process(0.1)
	_check(str(game.status) == "failed", "Timer expiry should end an unfinished round.")
	game.queue_free()
	await process_frame
	if _failed:
		print("KROLL Orbital Mini Golf runtime smoke test failed.")
		quit(1)
	else:
		print("KROLL Orbital Mini Golf runtime smoke test passed.")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
