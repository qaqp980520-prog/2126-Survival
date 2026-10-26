extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	_test_board_bounds()
	_test_build_validation()
	_test_wave_scaling()
	print("KROLL Core Defense rules tests passed.")
	quit(0)

func _test_board_bounds() -> void:
	assert(Rules.is_inside_board(Vector2i(0, 0)))
	assert(Rules.is_inside_board(Vector2i(12, 7)))
	assert(not Rules.is_inside_board(Vector2i(-1, 0)))
	assert(not Rules.is_inside_board(Vector2i(13, 7)))
	assert(not Rules.is_inside_board(Vector2i(0, 8)))

func _test_build_validation() -> void:
	var path: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]
	var towers: Array[Vector2i] = [Vector2i(2, 1)]
	assert(Rules.TOWER_COST == 35)
	assert(Rules.can_build(Vector2i(1, 1), path, towers, 80))
	assert(not Rules.can_build(Vector2i(1, 3), path, towers, 80))
	assert(not Rules.can_build(Vector2i(2, 1), path, towers, 80))
	assert(not Rules.can_build(Vector2i(1, 1), path, towers, 34))
	assert(not Rules.can_build(Vector2i(13, 1), path, towers, 80))

func _test_wave_scaling() -> void:
	assert(Rules.wave_enemy_count(1) == 6)
	assert(Rules.wave_enemy_count(2) == 8)
	assert(Rules.wave_enemy_count(3) == 10)
	assert(Rules.enemy_health_for_wave(1) == 1)
	assert(Rules.enemy_health_for_wave(3) == 2)
	assert(Rules.enemy_speed_for_wave(3) > Rules.enemy_speed_for_wave(1))
