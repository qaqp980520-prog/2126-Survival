extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await physics_frame
	_expect(game.call("get_title_text") == "KROLL // TETHER BOT RELAY", "game scene exposes the expected title")
	_expect(int(game.call("get_course_count")) == 3, "game scene exposes three authored courses")
	_expect(int(game.call("get_tether_node_count")) >= 3, "first course exposes at least three tether nodes")
	_expect(int(game.call("get_touch_control_count")) == 6, "game scene exposes six touch controls")
	_expect(str(game.call("get_status")) == "playing", "new campaign starts in playing state")

	var anchor: Vector2 = game.call("get_tether_node_position", 0)
	game.call("set_player_position_for_test", anchor + Vector2(32.0, 0.0))
	_expect(bool(game.call("toggle_tether")), "player can attach to the nearest maintenance node in range")
	_expect(bool(game.call("is_tether_attached")), "successful tether stores the selected maintenance node")
	_expect(int(game.call("get_tether_anchor_index")) == 0, "nearest maintenance node index is deterministic")

	var tether_anchor: Vector2 = game.call("get_tether_node_position", 0)
	game.call("set_player_position_for_test", tether_anchor + Vector2(180.0, 0.0))
	game.call("set_player_velocity_for_test", Vector2(600.0, 0.0))
	for frame_index in range(8):
		await physics_frame
	var constrained_position: Vector2 = game.call("get_player_position")
	var constrained_velocity: Vector2 = game.call("get_player_velocity_for_test")
	var tether_length: float = game.call("get_tether_length")
	var tether_direction: Vector2 = (constrained_position - tether_anchor).normalized()
	_expect(constrained_position.distance_to(tether_anchor) <= tether_length + 1.5, "runtime physics keeps the maintenance drone inside its tether radius")
	_expect(constrained_velocity.dot(tether_direction) <= 3.0, "runtime physics removes outward radial velocity while tethered")

	for course_index in range(3):
		game.call("set_player_position_for_test", game.call("get_goal_center"))
		game.call("check_goal_for_test")
		if course_index < 2:
			_expect(str(game.call("get_status")) == "course_clear", "non-final course enters course_clear state")
		else:
			_expect(str(game.call("get_status")) == "won", "final course completes the campaign")
		var score_after_clear: int = game.call("get_total_score")
		_expect(score_after_clear > 0, "successful course awards a positive score")
		_expect(not bool(game.call("restart_course")), "a passed course cannot be restarted to farm its award")
		_expect(int(game.call("get_total_score")) == score_after_clear, "restart rejection preserves the one-time score")
		if course_index < 2:
			_expect(bool(game.call("advance_course")), "next control advances after a passed course")
			_expect(int(game.call("get_course_index")) == course_index + 1, "course index advances exactly once")

	var final_score: int = game.call("get_total_score")
	_expect(not bool(game.call("advance_course")), "completed campaign cannot advance beyond its final course")
	_expect(not bool(game.call("restart_course")), "completed campaign cannot restart the final course for duplicate score")
	_expect(int(game.call("get_total_score")) == final_score, "terminal campaign keeps its score locked")
	_expect(bool(game.call("restart_campaign")), "explicit fresh-campaign control resets the expedition")
	_expect(int(game.call("get_course_index")) == 0, "fresh campaign returns to the first course")
	_expect(int(game.call("get_total_score")) == 0, "fresh campaign clears the previous campaign score")
	_expect(str(game.call("get_status")) == "playing", "fresh campaign returns to playing state")
	game.call("_register_fall")
	game.call("_register_fall")
	_expect(str(game.call("get_status")) == "playing", "two recovery attempts remain playable")
	game.call("_register_fall")
	_expect(str(game.call("get_status")) == "failed", "third fall ends the course")
	_expect(bool(game.call("restart_course")), "failed course can be retried")
	_expect(str(game.call("get_status")) == "playing", "retry restores the course to playing state")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Tether Bot Relay runtime smoke test passed.")
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
		push_error("FAIL: " + description)
