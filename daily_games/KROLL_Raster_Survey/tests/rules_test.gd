extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules := Rules.new()
	assert(rules.get_puzzle_count() == 3)
	var first: Dictionary = rules.get_puzzle(0)
	assert(first.get("id", "") == "delta_relay")
	assert(rules.get_row_clues(first) == [[2], [4], [6], [2, 2], [4], [2]])
	assert(rules.get_column_clues(first) == [[2], [4], [3, 2], [3, 2], [4], [2]])
	assert(rules.get_puzzle(99).is_empty())
	var state: Dictionary = rules.make_state(0)
	assert(state.size() == 4)
	assert(not rules.is_solved(state))
	assert(not rules.advance_state(state).get("ok", false))
	assert(not rules.mark_cell(state, -1, 0, 1).get("ok", false))
	assert(not rules.mark_cell(state, 0, 0, 3).get("ok", false))
	for puzzle_index in range(rules.get_puzzle_count()):
		state = rules.make_state(puzzle_index)
		var puzzle: Dictionary = rules.get_puzzle(puzzle_index)
		var rows: Array = puzzle["rows"]
		for y in range(6):
			for x in range(6):
				var mark: int = 1 if str(rows[y]).substr(x, 1) == "1" else 2
				var result: Dictionary = rules.mark_cell(state, x, y, mark)
				assert(result.get("ok", false))
				state = result["state"]
		assert(rules.is_solved(state))
		assert(str(state["status"]) == "solved")
		assert(int(state["moves"]) == 36)
		var progress: Dictionary = rules.get_progress(state)
		assert(int(progress["marked"]) == 36 and bool(progress["solved"]))
		if puzzle_index < rules.get_puzzle_count() - 1:
			var next: Dictionary = rules.advance_state(state)
			assert(next.get("ok", false))
			state = next["state"]
			assert(int(state["puzzle_index"]) == puzzle_index + 1)
			assert(int(state["moves"]) == 0)
		else:
			var finish: Dictionary = rules.advance_state(state)
			assert(finish.get("ok", false))
			assert(str(finish["state"]["status"]) == "campaign_complete")
	var reset: Dictionary = rules.reset_state(rules.make_state(1))
	assert(int(reset["puzzle_index"]) == 1)
	assert(int(reset["moves"]) == 0)
	assert(not rules.is_solved(reset))
	print("KROLL Raster Survey rules tests passed.")
	quit(0)
