extends SceneTree

const MainScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	_expect(game.get("state") is Dictionary, "scene initializes ecosystem state")
	_expect(game.get("status_label") is Label and game.get("ecosystem_label") is Label, "status and ecosystem labels exist")
	var picker: OptionButton = game.get("zone_picker") as OptionButton
	_expect(picker != null and picker.item_count == 3, "three habitat choices exist")
	var buttons: Dictionary = game.get("action_buttons")
	for key in ["plant", "grazer", "water", "cull", "end", "restart", "next"]:
		_expect(buttons.has(key), "control exists: " + key)
	_expect(buttons["plant"].name == "PlantButton" and buttons["cull"].name == "CullButton", "intervention controls have stable names")

	for seed_index in range(Rules.SEEDS.size()):
		var state: Dictionary = game.get("state")
		var seed_value: int = int(state.get("seed", -1))
		for round_index in range(Rules.MAX_TURNS):
			if round_index == 0:
				_apply(game, Rules.ACTION_GRAZER, "CANOPY")
				_apply(game, Rules.ACTION_PLANT, "WETLAND")
			elif round_index == 1:
				_apply(game, Rules.ACTION_GRAZER, "WETLAND")
				_apply(game, Rules.ACTION_CULL, "MEADOW")
			else:
				_apply(game, Rules.ACTION_CULL, "MEADOW")
				_apply(game, Rules.ACTION_CULL, "WETLAND")
			var turn_result: Dictionary = game.call("_end_turn")
			_expect(bool(turn_result.get("ok", false)), "scene advances seed %d turn %d" % [seed_value, round_index + 1])
		_expect(str(game.get("state").get("status", "")) == "won", "live scene completes seed %d survey" % seed_value)
		if seed_index < Rules.SEEDS.size() - 1:
			game.call("next_layout")
	game.call("restart_game")
	_expect(str(game.get("state").get("status", "")) == "playing" and int(game.get("state").get("turn", 0)) == 1, "restart resets current layout")
	game.call("next_layout")
	_expect(int(game.get("state").get("seed", -1)) == 17, "next layout advances deterministically")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Biome Balance runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _apply(game: Control, action_name: String, zone_name: String) -> void:
	var state: Dictionary = game.get("state")
	var zone_index: int = Rules.zone_index_for_name(state, zone_name)
	var result: Dictionary = game.call("_perform_action_for", zone_index, action_name)
	_expect(bool(result.get("ok", false)), "scene applies %s to %s" % [action_name, zone_name])

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
