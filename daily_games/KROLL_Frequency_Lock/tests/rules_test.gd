extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var secret: Array[int] = Rules.generate_secret(24027)
	_expect(secret.size() == Rules.CODE_LENGTH, "secret uses the required code length")
	_expect(Rules.is_valid_guess(secret), "generated secret has unique symbols in range")
	_expect(Rules.generate_secret(24027) == secret, "secret generation is deterministic for a seed")

	var score: Dictionary = Rules.score_guess([1, 2, 3, 4], [1, 3, 2, 6])
	_expect(bool(score.get("valid", false)), "valid guess is scored")
	_expect(int(score.get("exact", -1)) == 1, "exact-position feedback is correct")
	_expect(int(score.get("misplaced", -1)) == 2, "misplaced-symbol feedback is correct")
	var all_misplaced: Dictionary = Rules.score_guess([1, 2, 3, 4], [4, 3, 2, 1])
	_expect(int(all_misplaced.get("exact", -1)) == 0 and int(all_misplaced.get("misplaced", -1)) == 4, "fully rearranged code reports four misplaced symbols")

	_expect(not Rules.is_valid_guess([1, 1, 2, 3]), "duplicate symbols are rejected")
	_expect(not Rules.is_valid_guess([1, 2, 3]), "short guesses are rejected")
	_expect(not Rules.is_valid_guess([1, 2, 3, 7]), "out-of-bank symbols are rejected")
	_expect(not Rules.is_valid_guess([1, 2, 3, 4.5]), "fractional symbols are rejected")

	var state: Dictionary = Rules.create_state([1, 2, 3, 4])
	var invalid_result: Dictionary = Rules.submit_guess(state, [1, 1, 2, 3])
	_expect(not bool(invalid_result.get("accepted", true)), "invalid guess is not accepted")
	_expect(int(state.get("attempts_left", -1)) == Rules.MAX_ATTEMPTS, "invalid guess does not consume an attempt")
	_expect((state.get("guesses", []) as Array).is_empty(), "invalid guess does not enter history")

	var winning_state: Dictionary = Rules.create_state([1, 2, 3, 4])
	var win_result: Dictionary = Rules.submit_guess(winning_state, [1, 2, 3, 4])
	_expect(bool(win_result.get("accepted", false)), "valid winning guess is accepted")
	_expect(str(winning_state.get("status", "")) == "won", "exact code wins the round")
	var after_win: Dictionary = Rules.submit_guess(winning_state, [4, 3, 2, 1])
	_expect(not bool(after_win.get("accepted", true)), "terminal state rejects later guesses")

	var losing_state: Dictionary = Rules.create_state([1, 2, 3, 4])
	for attempt in range(Rules.MAX_ATTEMPTS):
		var result: Dictionary = Rules.submit_guess(losing_state, [6, 5, 4, 3])
		_expect(bool(result.get("accepted", false)), "valid wrong guess is accepted on attempt %d" % (attempt + 1))
	_expect(str(losing_state.get("status", "")) == "lost", "eighth wrong guess causes lockout")
	_expect(int(losing_state.get("attempts_left", -1)) == 0, "lockout leaves zero attempts")
	print("KROLL Frequency Lock rules tests passed." if failures.is_empty() else "KROLL Frequency Lock rules tests failed.")
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
