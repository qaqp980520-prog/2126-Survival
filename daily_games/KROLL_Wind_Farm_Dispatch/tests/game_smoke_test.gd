extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Wind Farm Dispatch scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its deterministic dispatch state")
	_expect(game.has_method("commit_current_round"), "game exposes the round commit action")
	_expect(game.has_method("get_turbine_card_count") and game.get_turbine_card_count() == 3, "game builds three interactive turbine cards")
	var state: Dictionary = game.call("get_current_state")
	_expect(str(state.get("status", "")) == "playing", "game starts in an active dispatch round")
	_expect(str(game.call("get_current_scenario").get("id", "")) == "north_array", "standalone scene starts North Array")
	_expect(bool(game.call("commit_current_round")), "on-screen round commit action resolves the first weather window")
	state = game.call("get_current_state")
	_expect(int(state.get("round_index", 0)) == 1, "committing a round advances the scenario")
	_expect(state.get("history", []).size() == 1, "committing a round appends an audit record")
	game.call("_reset_scenario")
	state = game.call("get_current_state")
	_expect(int(state.get("round_index", -1)) == 0, "reset button path restores the first round")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Wind Farm Dispatch runtime smoke test passed.")
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
