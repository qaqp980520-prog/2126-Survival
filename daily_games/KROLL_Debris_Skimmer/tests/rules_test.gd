extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	_test_thrust_and_turn()
	_test_speed_cap_and_drag()
	_test_field_wrap()
	_test_tractor_and_dock_ranges()
	_test_sector_progression_and_rewards()
	print("KROLL Debris Skimmer rules tests passed.")
	quit(0)

func _test_thrust_and_turn() -> void:
	var result: Dictionary = Rules.integrate_ship(Vector2(500,300), Vector2.ZERO, 0.0, 1.0, true, false, 1.0 / 60.0)
	assert(Vector2(result["velocity"]).x > 0.0)
	assert(float(result["heading"]) > 0.0)
	var reverse_result: Dictionary = Rules.integrate_ship(Vector2(500,300), Vector2.ZERO, 0.0, 0.0, false, true, 1.0 / 60.0)
	assert(Vector2(reverse_result["velocity"]).x < 0.0)

func _test_speed_cap_and_drag() -> void:
	var result: Dictionary = Rules.integrate_ship(Vector2(500,300), Vector2(900,0), 0.0, 0.0, false, false, 1.0 / 60.0)
	assert(Vector2(result["velocity"]).length() <= Rules.MAX_SPEED + 0.001)
	var drag_result: Dictionary = Rules.integrate_ship(Vector2(500,300), Vector2(100,0), 0.0, 0.0, false, false, 1.0 / 60.0)
	assert(Vector2(drag_result["velocity"]).length() < 100.0)

func _test_field_wrap() -> void:
	var wrapped: Vector2 = Rules.wrap_position(Vector2(Rules.FIELD_RECT.end.x + 8.0, Rules.FIELD_RECT.position.y - 6.0))
	assert(wrapped.x >= Rules.FIELD_RECT.position.x and wrapped.x < Rules.FIELD_RECT.end.x)
	assert(wrapped.y >= Rules.FIELD_RECT.position.y and wrapped.y < Rules.FIELD_RECT.end.y)

func _test_tractor_and_dock_ranges() -> void:
	assert(Rules.can_collect(Vector2.ZERO, Vector2(100,0)))
	assert(not Rules.can_collect(Vector2.ZERO, Vector2(105,0)))
	assert(Rules.can_dock(Rules.DOCK_POSITION + Vector2(60,0)))
	assert(not Rules.can_dock(Rules.DOCK_POSITION + Vector2(70,0)))

func _test_sector_progression_and_rewards() -> void:
	assert(Rules.sector_count() == 3)
	assert(int(Rules.sector_data(0)["target"]) == 3)
	assert(int(Rules.sector_data(1)["target"]) == 4)
	assert(int(Rules.sector_data(2)["target"]) == 5)
	assert(Rules.sector_complete(3,3))
	assert(not Rules.sector_complete(2,3))
	assert(Rules.clear_reward(false) == 100)
	assert(Rules.clear_reward(true) == 0)
