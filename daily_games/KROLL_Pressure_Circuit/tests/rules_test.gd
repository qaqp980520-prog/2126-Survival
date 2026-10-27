extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.create_puzzle(2701)
	var second: Dictionary = Rules.create_puzzle(2701)
	_expect(first.get("masks", []) == second.get("masks", []), "same seed creates the same scrambled board")
	_expect(first.get("path", []).size() == 9, "solution path has nine connected pipe cells")
	_expect(not Rules.is_solved(first), "scrambled puzzle does not start solved")

	var mask := Rules.DIR_N
	for _turn in range(4):
		mask = Rules.rotate_mask(mask)
	_expect(mask == Rules.DIR_N, "four clockwise turns restore the original connector")

	var corner := Rules.DIR_N | Rules.DIR_E
	_expect(Rules.rotate_mask(corner) == (Rules.DIR_E | Rules.DIR_S), "clockwise rotation preserves elbow geometry")
	_expect(not Rules.rotate_tile(first, Vector2i(-1, 2)), "out-of-board rotation is rejected")
	_expect(not Rules.rotate_tile(first, Vector2i(5, 5)), "empty tile rotation is rejected")
	_expect(int(first.get("moves", -1)) == 0, "rejected rotations do not consume moves")

	var solved: Dictionary = Rules.create_puzzle(2701)
	solved["masks"] = (solved["solution_masks"] as Array).duplicate()
	_expect(Rules.is_solved(solved), "the stored solution connects source to target")

	var blocked: Dictionary = Rules.create_puzzle(2702)
	var blocked_masks: Array = blocked["masks"]
	for index in range(blocked_masks.size()):
		blocked_masks[index] = 0
	var source: Vector2i = blocked["source"]
	blocked_masks[source.y * Rules.COLS + source.x] = Rules.DIR_N
	_expect(not Rules.is_solved(blocked), "a source with no reciprocal neighbour cannot reach the target")
	for _move in range(Rules.MAX_MOVES):
		_expect(Rules.rotate_tile(blocked, source), "rotation is accepted while moves remain")
	_expect(Rules.is_failed(blocked), "reaching the move limit without a route fails the puzzle")
	_expect(not Rules.rotate_tile(blocked, source), "rotation after the move limit is rejected")
	_expect(int(blocked.get("moves", -1)) == Rules.MAX_MOVES, "move count never exceeds the configured limit")

	print("KROLL Pressure Circuit rules tests passed." if failures.is_empty() else "KROLL Pressure Circuit rules tests failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
