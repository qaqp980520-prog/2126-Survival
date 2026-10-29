extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var game: Control = MainScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "scene initializes blueprint state", failures)
	_expect(game.get("_deck_buttons").size() == Rules.SPAN_COUNT, "scene creates five deck controls", failures)
	_expect(game.get("_brace_buttons").size() == Rules.SPAN_COUNT, "scene creates five support controls", failures)
	_expect(game.get_node_or_null("Layout/SpanCards/SpanCard0/DeckButton0") != null, "first span has a named deck button", failures)
	game.call("_set_deck_kind", 0, Rules.DECK_STANDARD)
	_expect(str(game.get("state")["decks"][0]) == Rules.DECK_STANDARD, "scene action installs a standard deck", failures)
	game.call("_toggle_brace", 0)
	_expect(bool(game.get("state")["braces"][0]), "scene action installs an anchored brace", failures)
	game.call("_start_blueprint", 1)
	_expect(int(game.get("state")["seed"]) == 202, "next blueprint advances deterministically", failures)
	var state: Dictionary = game.get("state")
	var anchors: Array = state["anchor_spans"]
	for span in range(Rules.SPAN_COUNT):
		game.call("_set_deck_kind", span, Rules.DECK_STANDARD if anchors.has(span) else Rules.DECK_REINFORCED)
		if anchors.has(span):
			game.call("_toggle_brace", span)
	game.call("_run_load_test")
	_expect(str(game.get("state")["status"]) == "won", "live scene completes a valid bridge load test", failures)
	_expect(game.get("_deck_buttons")[0].disabled, "winning bridge locks deck controls", failures)
	game.call("_start_blueprint", 2)
	_expect(int(game.get("state")["seed"]) == 303 and str(game.get("state")["status"]) == "building", "new blueprint resets the game", failures)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Span Engineer runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
