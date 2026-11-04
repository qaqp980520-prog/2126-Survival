extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_test_sensor_contract()
	_test_power_cell_contract()
	_test_pump_contract()
	_test_rejected_actions_are_immutable()
	_test_action_limit_and_advance_guard()
	_test_reward_once_and_restart()
	if failures.is_empty():
		print("KROLL Orbital Foundry rules tests passed.")
		quit(0)
	else:
		push_error("KROLL Orbital Foundry rules failures: " + str(failures))
		quit(1)

func _test_sensor_contract() -> void:
	var state: Dictionary = Rules.new_state()
	var missing: Dictionary = Rules.apply_recipe(state, "sensor_array")
	_expect(not bool(missing.get("accepted", false)), "sensor cannot be built before its ingredients")
	_expect(missing.get("state", {}) == state, "missing ingredients leave the state unchanged")
	state = _apply(state, "circuit_board")
	state = _apply(state, "glass_lens")
	state = _apply(state, "sensor_array")
	_expect(str(state.get("status", "")) == "completed", "sensor calibration work order completes")
	_expect(int(state.get("energy", -1)) == 0, "sensor chain consumes exactly six energy")
	_expect(int(state.get("campaign_score", 0)) == 100, "first completed work order awards 100 points")
	_expect(int(state.get("inventory", {}).get("sensor_array", 0)) == 1, "sensor array is produced")

func _test_power_cell_contract() -> void:
	var state: Dictionary = Rules.new_state(1)
	state = _apply(state, "alloy_plate")
	state = _apply(state, "circuit_board")
	state = _apply(state, "power_cell")
	_expect(str(state.get("status", "")) == "completed", "emergency power-cell work order completes")
	_expect(int(state.get("energy", -1)) == 0, "power-cell chain consumes exactly nine energy")
	_expect(int(state.get("inventory", {}).get("power_cell", 0)) == 1, "power cell is produced")

func _test_pump_contract() -> void:
	var state: Dictionary = Rules.new_state(2)
	state = _apply(state, "alloy_plate")
	state = _apply(state, "circuit_board")
	state = _apply(state, "circuit_board")
	state = _apply(state, "coolant_pump")
	_expect(str(state.get("status", "")) == "completed", "pressure-transfer pump work order completes")
	_expect(int(state.get("energy", -1)) == 0, "pump chain consumes exactly thirteen energy")
	_expect(int(state.get("inventory", {}).get("coolant_pump", 0)) == 1, "coolant pump is produced")

func _test_rejected_actions_are_immutable() -> void:
	var state: Dictionary = Rules.new_state()
	state["energy"] = 0
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Rules.apply_recipe(state, "circuit_board")
	_expect(not bool(result.get("accepted", false)), "insufficient energy rejects a recipe")
	_expect(result.get("state", {}) == before, "insufficient energy does not mutate the state")
	state = Rules.new_state()
	state["inventory"]["silica"] = 0
	before = state.duplicate(true)
	result = Rules.apply_recipe(state, "glass_lens")
	_expect(not bool(result.get("accepted", false)), "missing raw materials reject a recipe")
	_expect(result.get("state", {}) == before, "missing materials do not consume energy or stock")

func _test_action_limit_and_advance_guard() -> void:
	var state: Dictionary = Rules.new_state()
	state["actions"] = int(state.get("action_limit", 0))
	var result: Dictionary = Rules.apply_recipe(state, "circuit_board")
	_expect(not bool(result.get("accepted", false)), "action limit rejects additional production")
	_expect(result.get("state", {}) == state, "action-limit rejection is immutable")
	var premature: Dictionary = Rules.advance(Rules.new_state())
	_expect(not bool(premature.get("accepted", false)), "next contract cannot be loaded before completion")

func _test_reward_once_and_restart() -> void:
	var state: Dictionary = Rules.new_state()
	state = _apply(state, "circuit_board")
	state = _apply(state, "glass_lens")
	state = _apply(state, "sensor_array")
	var restarted: Dictionary = Rules.restart_level(state)
	_expect(int(restarted.get("campaign_score", 0)) == 100, "restarting a completed level preserves campaign score")
	restarted = _apply(restarted, "circuit_board")
	restarted = _apply(restarted, "glass_lens")
	restarted = _apply(restarted, "sensor_array")
	_expect(int(restarted.get("campaign_score", 0)) == 100, "replaying a completed level cannot duplicate its reward")
	var fresh: Dictionary = Rules.restart_campaign()
	_expect(int(fresh.get("campaign_score", -1)) == 0, "new campaign resets score")
	_expect(fresh.get("completed_levels", {}).is_empty(), "new campaign clears completion ledger")

func _apply(state: Dictionary, recipe_id: String) -> Dictionary:
	var result: Dictionary = Rules.apply_recipe(state, recipe_id)
	_expect(bool(result.get("accepted", false)), "recipe %s is accepted" % recipe_id)
	return result.get("state", state)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
