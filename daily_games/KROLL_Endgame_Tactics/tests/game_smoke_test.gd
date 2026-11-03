extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // ENDGAME TACTICS", "scene exposes the expected title")
	_expect(int(game.call("get_puzzle_count")) == 3, "scene exposes three endgame puzzles")
	_expect(int(game.call("get_board_button_count")) == 64, "scene builds all 64 touch-selectable squares")
	_expect(int(game.call("get_control_button_count")) == 3, "scene exposes reset, next and campaign restart controls")
	_expect(str(game.call("get_status")) == "playing", "new campaign starts in playing state")
	_expect(game.find_child("TacticsScroll", true, false) != null, "scene uses a scroll container for narrow touch viewports")

	_expect(bool(game.call("attempt_move", Vector2i(4, 7), Vector2i(4, 6))), "legal non-mating move is accepted for evaluation")
	_expect(int(game.call("get_strikes")) == 1, "non-mating move consumes one attempt")
	_expect(int(game.call("get_score")) == 0, "non-mating move awards no score")
	_expect(bool(game.call("attempt_move", Vector2i(4, 7), Vector2i(4, 0))), "Back-Rank Seal mate is accepted")
	_expect(str(game.call("get_status")) == "solved", "first mate unlocks the next puzzle")
	_expect(int(game.call("get_score")) == 100, "first puzzle awards 100 points once")
	_expect(not bool(game.call("reset_puzzle")), "a solved puzzle cannot be reset for duplicate points")
	_expect(not bool(game.call("attempt_move", Vector2i(4, 7), Vector2i(4, 0))), "a solved puzzle rejects repeated scoring")
	_expect(bool(game.call("advance_puzzle")), "next control advances after a solved puzzle")
	_expect(int(game.call("get_current_puzzle_index")) == 1, "campaign advances to Reverse File")

	_expect(bool(game.call("attempt_move", Vector2i(3, 0), Vector2i(3, 7))), "Reverse File mate is accepted")
	_expect(str(game.call("get_status")) == "solved", "second mate unlocks the final puzzle")
	_expect(int(game.call("get_score")) == 200, "second puzzle adds exactly 100 points")
	_expect(bool(game.call("advance_puzzle")), "campaign advances to Side-File Lock")
	_expect(bool(game.call("attempt_move", Vector2i(0, 4), Vector2i(7, 4))), "Side-File Lock mate is accepted")
	_expect(str(game.call("get_status")) == "won", "final mate completes the campaign")
	_expect(int(game.call("get_score")) == 300, "perfect campaign score is 300")
	_expect(not bool(game.call("advance_puzzle")), "completed campaign cannot advance beyond the final puzzle")
	_expect(not bool(game.call("reset_puzzle")), "final solved puzzle cannot be replayed for duplicate score")

	_expect(bool(game.call("restart_campaign")), "explicit campaign restart is available")
	_expect(int(game.call("get_current_puzzle_index")) == 0, "campaign restart returns to the first puzzle")
	_expect(int(game.call("get_score")) == 0, "campaign restart clears the previous score")
	_expect(str(game.call("get_status")) == "playing", "campaign restart restores playing state")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Endgame Tactics runtime smoke test passed.")
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
