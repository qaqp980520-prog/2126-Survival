extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var vent: Dictionary = Rules.apply_action([52.0, 50.0, 48.0], [35.0, 40.0, 38.0], 0, "vent")
	assert(bool(vent.get("ok", false)))
	assert(is_equal_approx(float(vent["outputs"][0]), 40.0))
	assert(is_equal_approx(float(vent["heats"][0]), 17.0))

	var boost: Dictionary = Rules.apply_action([52.0, 50.0, 48.0], [35.0, 40.0, 38.0], 2, "boost")
	assert(bool(boost.get("ok", false)))
	assert(is_equal_approx(float(boost["outputs"][2]), 58.0))
	assert(is_equal_approx(float(boost["heats"][2]), 50.0))

	assert(not bool(Rules.apply_action([50.0], [20.0], 0, "vent").get("ok", false)))
	assert(not bool(Rules.apply_action([50.0, 50.0, 50.0], [20.0, 20.0, 20.0], 3, "vent").get("ok", false)))
	assert(not bool(Rules.apply_action([50.0, 50.0, 50.0], [20.0, 20.0, 20.0], 0, "ignite").get("ok", false)))

	var advanced: Dictionary = Rules.advance([99.0, 1.0, 50.0], [99.0, 2.0, 20.0], [5.0, -5.0, 0.0], 1.0)
	assert(bool(advanced.get("ok", false)))
	assert(is_equal_approx(float(advanced["outputs"][0]), 100.0))
	assert(is_equal_approx(float(advanced["outputs"][1]), 0.0))
	assert(Rules.is_overheated(advanced["heats"]))
	assert(Rules.is_grid_stable([45.0, 50.0, 45.0]))
	assert(not Rules.is_grid_stable([10.0, 20.0, 30.0]))
	assert(not bool(Rules.advance([50.0, 50.0, 50.0], [20.0, 20.0, 20.0], [0.0, 0.0, 0.0], 0.0).get("ok", false)))
	print("KROLL Reactor Balance rules tests passed.")
	quit(0)
