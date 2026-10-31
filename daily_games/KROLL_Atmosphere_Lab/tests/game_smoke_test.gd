extends SceneTree
const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameScene.instantiate()
	_expect(game != null, "Atmosphere Lab scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_expect(game.has_method("get_current_state"), "game exposes its deterministic station state")
	var initial: Dictionary = game.call("get_current_state")
	_expect(str(initial.get("level_id", "")) == "coastal_front", "game starts at Coastal Front")
	_expect(game.find_child("TemperatureMinus", true, false) != null, "temperature decrement control exists")
	_expect(game.find_child("PressurePlus", true, false) != null, "pressure increment control exists")
	var minus := game.find_child("TemperatureMinus", true, false) as Button
	if minus != null:
		minus.emit_signal("pressed")
	var adjusted: Dictionary = game.call("get_current_state")
	_expect(int(adjusted["readings"]["temperature"]) == 25 and int(adjusted["actions_used"]) == 1, "instrument button applies one deterministic adjustment")
	game.call("_reset")
	var reset_state: Dictionary = game.call("get_current_state")
	_expect(int(reset_state["actions_used"]) == 0, "reset restores the station action budget")
	var level: Dictionary = Rules.get_level(0)
	var solved: Dictionary = Rules.new_game(0)
	for instrument in Rules.INSTRUMENTS:
		var current: int = int(solved["readings"][instrument])
		var target: int = int(level["target"][instrument])
		var direction: int = 1 if target > current else -1
		while current != target:
			solved = Rules.adjust(solved, instrument, direction)
			current = int(solved["readings"][instrument])
	game.set("_state", solved)
	game.call("_refresh")
	var next_button := game.find_child("NextButton", true, false) as Button
	_expect(next_button != null and not next_button.disabled, "stable forecast unlocks the next-station control")
	if next_button != null:
		next_button.emit_signal("pressed")
	var next_state: Dictionary = game.call("get_current_state")
	_expect(int(next_state.get("level_index", -1)) == 1, "next-station control advances to Desert Thermal")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Atmosphere Lab runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
