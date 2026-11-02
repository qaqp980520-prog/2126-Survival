extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules = RulesScript.new()
	_expect(rules.get_planet_count() == 3, "three planetary climate missions are available")
	_expect(rules.calculate_equilibrium_temperature(-1.0, 0.3, 0.4) < 0.0, "negative solar flux is rejected")
	_expect(rules.calculate_equilibrium_temperature(1361.0, 0.9, 0.4) < 0.0, "out-of-range albedo is rejected")
	_expect(rules.calculate_equilibrium_temperature(1361.0, 0.3, 0.9) < 0.0, "out-of-range greenhouse retention is rejected")

	var references: Array[Dictionary] = [
		{"albedo": 0.30, "greenhouse": 0.40, "target": 289.3},
		{"albedo": 0.25, "greenhouse": 0.15, "target": 243.3},
		{"albedo": 0.50, "greenhouse": 0.45, "target": 291.4}
	]
	var state: Dictionary = rules.create_state(0)
	var initial_attempt: Dictionary = rules.simulate(state)
	_expect(not bool(initial_attempt.get("ok", true)) and str(initial_attempt.get("reason", "")) == "outside_target_band", "out-of-band climate submission is rejected")
	state = initial_attempt["state"]
	_expect(str(state.get("status", "")) == "tuning" and int(state.get("score", -1)) == 0, "failed simulation keeps the planet open without awarding points")
	for planet_index in range(3):
		var definition: Dictionary = rules.get_planet_definition(planet_index)
		_expect(not definition.is_empty(), "planet %d exposes its mission brief" % planet_index)
		var reference: Dictionary = references[planet_index]
		var calculated: float = rules.calculate_equilibrium_temperature(
			float(definition["solar_flux"]),
			float(reference["albedo"]),
			float(reference["greenhouse"])
		)
		_expect(absf(calculated - float(reference["target"])) <= 0.1, "planet %d reference settings reproduce the authored target" % planet_index)
		_expect(absf(calculated - float(definition["target_temp_k"])) <= 1.5, "planet %d reference settings are inside the target band" % planet_index)

		var invalid_albedo: Dictionary = rules.set_albedo(state, 0.333)
		_expect(not bool(invalid_albedo.get("ok", true)) and str(invalid_albedo.get("reason", "")) == "invalid_albedo", "unquantized albedo is rejected")
		var set_albedo: Dictionary = rules.set_albedo(state, float(reference["albedo"]))
		_expect(bool(set_albedo.get("ok", false)), "planet %d accepts a calibrated albedo" % planet_index)
		state = set_albedo["state"]
		var set_greenhouse: Dictionary = rules.set_greenhouse(state, float(reference["greenhouse"]))
		_expect(bool(set_greenhouse.get("ok", false)), "planet %d accepts calibrated greenhouse retention" % planet_index)
		state = set_greenhouse["state"]
		var submitted: Dictionary = rules.simulate(state)
		_expect(bool(submitted.get("ok", false)), "planet %d stabilizes inside its target band" % planet_index)
		state = submitted["state"]
		_expect(int(state.get("score", 0)) == (planet_index + 1) * 100, "planet %d awards exactly one hundred points" % planet_index)
		_expect(not bool(rules.simulate(state).get("ok", true)), "planet %d cannot be submitted twice" % planet_index)
		_expect(not bool(rules.restart_planet(state).get("ok", true)), "completed planet %d cannot be reset to farm points" % planet_index)
		if planet_index < 2:
			var advanced: Dictionary = rules.advance_planet(state)
			_expect(bool(advanced.get("ok", false)), "campaign advances after planet %d" % planet_index)
			state = advanced["state"]

	_expect(str(state.get("status", "")) == "campaign_complete", "third planet locks the campaign")
	_expect(int(state.get("score", 0)) == 300, "complete campaign scores exactly three hundred points")
	_expect(not bool(rules.advance_planet(state).get("ok", true)), "completed campaign rejects a fourth planet")
	var restarted: Dictionary = rules.restart_campaign()
	_expect(int(restarted.get("score", -1)) == 0 and int(restarted.get("planet_index", -1)) == 0, "new campaign clears score and returns to Nysa")
	var carried_state: Dictionary = rules.create_state(1, 100)
	var reset_current: Dictionary = rules.restart_planet(carried_state)
	_expect(bool(reset_current.get("ok", false)) and int(reset_current["state"].get("score", -1)) == 100, "restarting an unfinished planet preserves prior campaign points")

	var boundary_state: Dictionary = rules.create_state(0)
	var max_albedo: Dictionary = rules.set_albedo(boundary_state, 0.80)
	_expect(bool(max_albedo.get("ok", false)), "maximum albedo is accepted")
	var over_max: Dictionary = rules.adjust_albedo(max_albedo["state"], 1)
	_expect(not bool(over_max.get("ok", true)) and str(over_max.get("reason", "")) == "invalid_albedo", "albedo cannot exceed its upper bound")
	var max_greenhouse: Dictionary = rules.set_greenhouse(boundary_state, 0.70)
	_expect(bool(max_greenhouse.get("ok", false)), "maximum greenhouse retention is accepted")
	var over_greenhouse: Dictionary = rules.adjust_greenhouse(max_greenhouse["state"], 1)
	_expect(not bool(over_greenhouse.get("ok", true)) and str(over_greenhouse.get("reason", "")) == "invalid_greenhouse", "greenhouse retention cannot exceed its upper bound")
	_expect(rules.get_planet_definition(-1).is_empty() and rules.create_state(99).is_empty(), "invalid planet indexes are rejected")

	if failures.is_empty():
		print("KROLL Planetary Climate Lab rules tests passed.")
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
