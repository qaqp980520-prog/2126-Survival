extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for layout_index in range(Rules.LAYOUTS.size()):
		var state: Dictionary = Rules.create_layout(layout_index)
		_expect(not bool(Rules.evaluate(state).get("connected", false)), "layout %d starts scrambled" % layout_index)
		_expect(not Rules.rotate_tile(state, -1), "negative tile index is rejected")
		_expect(not Rules.rotate_tile(state, 999), "out-of-range tile index is rejected")
		_expect(int(state.get("moves", -1)) == 0, "invalid actions do not consume moves")

		var tiles: Array = state["tiles"]
		for tile_index in range(tiles.size()):
			var guard: int = 0
			while not Rules.tile_matches_solution(tiles[tile_index]) and guard < 4:
				_expect(Rules.rotate_tile(state, tile_index), "layout %d accepts a legal clockwise rotation" % layout_index)
				tiles = state["tiles"]
				guard += 1
			_expect(Rules.tile_matches_solution(tiles[tile_index]), "layout %d tile %d reaches its target orientation" % [layout_index, tile_index])
		var result: Dictionary = Rules.evaluate(state)
		_expect(bool(result.get("connected", false)), "layout %d connects source, every pipe and target" % layout_index)
		_expect(int(result.get("visited_tiles", -1)) == tiles.size(), "layout %d powers every pipe segment" % layout_index)
		_expect(bool(state.get("solved", false)), "layout %d locks after completion" % layout_index)
		_expect(int(state.get("moves", 99)) <= Rules.MAX_MOVES, "layout %d stays within the move budget" % layout_index)
		_expect(not Rules.rotate_tile(state, 0), "solved layout %d rejects further edits" % layout_index)

	var budget_state: Dictionary = Rules.create_layout(1)
	for _move in range(Rules.MAX_MOVES):
		_expect(Rules.rotate_tile(budget_state, 0), "unsolved board accepts a rotation while budget remains")
	_expect(int(budget_state.get("moves", -1)) == Rules.MAX_MOVES, "move counter reaches the exact budget")
	var moves_before: int = int(budget_state["moves"])
	_expect(not Rules.rotate_tile(budget_state, 1), "rotation beyond the move budget is rejected")
	_expect(int(budget_state["moves"]) == moves_before, "over-budget action is non-mutating")

	var malformed: Dictionary = Rules.create_layout(0)
	var malformed_tiles: Array = malformed["tiles"]
	var duplicate: Dictionary = malformed_tiles[0].duplicate(true)
	duplicate["cell"] = malformed_tiles[1]["cell"]
	malformed_tiles.append(duplicate)
	malformed["tiles"] = malformed_tiles
	_expect(str(Rules.evaluate(malformed).get("reason", "")) == "invalid_tile_layout", "duplicate pipe coordinates are rejected")

	if failures.is_empty():
		print("KROLL Pipe Relay rules tests passed.")
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
