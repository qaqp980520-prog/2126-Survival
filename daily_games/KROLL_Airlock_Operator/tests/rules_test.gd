extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var initial: Dictionary = Rules.new_game()
	_expect(int(initial.get("pods_exterior",0)) == 3, "new shift starts with three cargo pods")
	_expect(int(initial.get("oxygen",0)) == 60, "new shift starts with a bounded oxygen reserve")
	var rejected: Dictionary = Rules.apply_action(initial, "open_inner")
	_expect(not bool(rejected.get("ok",false)) and str(rejected.get("reason","")) == "airlock_empty", "inner door refuses to open without cargo")
	_expect(initial == Rules.new_game(), "rejected action leaves state unchanged")
	var state: Dictionary = Rules.apply_action(initial,"open_outer")["state"]
	var blocked: Dictionary = Rules.apply_action(state,"pressurize")
	_expect(not bool(blocked.get("ok",false)) and str(blocked.get("reason","")) == "door_open", "pressure valve is locked while a door is open")
	_expect(not bool(Rules.apply_action(state,"open_inner").get("ok",false)), "opposite door cannot open while outer door is open")
	state = Rules.apply_action(state,"load_pod")["state"]
	_expect(int(state.get("pods_airlock",-1)) == 1 and int(state.get("oxygen",-1)) == 55, "loading moves one pod and consumes five oxygen")
	state = Rules.apply_action(state,"close_outer")["state"]
	var pressure_mismatch: Dictionary = Rules.apply_action(state,"open_inner")
	_expect(not bool(pressure_mismatch.get("ok",false)) and str(pressure_mismatch.get("reason","")) == "pressure_mismatch", "inner door refuses a 100 kPa pressure difference")
	_expect(int(state.get("airlock_pressure",-1)) == 0 and not bool(state.get("inner_open",true)), "pressure mismatch rejection leaves the airlock unchanged")
	state = Rules.apply_action(state,"pressurize")["state"]
	state = Rules.apply_action(state,"pressurize")["state"]
	state = Rules.apply_action(state,"open_inner")["state"]
	state = Rules.apply_action(state,"unload_pod")["state"]
	_expect(int(state.get("pods_delivered",-1)) == 1 and int(state.get("oxygen",-1)) == 50, "inner transfer delivers one pod and consumes oxygen")
	var solution: Array[String] = [
		"open_outer","load_pod","close_outer","pressurize","pressurize","open_inner","unload_pod","close_inner",
		"vent","vent","open_outer","load_pod","close_outer","pressurize","pressurize","open_inner","unload_pod","close_inner",
		"vent","vent","open_outer","load_pod","close_outer","pressurize","pressurize","open_inner","unload_pod","close_inner"
	]
	var winning: Dictionary = Rules.new_game()
	for action in solution:
		var result: Dictionary = Rules.apply_action(winning,action)
		_expect(bool(result.get("ok",false)), "solution accepts " + action)
		if bool(result.get("ok",false)):
			winning = result["state"]
	_expect(str(winning.get("result","")) == "won", "three-pod solution wins")
	_expect(int(winning.get("actions",-1)) == 28 and int(winning.get("oxygen",-1)) == 30, "solution uses 28 actions and retains 30 oxygen")
	_expect(not bool(winning.get("outer_open",true)) and not bool(winning.get("inner_open",true)), "winning solution closes both doors")
	_expect(not bool(Rules.apply_action(winning,"pressurize").get("ok",false)), "completed shift rejects further actions")
	var oxygen: Dictionary = Rules.apply_action(Rules.new_game(),"recycle_oxygen")
	_expect(bool(oxygen.get("ok",false)) and int(oxygen["state"].get("oxygen",0)) == 80, "oxygen recycler restores twenty points")
	var exhausted: Dictionary = Rules.new_game()
	for index in range(14):
		exhausted = Rules.apply_action(exhausted,"pressurize")["state"]
		exhausted = Rules.apply_action(exhausted,"vent")["state"]
	_expect(str(exhausted.get("result","")) == "lost", "action budget eventually ends an incomplete shift")
	if failures.is_empty():
		print("KROLL Airlock Operator rules tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
