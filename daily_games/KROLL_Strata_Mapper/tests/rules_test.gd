extends SceneTree

const RULES_LOCAL_PATH: String = "res://rules.gd"
const RULES_ROOT_PATH: String = "res://daily_games/KROLL_Strata_Mapper/rules.gd"
var failures: Array[String] = []
var rules: RefCounted

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules_path: String = RULES_ROOT_PATH if ResourceLoader.exists(RULES_ROOT_PATH) else RULES_LOCAL_PATH
	var rules_script: Script = load(rules_path) as Script
	_expect(rules_script != null, "stratigraphy rules module loads")
	if rules_script == null:
		quit(1)
		return
	rules = rules_script.new() as RefCounted
	_expect(int(rules.call("get_site_count")) == 3, "three geological survey sites are available")
	_expect(str(rules.call("get_site_data", 0).get("id", "")) == "delta_basin", "first site is Delta Basin")
	_expect(str(rules.call("get_site_data", 2).get("id", "")) == "crater_shelf", "third site is Crater Shelf")
	var invalid_negative: Dictionary = rules.call("make_state", -1)
	var invalid_high: Dictionary = rules.call("make_state", 3)
	_expect(invalid_negative.is_empty(), "negative site index is rejected")
	_expect(invalid_high.is_empty(), "out-of-range site index is rejected")

	for site_index in range(int(rules.call("get_site_count"))):
		var state: Dictionary = rules.call("make_state", site_index)
		_expect(str(state.get("status", "")) == "playing", "site starts in the playing state")
		_expect(int(state.get("moves_left", 0)) == 18, "site receives an eighteen-swap budget")
		_expect(not bool(rules.call("is_solved", state)), "shuffled core columns do not start solved")
		var progress: Dictionary = rules.call("get_progress", state)
		_expect(int(progress.get("total_slots", 0)) == 12, "three four-sample cores create twelve stratigraphic slots")
		_expect(not bool(progress.get("marker_aligned", true)), "initial marker beds are deliberately misaligned")
		var before_invalid: Dictionary = state.duplicate(true)
		var invalid_move: Dictionary = rules.call("move_sample", state, 0, 0, -1)
		_expect(not bool(invalid_move.get("ok", true)) and invalid_move.get("state", {}) == before_invalid, "moving the bottom sample down is rejected without mutation")
		var invalid_direction: Dictionary = rules.call("move_sample", state, 0, 0, 0)
		_expect(not bool(invalid_direction.get("ok", true)), "zero-distance sample movement is rejected")
		_expect(rules.call("advance_state", state).is_empty(), "a site cannot advance before its cores are solved")

		for core_index in range(3):
			var core_state: Dictionary = state.get("cores", [])[core_index]
			var target: Array = core_state.get("target", [])
			for target_index in range(target.size()):
				core_state = state.get("cores", [])[core_index]
				var samples: Array = core_state.get("samples", [])
				var found_index: int = samples.find(target[target_index])
				while found_index > target_index:
					var result: Dictionary = rules.call("move_sample", state, core_index, found_index, -1)
					_expect(bool(result.get("ok", false)), "adjacent swap moves a sample toward its correct age position")
					state = result.get("state", state)
					found_index -= 1
		_expect(str(state.get("status", "")) == "won", "deterministic adjacent-swap solution completes each site")
		_expect(bool(rules.call("is_solved", state)), "all three target core sequences and marker positions match")
		_expect(int(state.get("moves_used", 99)) <= 18, "authored solution fits the move budget")
		_expect(bool(rules.call("get_progress", state).get("marker_aligned", false)), "all three volcanic ash marker beds align at the target depth")
		var next_state: Dictionary = rules.call("advance_state", state)
		if site_index < 2:
			_expect(int(next_state.get("site_index", -1)) == site_index + 1, "winning a site advances to the next survey")
			_expect(str(next_state.get("status", "")) == "playing", "next survey resets its own move budget")
		else:
			_expect(str(next_state.get("status", "")) == "complete", "winning the final site completes the survey campaign")

	var selection_state: Dictionary = rules.call("make_state", 0)
	var selected: Dictionary = rules.call("select_sample", selection_state, 2, 3)
	_expect(bool(selected.get("ok", false)), "sample selection accepts a valid core and layer")
	_expect(int(selected.get("state", {}).get("selected_core", -1)) == 2 and int(selected.get("state", {}).get("selected_sample", -1)) == 3, "selection state stores the chosen core and layer")
	var zero_budget: Dictionary = selection_state.duplicate(true)
	zero_budget["moves_left"] = 0
	var exhausted: Dictionary = rules.call("move_sample", zero_budget, 0, 0, 1)
	_expect(not bool(exhausted.get("ok", true)) and str(exhausted.get("reason", "")) == "move_budget_exhausted", "move budget cannot be overdrawn")
	var reset_state: Dictionary = rules.call("make_state", 1)
	_expect(str(reset_state.get("level_id", "")) == "ridge_cut" and int(reset_state.get("moves_left", 0)) == 18, "resetting a site restores its authored shuffled layout")
	_expect(str(rules.call("get_layer_label", "ash_marker")) == "VOLCANIC ASH", "shared marker has a readable sample label")
	_expect(str(rules.call("get_layer_color", "basalt")).begins_with("#"), "sample palette exposes valid hex colors")

	if failures.is_empty():
		print("KROLL Strata Mapper rules tests passed.")
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
