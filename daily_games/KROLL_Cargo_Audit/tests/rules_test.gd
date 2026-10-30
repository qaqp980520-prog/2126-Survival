extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_case_count() == 3, "three deterministic cargo audit cases exist")
	_expect(Rules.validate_all_cases(), "each case contains exactly one discrepancy outside its certified field")
	var manifest: Dictionary = Rules.get_case(0)
	var manifest_containers: Array = manifest.get("containers", [])
	_expect(not manifest_containers.is_empty() and not manifest_containers[0].has("actual_mass"), "player-facing manifest never exposes hidden sensor readings")
	_expect(not manifest.has("anomaly_container") and not manifest.has("anomaly_field"), "player-facing case projection hides the answer metadata")

	var state: Dictionary = Rules.create_state()
	_expect(int(state.get("scans_left", -1)) == 8 and int(state.get("attempts_left", -1)) == 2, "case starts with eight scans and two accusations")
	var certified: Dictionary = Rules.scan(0, state, 0, "seal")
	_expect(str(certified.get("reason", "")) == "certified_field" and int(state.get("scans_used", -1)) == 0, "certified field cannot waste a scan")
	var first_scan: Dictionary = Rules.scan(0, state, 0, "mass")
	_expect(bool(first_scan.get("ok", false)) and not bool(first_scan.get("record", {}).get("mismatch", true)), "matching sensor scan is recorded")
	var duplicate: Dictionary = Rules.scan(0, state, 0, "mass")
	_expect(str(duplicate.get("reason", "")) == "already_scanned" and int(state.get("scans_used", -1)) == 1, "duplicate scan is rejected without spending budget")
	var anomaly_scan: Dictionary = Rules.scan(0, state, 1, "mass")
	_expect(bool(anomaly_scan.get("ok", false)) and bool(anomaly_scan.get("record", {}).get("mismatch", false)), "sensor identifies the altered container mass")
	var solved: Dictionary = Rules.accuse(0, state, 1, "mass")
	_expect(bool(solved.get("ok", false)) and str(state.get("status", "")) == "cleared", "correct container and field clear the audit")
	_expect(int(state.get("score", 0)) > 0, "efficient audit produces a positive score")

	var wrong_state: Dictionary = Rules.create_state()
	var wrong_one: Dictionary = Rules.accuse(1, wrong_state, 0, "seal")
	_expect(not bool(wrong_one.get("ok", true)) and int(wrong_state.get("attempts_left", -1)) == 1, "incorrect accusation consumes one attempt")
	var wrong_two: Dictionary = Rules.accuse(1, wrong_state, 0, "seal")
	_expect(str(wrong_state.get("status", "")) == "failed" and int(wrong_state.get("attempts_left", -1)) == 0, "second incorrect accusation ends the case")

	var exhausted_state: Dictionary = Rules.create_state()
	exhausted_state["scans_left"] = 0
	var exhausted: Dictionary = Rules.scan(0, exhausted_state, 0, "count")
	_expect(str(exhausted.get("reason", "")) == "scan_budget_exhausted", "scan budget cannot be exceeded")
	var invalid: Dictionary = Rules.scan(0, Rules.create_state(), 9, "mass")
	_expect(str(invalid.get("reason", "")) == "invalid_selection", "invalid container selection is rejected")

	if failures.is_empty():
		print("KROLL Cargo Audit rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
