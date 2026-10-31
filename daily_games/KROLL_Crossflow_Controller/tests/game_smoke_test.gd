extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate()
	_expect(game != null, "Crossflow Controller scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes a state snapshot")
	_expect(game.has_method("set_signal_axis"), "game exposes signal controls")
	_expect(game.has_method("step_once"), "game exposes deterministic tick advancement")
	_expect(game.has_method("reset_level"), "game exposes shift reset")
	if game.has_method("set_paused"):
		game.call("set_paused", true)
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("level_id", "")) == "depot_rush", "game starts the Depot Rush shift")
	_expect(str(initial.get("phase", "")) == Rules.PHASE_NS_GREEN, "north/south starts green")
	_expect(bool(game.call("set_signal_axis", Rules.AXIS_EW)), "UI controller accepts an east/west signal request")
	var pending: Dictionary = game.call("get_current_state")
	_expect(str(pending.get("phase", "")) == Rules.PHASE_CLEARANCE, "UI controller enters all-red clearance")
	game.call("step_once")
	var switched: Dictionary = game.call("get_current_state")
	_expect(str(switched.get("phase", "")) == Rules.PHASE_EW_GREEN, "manual tick completes the signal transition")
	game.call("reset_level")
	var reset_state: Dictionary = game.call("get_current_state")
	_expect(int(reset_state.get("tick", -1)) == 0 and str(reset_state.get("phase", "")) == Rules.PHASE_NS_GREEN, "reset restores the first shift state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Crossflow Controller runtime smoke test passed.")
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
