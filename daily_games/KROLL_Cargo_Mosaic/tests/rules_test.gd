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
		var candidates_by_piece: Dictionary = {}
		for piece_id in Rules.get_piece_ids():
			candidates_by_piece[piece_id] = _candidate_placements(level_index, piece_id)
		assert(_count_solutions(level_index, 0, {}, candidates_by_piece) == 1, "Each bay must have exactly one distinct exact-cover packing.")
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

func _candidate_placements(level_index: int, piece_id: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for rotation in range(4):
		for y in range(Rules.BOARD_HEIGHT):
			for x in range(Rules.BOARD_WIDTH):
				var origin := Vector2i(x, y)
				var check: Dictionary = Rules.can_place(level_index, {}, piece_id, origin, rotation)
				if not bool(check.get("ok", false)):
					continue
				var key: String = _cells_key(check["cells"])
				if seen.has(key):
					continue
				seen[key] = true
				candidates.append({"origin": origin, "rotation": rotation})
	return candidates

func _cells_key(cells: Array) -> String:
	var parts: Array[String] = []
	for cell in cells:
		parts.append("%d,%d" % [cell.x, cell.y])
	parts.sort()
	return "|".join(parts)

func _count_solutions(level_index: int, piece_index: int, placements: Dictionary, candidates_by_piece: Dictionary) -> int:
	var piece_ids: Array[String] = Rules.get_piece_ids()
	if piece_index >= piece_ids.size():
		return 1 if Rules.is_solved(level_index, placements) else 0
	var piece_id: String = piece_ids[piece_index]
	var total := 0
	for candidate in candidates_by_piece[piece_id]:
		var result: Dictionary = Rules.place_piece(
			level_index, placements, piece_id, candidate["origin"], int(candidate["rotation"])
		)
		if bool(result.get("ok", false)):
			total += _count_solutions(level_index, piece_index + 1, result["placements"], candidates_by_piece)
	return total
