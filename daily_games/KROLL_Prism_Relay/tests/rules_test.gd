extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var puzzle_a: Dictionary = Rules.create_puzzle(0)
	var puzzle_b: Dictionary = Rules.create_puzzle(0)
	_expect(puzzle_a == puzzle_b, "Same puzzle index must create a deterministic state", failures)
	_expect(not bool(Rules.trace_beam(puzzle_a).get("hit_target", false)), "Relay one begins unsolved", failures)
	var puzzle_1: Dictionary = Rules.create_puzzle(1)
	var puzzle_2: Dictionary = Rules.create_puzzle(2)
	_expect(not bool(Rules.trace_beam(puzzle_1).get("hit_target", false)), "Relay two begins unsolved", failures)
	_expect(not bool(Rules.trace_beam(puzzle_2).get("hit_target", false)), "Relay three begins unsolved", failures)
	var invalid_before: Dictionary = puzzle_a.duplicate(true)
	var invalid_result: Dictionary = Rules.apply_rotation(puzzle_a, "0,0")
	_expect(not bool(invalid_result.get("ok", false)), "Non-mirror cell must reject rotation", failures)
	_expect(puzzle_a == invalid_before and invalid_result.get("state", {}) == invalid_before, "Rejected rotation must not mutate puzzle state", failures)
	var step: Dictionary = Rules.apply_rotation(puzzle_a, "2,5")
	_expect(bool(step.get("ok", false)), "First mirror rotation should be accepted", failures)
	puzzle_a = step["state"]
	_expect(str(puzzle_a.get("status", "")) == "playing", "One correct rotation alone must not solve relay one", failures)
	step = Rules.apply_rotation(puzzle_a, "5,5")
	_expect(bool(step.get("ok", false)), "Second mirror rotation should be accepted", failures)
	puzzle_a = step["state"]
	_expect(str(puzzle_a.get("status", "")) == "won", "Two correct rotations should power relay one", failures)
	_expect(bool(Rules.trace_beam(puzzle_a).get("hit_target", false)), "Winning beam must hit the receiver", failures)
	var terminal_snapshot: Dictionary = puzzle_a.duplicate(true)
	var terminal_action: Dictionary = Rules.apply_rotation(puzzle_a, "2,5")
	_expect(not bool(terminal_action.get("ok", false)) and terminal_action.get("state", {}) == terminal_snapshot, "Terminal state must reject further rotations", failures)
	var second: Dictionary = Rules.create_puzzle(1)
	step = Rules.apply_rotation(second, "5,5")
	second = step["state"]
	_expect(str(second.get("status", "")) == "won", "Relay two should solve with one required rotation", failures)
	var third: Dictionary = Rules.create_puzzle(2)
	step = Rules.apply_rotation(third, "2,5")
	third = step["state"]
	_expect(str(third.get("status", "")) == "won", "Relay three should solve with one required rotation", failures)
	var exhausted: Dictionary = Rules.create_puzzle(0)
	for _turn in range(Rules.MAX_TURNS):
		var exhaustion_step: Dictionary = Rules.apply_rotation(exhausted, "2,3")
		if bool(exhaustion_step.get("ok", false)):
			exhausted = exhaustion_step["state"]
	_expect(str(exhausted.get("status", "")) == "failed", "Using all turns without a receiver hit must fail the relay", failures)
	_expect(int(exhausted.get("turns_left", -1)) == 0, "Power budget must stop at zero", failures)
	if failures.is_empty():
		print("KROLL Prism Relay rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
