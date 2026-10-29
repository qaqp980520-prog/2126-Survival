extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = Rules.new_game(17)
	var repeated: Dictionary = Rules.new_game(17)
	_expect(first == repeated, "same seed creates the same ecosystem state")
	_expect(Rules.new_game(17)["zones"] != Rules.new_game(29)["zones"], "different seeds produce different habitat orders")
	_expect(first.get("zones", []).size() == 3, "game starts with three habitats")
	_expect(int(first.get("actions_left", 0)) == Rules.ACTIONS_PER_TURN, "two interventions are available each turn")

	var invalid_zone: Dictionary = Rules.perform_action(first, -1, Rules.ACTION_PLANT)
	_expect(not bool(invalid_zone.get("ok", false)) and invalid_zone.get("reason") == "invalid_zone", "invalid habitat index is rejected")
	_expect(first == invalid_zone.get("state", {}), "invalid action does not mutate the source state")
	var invalid_action: Dictionary = Rules.perform_action(first, 0, "terraform")
	_expect(not bool(invalid_action.get("ok", false)) and first == invalid_action.get("state", {}), "unknown intervention is rejected without mutation")

	var action_state: Dictionary = first
	var canopy_index: int = Rules.zone_index_for_name(action_state, "CANOPY")
	action_state = _do(action_state, Rules.ACTION_GRAZER, "CANOPY")
	action_state = _do(action_state, Rules.ACTION_PLANT, "WETLAND")
	var third_action: Dictionary = Rules.perform_action(action_state, canopy_index, Rules.ACTION_WATER)
	_expect(not bool(third_action.get("ok", false)) and third_action.get("reason") == "no_actions_left", "third intervention in one turn is rejected")
	_expect(int(action_state.get("actions_left", -1)) == 0, "rejected third intervention leaves the action budget intact")

	for seed_value in Rules.SEEDS:
		var state: Dictionary = Rules.new_game(seed_value)
		for round_index in range(Rules.MAX_TURNS):
			if round_index == 0:
				state = _do(state, Rules.ACTION_GRAZER, "CANOPY")
				state = _do(state, Rules.ACTION_PLANT, "WETLAND")
			elif round_index == 1:
				state = _do(state, Rules.ACTION_GRAZER, "WETLAND")
				state = _do(state, Rules.ACTION_CULL, "MEADOW")
			else:
				state = _do(state, Rules.ACTION_CULL, "MEADOW")
				state = _do(state, Rules.ACTION_CULL, "WETLAND")
			var turn_result: Dictionary = Rules.end_turn(state)
			_expect(bool(turn_result.get("ok", false)), "seed %d round %d advances" % [seed_value, round_index + 1])
			state = turn_result.get("state", state)
		_expect(str(state.get("status", "")) == "won", "seed %d accepts a stable ecosystem plan" % seed_value)
		_expect(int(state.get("actions_used", 0)) == 12, "seed %d counts all twelve interventions" % seed_value)

	var idle: Dictionary = Rules.new_game(17)
	for _turn in range(Rules.MAX_TURNS):
		var idle_result: Dictionary = Rules.end_turn(idle)
		idle = idle_result.get("state", idle)
	_expect(str(idle.get("status", "")) == "failed", "ignoring predator pressure eventually fails the survey")
	var terminal: Dictionary = Rules.perform_action(idle, 0, Rules.ACTION_PLANT)
	_expect(not bool(terminal.get("ok", false)) and terminal.get("reason") == "terminal", "terminal ecosystem cannot be edited")
	if failures.is_empty():
		print("KROLL Biome Balance rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _do(state: Dictionary, action_name: String, zone_name: String) -> Dictionary:
	var zone_index: int = Rules.zone_index_for_name(state, zone_name)
	var result: Dictionary = Rules.perform_action(state, zone_index, action_name)
	_expect(bool(result.get("ok", false)), "seed %d %s action in %s succeeds" % [int(state.get("seed", -1)), action_name, zone_name])
	return result.get("state", state)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
