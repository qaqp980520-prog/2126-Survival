extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules = RulesScript.new()
	_test_invalid_inputs_do_not_mutate_state(rules)
	_test_fixed_seed_physics_is_deterministic(rules)
	_test_three_stones_resolve_a_round(rules)
	_test_collisions_and_rink_bounds(rules)
	_test_campaign_progression_and_restart(rules)
	if failures.is_empty():
		print("KROLL Orbital Curling rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _test_invalid_inputs_do_not_mutate_state(rules: Variant) -> void:
	var state: Dictionary = rules.new_campaign()
	var before: Dictionary = state.duplicate(true)
	var zero_aim: Dictionary = rules.throw_stone(state, Vector2.ZERO, 180.0)
	_expect(not bool(zero_aim.get("ok", false)) and str(zero_aim.get("reason", "")) == "invalid_aim", "zero aim is rejected")
	_expect(state == before, "invalid aim leaves the campaign unchanged")
	var low_power: Dictionary = rules.throw_stone(state, Vector2.RIGHT, 20.0)
	_expect(not bool(low_power.get("ok", false)) and str(low_power.get("reason", "")) == "invalid_power", "out-of-range power is rejected")
	_expect(state == before, "invalid power leaves the campaign unchanged")

func _test_fixed_seed_physics_is_deterministic(rules: Variant) -> void:
	var first: Dictionary = rules.new_campaign()
	var second: Dictionary = rules.new_campaign()
	var first_result: Dictionary = rules.throw_stone(first, Vector2(1.0, -0.2), 285.0)
	var second_result: Dictionary = rules.throw_stone(second, Vector2(1.0, -0.2), 285.0)
	_expect(bool(first_result.get("ok", false)) and bool(second_result.get("ok", false)), "same valid throw is accepted in two fresh campaigns")
	_expect(first_result.get("state", {}) == second_result.get("state", {}), "fixed-step physics produces identical results")

func _test_three_stones_resolve_a_round(rules: Variant) -> void:
	var state: Dictionary = rules.new_campaign()
	for shot_index in range(3):
		var result: Dictionary = rules.throw_stone(state, Vector2.RIGHT, 300.0)
		_expect(bool(result.get("ok", false)), "shot %d is accepted" % (shot_index + 1))
		state = result.get("state", state)
	_expect(int(state.get("shots_left", -1)) == 0, "three shots consume the round allowance")
	_expect(str(state.get("status", "")) == "round_complete", "third shot completes a non-final round")
	_expect(state.get("round_scores", []).size() == 1, "completed round records exactly one score")
	_expect(int(state.get("round_score", -1)) in [0, 10, 20, 30], "round score uses one of the authored distance bands")

func _test_collisions_and_rink_bounds(rules: Variant) -> void:
	var state: Dictionary = rules.new_campaign()
	for _shot_index in range(3):
		var result: Dictionary = rules.throw_stone(state, Vector2(1.0, 0.0), 340.0)
		if bool(result.get("ok", false)):
			state = result["state"]
	var stones: Array = state.get("stones", [])
	_expect(stones.size() == 3, "three stones remain on the rink after a collision sequence")
	for stone_value in stones:
		var stone: Dictionary = stone_value
		var position: Vector2 = stone.get("position", Vector2.ZERO)
		_expect(position.x >= rules.get_rink_min().x + rules.get_stone_radius() and position.x <= rules.get_rink_max().x - rules.get_stone_radius(), "stone stays within horizontal rink bounds")
		_expect(position.y >= rules.get_rink_min().y + rules.get_stone_radius() and position.y <= rules.get_rink_max().y - rules.get_stone_radius(), "stone stays within vertical rink bounds")
	for first in range(stones.size()):
		for second in range(first + 1, stones.size()):
			var a: Vector2 = stones[first]["position"]
			var b: Vector2 = stones[second]["position"]
			_expect(a.distance_to(b) >= rules.get_stone_radius() * 2.0 - 0.75, "settled stones do not overlap")
 
func _test_campaign_progression_and_restart(rules: Variant) -> void:
	var state: Dictionary = rules.new_campaign()
	for round_index in range(rules.get_round_count()):
		for _shot_index in range(rules.get_shots_per_round()):
			var result: Dictionary = rules.throw_stone(state, Vector2.RIGHT, 250.0)
			_expect(bool(result.get("ok", false)), "campaign throw is accepted")
			state = result.get("state", state)
		if round_index < rules.get_round_count() - 1:
			var next_result: Dictionary = rules.advance_round(state)
			_expect(bool(next_result.get("ok", false)), "completed round advances to the next target")
			state = next_result.get("state", state)
	_expect(state.get("round_scores", []).size() == 3, "campaign records three round scores")
	_expect(int(state.get("total_score", -1)) >= 0 and int(state.get("total_score", -1)) <= 90, "campaign score stays within 0–90")
	_expect(str(state.get("status", "")) in ["won", "complete"], "third round ends the campaign")
	if str(state.get("status", "")) == "complete":
		_expect(not str(state.get("message", "")).contains("CAMPAIGN CLEARED"), "below-goal campaign does not claim a win")
	var restarted: Dictionary = rules.restart_campaign()
	_expect(int(restarted.get("round_index", -1)) == 0 and int(restarted.get("shots_left", -1)) == 3, "restart returns to the first round with three throws")
	_expect(restarted.get("stones", []).is_empty() and int(restarted.get("total_score", -1)) == 0, "restart clears stones and score")

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
