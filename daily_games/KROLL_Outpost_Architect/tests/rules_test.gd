extends SceneTree

const Rules = preload("res://rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.layout_count() == 3, "three deterministic outpost layouts are available")
	for layout_index in range(Rules.layout_count()):
		var state: Dictionary = Rules.new_game(layout_index)
		_expect(state.get("hand", []).size() == Rules.HAND_SIZE, "new game starts with a three-card hand")
		_expect(int(state.get("energy", -1)) == Rules.STARTING_ENERGY, "new game starts with the configured energy budget")
		for cell_index in range(Rules.PLACEMENT_LIMIT):
			var placement: Dictionary = Rules.place_module(state, 0, cell_index)
			_expect(bool(placement.get("ok", false)), "authored first-card route places module %d in layout %d" % [cell_index, layout_index])
		_expect(str(state.get("result", "")) == "won", "authored route wins layout %d" % layout_index)
		_expect(int(state.get("score", 0)) == Rules.target_score(layout_index), "authored route reaches the exact target score for layout %d" % layout_index)
		_expect(int(state.get("energy", -1)) == 4, "authored route stays within the energy budget")
		_expect(int(state.get("turns_left", -1)) == 0, "authored route uses exactly eight placements")
		_expect(not bool(Rules.place_module(state, 0, 8).get("ok", false)), "completed outpost rejects further placement")
	_test_rejected_actions()

	if failures.is_empty():
		print("KROLL Outpost Architect rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_rejected_actions() -> void:
	var state: Dictionary = Rules.new_game(0)
	_expect(not bool(Rules.place_module(state, 0, -1).get("ok", false)), "negative cell index is rejected")
	_expect(not bool(Rules.place_module(state, 0, Rules.BOARD_CELLS).get("ok", false)), "cell index beyond the board is rejected")
	_expect(state.get("board", {}).is_empty(), "invalid cell attempts do not mutate the board")
	_expect(not bool(Rules.place_module(state, -1, 0).get("ok", false)), "negative hand index is rejected")
	_expect(not bool(Rules.place_module(state, Rules.HAND_SIZE, 0).get("ok", false)), "hand index beyond the hand is rejected")

	var occupied_state: Dictionary = Rules.new_game(0)
	_expect(bool(Rules.place_module(occupied_state, 0, 0).get("ok", false)), "first legal placement succeeds")
	var hand_before: Array = occupied_state["hand"].duplicate()
	_expect(not bool(Rules.place_module(occupied_state, 0, 0).get("ok", false)), "occupied cell rejects a second module")
	_expect(occupied_state["hand"] == hand_before and occupied_state["board"].size() == 1, "occupied-cell rejection is side-effect free")

	var energy_state: Dictionary = Rules.new_game(0)
	energy_state["energy"] = 0
	var energy_hand_before: Array = energy_state["hand"].duplicate()
	_expect(not bool(Rules.place_module(energy_state, 1, 1).get("ok", false)), "insufficient energy rejects a module")
	_expect(energy_state["hand"] == energy_hand_before and energy_state["board"].is_empty(), "energy rejection does not consume a card or cell")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
