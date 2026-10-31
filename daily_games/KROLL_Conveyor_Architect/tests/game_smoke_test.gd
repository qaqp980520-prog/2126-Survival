extends SceneTree

const GameScene = preload("res://main.tscn")
const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Conveyor Architect scene loads")
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its current route state")
	_expect(game.has_method("apply_conveyor") and game.has_method("advance_cargo"), "game exposes conveyor and cargo actions")
	_expect(str(game.call("get_current_level")) == "dock_line", "game starts at Dock Line")
	_expect(game.find_child("FactoryGrid", true, false) is GridContainer, "factory grid is available for mouse and touch")
	var path: Array[Vector2i] = RulesScript.get_solution_path(0)
	for path_index in range(path.size() - 1):
		var direction: int = RulesScript.direction_between(path[path_index], path[path_index + 1])
		var place_result: Dictionary = game.call("apply_conveyor", path[path_index], direction)
		_expect(bool(place_result.get("ok", false)), "runtime accepts route conveyor %d" % path_index)
	for step_index in range(path.size() + 1):
		if str(game.call("get_current_state").get("status", "")) == "delivered":
			break
		game.call("advance_cargo")
	var state: Dictionary = game.call("get_current_state")
	_expect(str(state.get("status", "")) == "delivered", "runtime cargo reaches the receiving dock")
	_expect(bool(game.call("advance_level")), "runtime advances after successful delivery")
	_expect(str(game.call("get_current_level")) == "coolant_bend", "runtime loads the next work order")
	game.call("reset_level")
	_expect(str(game.call("get_current_level")) == "coolant_bend", "runtime reset preserves the current work order")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Conveyor Architect runtime smoke test passed.")
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
		push_error("FAIL: " + description)
