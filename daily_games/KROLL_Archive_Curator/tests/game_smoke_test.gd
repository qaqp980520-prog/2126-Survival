extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // ARCHIVE CURATOR", "scene exposes the expected title")
	_expect(int(game.call("get_gallery_count")) == 3, "scene exposes three galleries")
	_expect(int(game.call("get_card_count")) == 6, "scene exposes six archive items")
	_expect(int(game.call("get_slot_count")) == 4, "scene exposes four exhibit cases")
	_expect(int(game.call("get_card_button_count")) == 6, "scene builds six touch-selectable item buttons")
	_expect(int(game.call("get_slot_button_count")) == 4, "scene builds four touch-selectable case buttons")
	_expect(int(game.call("get_action_button_count")) == 4, "scene exposes recall, reset, next and campaign restart controls")
	_expect(str(game.call("get_status")) == "playing", "new campaign starts in playing state")

	_play_layout(game, [0, 1, 2, 3])
	_expect(str(game.call("get_status")) == "gallery_clear", "engineering gallery passes and unlocks the next gallery")
	_expect(int(game.call("get_gallery_score", 0)) == 31, "engineering gallery awards its deterministic score once")
	_expect(not bool(game.call("reset_gallery")), "a passed gallery cannot be reset for duplicate points")
	_expect(bool(game.call("advance_gallery")), "next control advances after a passed gallery")
	_expect(int(game.call("get_current_gallery_index")) == 1, "campaign advances to the life-sciences gallery")

	_play_layout(game, [0, 1, 2, 3])
	_expect(str(game.call("get_status")) == "gallery_clear", "life-sciences gallery passes")
	_expect(int(game.call("get_gallery_score", 1)) == 29, "life-sciences gallery awards its deterministic score")
	_expect(bool(game.call("advance_gallery")), "campaign advances to the exploration gallery")

	_play_layout(game, [0, 1, 3, 5])
	_expect(str(game.call("get_status")) == "won", "final gallery completes the campaign")
	_expect(int(game.call("get_gallery_score", 2)) == 29, "exploration gallery awards its deterministic score")
	var final_score: int = game.call("get_total_score")
	_expect(final_score == 89, "campaign total equals the three gallery awards")
	_expect(not bool(game.call("advance_gallery")), "completed campaign cannot advance beyond its final gallery")
	_expect(not bool(game.call("reset_gallery")), "completed gallery cannot be replayed for duplicate score")
	_expect(int(game.call("get_total_score")) == final_score, "terminal campaign keeps its score locked")

	_expect(bool(game.call("restart_campaign")), "explicit campaign restart is available")
	_expect(int(game.call("get_current_gallery_index")) == 0, "campaign restart returns to the first gallery")
	_expect(int(game.call("get_total_score")) == 0, "campaign restart clears the previous score")
	_expect(str(game.call("get_status")) == "playing", "campaign restart restores playing state")

	_expect(bool(game.call("select_card_for_test", 0)), "first artifact can be selected")
	_expect(bool(game.call("place_selected_for_test", 0)), "selected artifact can be placed into case A")
	_expect(not bool(game.call("select_card_for_test", 0)), "an already displayed artifact cannot be selected again")
	_expect(bool(game.call("select_card_for_test", 1)), "another artifact can be selected")
	_expect(bool(game.call("place_selected_for_test", 1)), "second artifact can be placed")
	_expect(bool(game.call("undo_last")), "recall removes the most recently placed artifact")
	_expect(int(game.call("get_placed_count")) == 1 and int(game.call("get_slot_card", 1)) == -1, "recall restores the case and placement count")
	_expect(int(game.call("get_selected_card")) == 1, "recalled artifact becomes the selected item")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Archive Curator runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _play_layout(game: Control, card_order: Array) -> void:
	for slot_index in range(card_order.size()):
		var card_index: int = card_order[slot_index]
		_expect(bool(game.call("select_card_for_test", card_index)), "select artifact %d" % (card_index + 1))
		_expect(bool(game.call("place_selected_for_test", slot_index)), "place artifact %d in case %d" % [card_index + 1, slot_index + 1])

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
