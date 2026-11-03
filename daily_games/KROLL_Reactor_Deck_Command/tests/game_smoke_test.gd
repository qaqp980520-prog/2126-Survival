extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = MainScene
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // REACTOR DECK COMMAND", "scene displays the Reactor Deck Command title")
	_expect(game.call("get_encounter_count") == 3, "scene exposes three encounters")
	_expect(game.call("get_card_button_count") == 5, "scene builds five card buttons")
	_expect(game.call("get_status_text") == "playing", "new campaign begins in playing state")
	_expect(game.call("get_hand_card_count") == 5, "new campaign displays a five-card hand")
	_expect(game.call("get_score") == 0, "new campaign begins with zero score")
	_expect(bool(game.call("play_card", 0)), "first visible card can be played")
	_expect(bool(game.call("end_turn")), "end-turn control resolves the enemy action")
	_expect(int(game.call("get_turn_number")) == 2, "end-turn control advances to turn two")
	_expect(bool(game.call("restart_campaign")), "restart control creates a fresh campaign")
	_expect(game.call("get_status_text") == "playing", "restarted campaign returns to playing state")
	_expect(int(game.call("get_score")) == 0, "restarted campaign clears the score")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Reactor Deck Command runtime smoke test passed.")
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
