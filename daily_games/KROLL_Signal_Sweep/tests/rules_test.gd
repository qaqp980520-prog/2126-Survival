extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	_test_manhattan_distance()
	_test_nearest_core_distance()
	_test_empty_core_list()
	_test_difficulty_values()
	_test_cell_bounds()
	print("KROLL Signal Sweep rules tests passed.")
	quit()

func _test_manhattan_distance() -> void:
	assert(Rules.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4)) == 7)
	assert(Rules.manhattan_distance(Vector2i(7, 7), Vector2i(7, 7)) == 0)

func _test_nearest_core_distance() -> void:
	var cores: Array[Vector2i] = [Vector2i(1, 1), Vector2i(6, 5)]
	assert(Rules.nearest_core_distance(Vector2i(2, 3), cores) == 3)
	assert(Rules.nearest_core_distance(Vector2i(7, 7), cores) == 3)

func _test_empty_core_list() -> void:
	var cores: Array[Vector2i] = []
	assert(Rules.nearest_core_distance(Vector2i(0, 0), cores) == -1)

func _test_difficulty_values() -> void:
	assert(Rules.difficulty(0).cores == 2)
	assert(Rules.difficulty(0).scans == 30)
	assert(Rules.difficulty(1).cores == 3)
	assert(Rules.difficulty(1).scans == 22)
	assert(Rules.difficulty(2).cores == 4)
	assert(Rules.difficulty(2).scans == 18)
	assert(Rules.difficulty(-1).is_empty())
	assert(Rules.difficulty(3).is_empty())

func _test_cell_bounds() -> void:
	assert(Rules.is_valid_cell(Vector2i(0, 0)))
	assert(Rules.is_valid_cell(Vector2i(7, 7)))
	assert(not Rules.is_valid_cell(Vector2i(-1, 0)))
	assert(not Rules.is_valid_cell(Vector2i(8, 7)))
