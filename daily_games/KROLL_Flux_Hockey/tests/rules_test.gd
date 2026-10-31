extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var initial: Dictionary = Rules.create_state()
	_expect(int(initial.get("arena_index", -1)) == 0, "new match starts in the first arena")
	_expect(int(initial.get("player_score", -1)) == 0 and int(initial.get("ai_score", -1)) == 0, "new match starts with a zero score")
	var moved: Dictionary = Rules.step(initial, 650.0, 0.05)
	_expect(float(moved.get("player_x", 0.0)) > float(initial.get("player_x", 0.0)), "player paddle moves toward the requested target")
	_expect(float(moved.get("player_x", 999.0)) <= Rules.RIGHT - Rules.PADDLE_HALF_WIDTH, "player paddle remains inside the arena")

	var wall_state: Dictionary = initial.duplicate(true)
	wall_state["puck_position"] = Vector2(Rules.LEFT + 14.0, Rules.CENTER_Y)
	wall_state["puck_velocity"] = Vector2(-300.0, 0.0)
	var wall_result: Dictionary = Rules.step(wall_state, Rules.CENTER_X, 0.02)
	var wall_velocity: Vector2 = wall_result.get("puck_velocity", Vector2.ZERO)
	_expect(wall_velocity.x > 0.0, "side-wall collision reflects the puck")

	var top_goal_state: Dictionary = initial.duplicate(true)
	top_goal_state["puck_position"] = Vector2(Rules.CENTER_X, Rules.TOP + 1.0)
	top_goal_state["puck_velocity"] = Vector2(0.0, -300.0)
	var top_goal_result: Dictionary = Rules.step(top_goal_state, Rules.CENTER_X, 0.05)
	var top_goal_position: Vector2 = top_goal_result.get("puck_position", Vector2.ZERO)
	_expect(int(top_goal_result.get("player_score", 0)) == 1, "puck crossing the upper goal awards the player")
	_expect(top_goal_position.is_equal_approx(Vector2(Rules.CENTER_X, Rules.CENTER_Y)), "scoring resets the puck to center")

	var side_miss_state: Dictionary = initial.duplicate(true)
	side_miss_state["puck_position"] = Vector2(Rules.LEFT + 30.0, Rules.TOP + 1.0)
	side_miss_state["puck_velocity"] = Vector2(0.0, -300.0)
	var side_miss_result: Dictionary = Rules.step(side_miss_state, Rules.CENTER_X, 0.05)
	var side_miss_velocity: Vector2 = side_miss_result.get("puck_velocity", Vector2.ZERO)
	_expect(int(side_miss_result.get("player_score", 0)) == 0, "upper boundary outside the goal does not score")
	_expect(side_miss_velocity.y > 0.0, "upper boundary outside the goal reflects the puck")

	var bumper_state: Dictionary = Rules.create_state(1)
	bumper_state["puck_position"] = Vector2(300.0, 300.0 + Rules.BUMPER_RADIUS + Rules.PUCK_RADIUS + 2.0)
	bumper_state["puck_velocity"] = Vector2(0.0, -260.0)
	var bumper_result: Dictionary = Rules.step(bumper_state, Rules.CENTER_X, 0.02)
	var bumper_velocity: Vector2 = bumper_result.get("puck_velocity", Vector2.ZERO)
	_expect(bumper_velocity.y > 0.0, "arena bumper reflects an approaching puck")

	var player_hit_state: Dictionary = Rules.create_state()
	player_hit_state["puck_position"] = Vector2(Rules.CENTER_X, 490.0)
	player_hit_state["puck_velocity"] = Vector2(0.0, 300.0)
	var player_hit_result: Dictionary = Rules.step(player_hit_state, Rules.CENTER_X, 0.05)
	var player_hit_velocity: Vector2 = player_hit_result.get("puck_velocity", Vector2.ZERO)
	_expect(player_hit_velocity.y < 0.0, "swept collision prevents a fast puck tunneling through the player paddle")

	var ai_hit_state: Dictionary = Rules.create_state()
	ai_hit_state["puck_position"] = Vector2(Rules.CENTER_X, 110.0)
	ai_hit_state["puck_velocity"] = Vector2(0.0, -300.0)
	var ai_hit_result: Dictionary = Rules.step(ai_hit_state, Rules.CENTER_X, 0.05)
	var ai_hit_velocity: Vector2 = ai_hit_result.get("puck_velocity", Vector2.ZERO)
	_expect(ai_hit_velocity.y > 0.0, "swept collision prevents a fast puck tunneling through the AI paddle")

	var bottom_goal_state: Dictionary = Rules.create_state()
	bottom_goal_state["puck_position"] = Vector2(Rules.CENTER_X, Rules.BOTTOM - 1.0)
	bottom_goal_state["puck_velocity"] = Vector2(0.0, 300.0)
	var bottom_goal_result: Dictionary = Rules.step(bottom_goal_state, Rules.CENTER_X, 0.05)
	_expect(int(bottom_goal_result.get("ai_score", 0)) == 1, "puck crossing the lower goal awards the opponent")

	var win_state: Dictionary = Rules.create_state()
	for _index in range(Rules.TARGET_SCORE):
		win_state = Rules.award_goal(win_state, true)
	_expect(str(win_state.get("winner", "")) == "PLAYER", "first-to-five rule declares a player winner")
	var locked_state: Dictionary = Rules.award_goal(win_state, false)
	_expect(int(locked_state.get("ai_score", 0)) == 0, "completed match rejects additional score changes")

	var next_arena: Dictionary = Rules.next_arena(initial)
	_expect(int(next_arena.get("arena_index", -1)) == 1, "next-arena action advances the scenario")
	_expect(Rules.get_arena_name(2) == "Split Orbit", "third arena exposes its authored name")
	var reset_state: Dictionary = Rules.reset_match(next_arena)
	_expect(int(reset_state.get("arena_index", -1)) == 1 and int(reset_state.get("player_score", -1)) == 0, "reset preserves the current arena and clears scores")

	if failures.is_empty():
		print("KROLL Flux Hockey rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
