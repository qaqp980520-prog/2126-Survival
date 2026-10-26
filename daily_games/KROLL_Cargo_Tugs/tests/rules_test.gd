extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var level_one: Dictionary = Rules.make_level(0)
	var rows: Array[String] = level_one["rows"]
	var player: Vector2i = level_one["player"]
	var crates: Array[Vector2i] = level_one["crates"]
	var goals: Array[Vector2i] = level_one["goals"]
	assert(rows.size() == Rules.BOARD_SIZE)
	assert(Rules.tile_at(rows, Vector2i(0, 0)) == "#")
	assert(Rules.tile_at(rows, Vector2i(-1, 2)) == "#")
	assert(Rules.is_walkable(rows, player))

	var push_result: Dictionary = Rules.attempt_move(rows, player, crates, Vector2i(1, 0))
	assert(bool(push_result["moved"]))
	assert(push_result["player"] == Vector2i(2, 2))
	assert(push_result["crates"] == [Vector2i(3, 2)])
	assert(not Rules.is_solved(push_result["crates"], goals))

	var blocked_wall: Dictionary = Rules.attempt_move(rows, player, crates, Vector2i(-1, 0))
	assert(not bool(blocked_wall["moved"]))
	var blocked_crate: Dictionary = Rules.attempt_move(rows, Vector2i(5, 2), [Vector2i(6, 2)], Vector2i(1, 0))
	assert(not bool(blocked_crate["moved"]))
	var invalid_diagonal: Dictionary = Rules.attempt_move(rows, player, crates, Vector2i(1, 1))
	assert(not bool(invalid_diagonal["moved"]))
	assert(not bool(Rules.attempt_move(rows, player, crates, Vector2i.ZERO)["moved"]))
	assert(Rules.is_solved([Vector2i(5, 2)], goals))
	assert(not Rules.is_solved([Vector2i(5, 2), Vector2i(4, 2)], goals))

	var level_two: Dictionary = Rules.make_level(1)
	var level_three: Dictionary = Rules.make_level(2)
	assert(level_two["crates"].size() == 2)
	assert(level_three["crates"].size() == 3)
	print("KROLL Cargo Tugs rules tests passed.")
	quit(0)
