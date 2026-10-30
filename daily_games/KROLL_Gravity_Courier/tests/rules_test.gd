extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run()
	if failures.is_empty():
		print("KROLL Gravity Courier rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _run() -> void:
	var state: Dictionary = Rules.new_game()
	_expect(int(state.get("gravity_sign", 0)) == 1, "new mission starts with downward gravity")
	var flipped: Dictionary = Rules.flip_gravity(state)
	_expect(bool(flipped.get("ok", false)) and int(flipped["state"]["gravity_sign"]) == -1, "gravity flip reverses direction")
	_expect(int(state["gravity_sign"]) == 1, "gravity flip does not mutate the input snapshot")
	var duplicate_flip: Dictionary = Rules.flip_gravity(flipped["state"])
	_expect(int(duplicate_flip["state"]["gravity_sign"]) == 1, "second flip restores downward gravity")
	var invalid: Dictionary = Rules.collect_cargo(state, "unknown")
	_expect(not bool(invalid.get("ok", false)) and str(invalid.get("reason", "")) == "unknown_cargo", "unknown cargo IDs are rejected")
	var early_exit: Dictionary = Rules.try_exit(state)
	_expect(not bool(early_exit.get("ok", false)) and str(early_exit.get("reason", "")) == "cargo_missing", "exit remains locked until all cargo is collected")
	var current: Dictionary = state
	for cargo_id in Rules.CARGO_IDS:
		var collected: Dictionary = Rules.collect_cargo(current, cargo_id)
		_expect(bool(collected.get("ok", false)), "valid cargo can be collected: " + cargo_id)
		current = collected["state"]
	var duplicate: Dictionary = Rules.collect_cargo(current, "cargo_1")
	_expect(not bool(duplicate.get("ok", false)) and str(duplicate.get("reason", "")) == "already_collected", "duplicate cargo collection is rejected")
	var won: Dictionary = Rules.try_exit(current)
	_expect(bool(won.get("ok", false)) and str(won["state"]["result"]) == "won", "exit opens after all four cargo cells are secured")
	var after_win: Dictionary = Rules.flip_gravity(won["state"])
	_expect(not bool(after_win.get("ok", false)) and str(after_win.get("reason", "")) == "finished", "terminal mission rejects further gravity changes")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
