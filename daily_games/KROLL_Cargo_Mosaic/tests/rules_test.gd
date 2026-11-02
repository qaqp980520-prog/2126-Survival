extends SceneTree

const Rules = preload("res://rules.gd")
const FIXTURES: Array[Array] = [
	[{"id":"ION","origin":Vector2i(1,1),"rotation":3},{"id":"FORK","origin":Vector2i(2,4),"rotation":0},{"id":"HOOK","origin":Vector2i(4,0),"rotation":0},{"id":"CORE","origin":Vector2i(2,1),"rotation":0}],
	[{"id":"ION","origin":Vector2i(1,2),"rotation":0},{"id":"FORK","origin":Vector2i(0,3),"rotation":1},{"id":"HOOK","origin":Vector2i(4,3),"rotation":2},{"id":"CORE","origin":Vector2i(3,4),"rotation":2}],
	[{"id":"ION","origin":Vector2i(5,2),"rotation":1},{"id":"FORK","origin":Vector2i(1,1),"rotation":1},{"id":"HOOK","origin":Vector2i(2,4),"rotation":3},{"id":"CORE","origin":Vector2i(3,1),"rotation":0}]
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Rules.get_level_count() == 3)
	assert(Rules.get_piece_ids().size() == 4)
	for piece_id in Rules.get_piece_ids():
		assert(Rules.get_piece_cells(piece_id, 0).size() == 4)
	assert(Rules.get_piece_cells("ION", 0) == Rules.get_piece_cells("ION", 4))
	assert(Rules.get_level_data(-1).is_empty())
	assert(Rules.get_level_data(3).is_empty())
	for level_index in range(3):
		assert(Rules.get_level_data(level_index)["target_cells"].size() == 16)
		var placements: Dictionary = {}
		for fixture in FIXTURES[level_index]:
			var result: Dictionary = Rules.place_piece(level_index, placements, fixture["id"], fixture["origin"], fixture["rotation"])
			assert(bool(result.get("ok", false)), "authored packing must be valid: %s" % str(result))
			placements = result["placements"]
		assert(Rules.is_solved(level_index, placements))
		assert(Rules.remove_piece(placements, "CORE").size() == 3)
		assert(not Rules.is_solved(level_index, Rules.remove_piece(placements, "CORE")))
	var first: Dictionary = Rules.place_piece(0, {}, "ION", Vector2i(1,1), 3)
	assert(bool(first.get("ok", false)))
	assert(Rules.can_place(0, {}, "ION", Vector2i(-1,0), 0)["reason"] == "outside_board")
	assert(Rules.can_place(0, {}, "ION", Vector2i(0,0), 0)["reason"] == "blocked_cell")
	assert(Rules.can_place(0, first["placements"], "CORE", Vector2i(1,1), 0)["reason"] == "overlap")
	assert(Rules.can_place(0, first["placements"], "ION", Vector2i(4,0), 0)["reason"] == "already_placed")
	assert(not Rules.is_solved(0, first["placements"]))
	print("KROLL Cargo Mosaic rules tests passed.")
	quit(0)
