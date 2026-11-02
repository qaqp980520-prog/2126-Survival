extends SceneTree

const RulesScript = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules: RefCounted = RulesScript.new()
	_expect(rules.get_sample_count() == 3, "three unknown acid samples are available")
	var expected_endpoints: Array[float] = [20.0, 30.0, 40.0]
	var concentrations: Array[float] = [0.08, 0.12, 0.16]
	for sample_index in range(3):
		var definition: Dictionary = rules.get_sample_definition(sample_index)
		_expect(not definition.is_empty(), "sample %d exposes its safe lab brief" % sample_index)
		_expect(is_equal_approx(float(rules.get_reference_endpoint_ml(sample_index)), expected_endpoints[sample_index]), "sample %d has the authored equivalence volume" % sample_index)
		var expected_initial_ph: float = -log(concentrations[sample_index]) / log(10.0)
		_expect(is_equal_approx(float(rules.calculate_ph(sample_index, 0.0)), expected_initial_ph), "sample %d starts at the calculated strong-acid pH" % sample_index)
		_expect(is_equal_approx(float(rules.calculate_ph(sample_index, expected_endpoints[sample_index])), 7.0), "sample %d reaches neutral pH at equivalence" % sample_index)
		_expect(float(rules.calculate_ph(sample_index, expected_endpoints[sample_index] + 5.0)) > 7.0, "sample %d becomes basic after equivalence" % sample_index)
		var initial: Dictionary = rules.create_state(sample_index)
		var valid_addition: Dictionary = rules.add_titrant(initial, 0.5)
		_expect(bool(valid_addition.get("ok", false)), "sample %d accepts a calibrated 0.5 mL addition" % sample_index)
		var invalid_addition: Dictionary = rules.add_titrant(initial, 0.25)
		_expect(not bool(invalid_addition.get("ok", true)), "sample %d rejects an uncalibrated addition size" % sample_index)
		_expect(not bool(rules.submit_endpoint(initial).get("ok", true)), "sample %d rejects an early endpoint submission" % sample_index)

	var state: Dictionary = rules.create_state(0)
	for sample_index in range(3):
		var endpoint: float = float(rules.get_reference_endpoint_ml(sample_index))
		while float(state.get("volume_added_ml", 0.0)) < endpoint:
			var added: Dictionary = rules.add_titrant(state, 2.5)
			_expect(bool(added.get("ok", false)), "campaign accepts measured additions")
			state = added["state"]
		var submitted: Dictionary = rules.submit_endpoint(state)
		_expect(bool(submitted.get("ok", false)), "sample %d captures its endpoint" % sample_index)
		state = submitted["state"]
		_expect(int(state.get("score", 0)) == (sample_index + 1) * 100, "sample %d awards exactly one hundred points" % sample_index)
		_expect(not bool(rules.restart_sample(state).get("ok", true)), "completed sample %d cannot be reset to farm points" % sample_index)
		if sample_index < 2:
			var advanced: Dictionary = rules.advance_sample(state)
			_expect(bool(advanced.get("ok", false)), "campaign advances after sample %d" % sample_index)
			state = advanced["state"]
	_expect(str(state.get("status", "")) == "campaign_complete", "third sample locks the campaign")
	_expect(not bool(rules.submit_endpoint(state).get("ok", true)), "completed campaign rejects another endpoint submission")
	_expect(not bool(rules.advance_sample(state).get("ok", true)), "completed campaign rejects a fourth sample")
	var restarted: Dictionary = rules.restart_campaign()
	_expect(int(restarted.get("score", -1)) == 0 and int(restarted.get("sample_index", -1)) == 0, "new campaign resets score and returns to Sample A")
	_expect(rules.get_reference_endpoint_ml(-1) < 0.0 and rules.get_sample_definition(99).is_empty(), "invalid sample indexes are rejected")

	if failures.is_empty():
		print("KROLL Titration Bench rules tests passed.")
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
