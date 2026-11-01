extends SceneTree

const GAME_SCENE = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GAME_SCENE.instantiate() as Control
	_expect(game != null, "Strata Mapper main scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its current survey state")
	_expect(game.has_method("select_sample") and game.has_method("move_selected"), "game exposes sample selection and adjacent-swap controls")
	if game.has_method("get_current_state"):
		var state: Dictionary = game.call("get_current_state")
		_expect(str(state.get("level_id", "")) == "delta_basin", "game starts at Delta Basin")
		_expect(str(state.get("status", "")) == "playing", "game starts ready for input")
	var buttons: Array = game.find_children("*", "Button", true, false)
	_expect(buttons.size() == 19, "scene builds twelve sample buttons and seven control buttons")
	_expect(bool(game.call("select_sample", 0, 0)), "runtime can select a visible core sample")
	var before: Dictionary = game.call("get_current_state")
	_expect(bool(game.call("move_selected", 1)), "runtime can swap the selected sample with its neighbor")
	var after: Dictionary = game.call("get_current_state")
	_expect(int(after.get("moves_used", 0)) == int(before.get("moves_used", 0)) + 1, "runtime move increments the move counter exactly once")
	game.call("reset_level")
	_expect(int(game.call("get_current_state").get("moves_used", -1)) == 0, "reset restores the initial move counter")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Strata Mapper runtime smoke test passed.")
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
