extends SceneTree

const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")
const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert_profiles_and_level_whitelist()
	_assert_window_and_smiler_policies()
	_assert_hound_and_skin_stealer_policies()
	_assert_anchored_and_passive_policies()
	_assert_deathmoth_policy()
	_assert_invalid_perception_is_transactional()
	_assert_deterministic_state_and_elapsed_time()
	await _assert_runtime_perception_gate()

	if failures.is_empty():
		print("Backrooms entity brain tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_profiles_and_level_whitelist() -> void:
	var expected_levels := {
		"window": "Level 1",
		"smiler": "Level 1",
		"hound": "Level 2",
		"skin_stealer": "Level 2",
		"clump": "Level 3",
		"faceling": "Level 3",
		"duller": "Level 4",
		"deathmoth": "Level 5"
	}
	var ids: Array[String] = BrainScript.get_supported_entity_ids()
	_expect(ids.size() == 8, "behavior director exposes exactly eight supported entity IDs")
	for entity_id in ids:
		var brain: Node = BrainScript.new()
		var level_id: String = str(expected_levels.get(entity_id, ""))
		_expect(bool(brain.call("configure", entity_id, level_id, Vector2i(2, -3), 20261118)), "%s configures only on its permitted level" % entity_id)
		var profile: Dictionary = BrainScript.get_behavior_profile(entity_id)
		_expect(not profile.is_empty() and not str(profile.get("role", "")).is_empty(), "%s exposes a named behavior profile" % entity_id)
		_expect(int(brain.call("get_behavior_snapshot").get("behavior_version", 0)) == BrainScript.BEHAVIOR_VERSION, "%s records behavior version one" % entity_id)
		brain.free()

	var wrong_level: Node = BrainScript.new()
	_expect(not bool(wrong_level.call("configure", "hound", "Level 1", Vector2i.ZERO, 1)), "Hound cannot be configured on a level outside its spawn whitelist")
	wrong_level.free()
	var level_zero: Node = BrainScript.new()
	_expect(not bool(level_zero.call("configure", "window", "Level 0", Vector2i.ZERO, 1)), "Level 0 cannot configure an entity brain")
	level_zero.free()
	var unknown: Node = BrainScript.new()
	_expect(not bool(unknown.call("configure", "unknown", "Level 1", Vector2i.ZERO, 1)), "unknown entity IDs are rejected")
	unknown.free()

func _assert_window_and_smiler_policies() -> void:
	var window: Node = _make_brain("window", "Level 1")
	var watched: Dictionary = window.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"is_dark": true
	}, 0.1)
	_expect(bool(watched.get("ok", false)) and str(watched.get("state", "")) == "watch", "Window observes a nearby visible player without becoming a pursuer")
	var hidden_window: Dictionary = window.call("evaluate_perception", {
		"distance_to_player": 2.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(hidden_window.get("state", "")) == "dormant", "Window remains dormant without direct line of sight")
	window.free()

	var smiler: Node = _make_brain("smiler", "Level 1")
	var approach: Dictionary = smiler.call("evaluate_perception", {
		"distance_to_player": 8.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0,
		"is_dark": true
	}, 0.1)
	_expect(str(approach.get("state", "")) == "approach", "Smiler approaches only while dark and not directly observed")
	var freeze: Dictionary = smiler.call("evaluate_perception", {
		"distance_to_player": 8.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"is_dark": true,
		"player_position": Vector3(4.0, 0.0, 2.0)
	}, 0.1)
	_expect(str(freeze.get("state", "")) == "freeze" and bool(freeze.get("has_target_position", false)), "Smiler freezes when seen and retains the observed player position")
	var lit: Dictionary = smiler.call("evaluate_perception", {
		"distance_to_player": 3.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0,
		"is_dark": false
	}, 0.1)
	_expect(str(lit.get("state", "")) == "dormant" and not bool(lit.get("has_target_position", true)), "Smiler becomes dormant in a lit area and clears its target")
	smiler.free()

func _assert_hound_and_skin_stealer_policies() -> void:
	var hound: Node = _make_brain("hound", "Level 2")
	var hound_chase: Dictionary = hound.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.8,
		"noise_distance": 8.0,
		"noise_position": Vector3(7.0, 0.0, 3.0)
	}, 0.1)
	_expect(str(hound_chase.get("state", "")) == "pursue" and bool(hound_chase.get("has_target_position", false)), "Hound pursues a strong nearby sound even without line of sight")
	var hound_investigate: Dictionary = hound.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.3,
		"noise_distance": 18.0
	}, 0.1)
	_expect(str(hound_investigate.get("state", "")) == "investigate", "Hound investigates a moderate sound inside its hearing radius")
	var hound_patrol: Dictionary = hound.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(hound_patrol.get("state", "")) == "patrol", "Hound returns to patrol when no usable signal remains")
	hound.free()

	var skin: Node = _make_brain("skin_stealer", "Level 2")
	var skin_pursue: Dictionary = skin.call("evaluate_perception", {
		"distance_to_player": 8.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(skin_pursue.get("state", "")) == "pursue", "Skin-Stealer pursues a visible player inside its close radius")
	var skin_investigate: Dictionary = skin.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.5,
		"noise_distance": 12.0
	}, 0.1)
	_expect(str(skin_investigate.get("state", "")) == "investigate", "Skin-Stealer investigates a nearby sound when the player is not visible")
	var skin_observe: Dictionary = skin.call("evaluate_perception", {
		"distance_to_player": 15.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(skin_observe.get("state", "")) == "observe", "Skin-Stealer shadows a visible player outside its immediate pursuit radius")
	skin.free()

func _assert_anchored_and_passive_policies() -> void:
	var clump: Node = _make_brain("clump", "Level 3")
	var ambush: Dictionary = clump.call("evaluate_perception", {
		"distance_to_player": 4.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(ambush.get("state", "")) == "ambush", "Clump enters an anchored ambush state for a nearby visible player")
	var anchored: Dictionary = clump.call("evaluate_perception", {
		"distance_to_player": 20.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(anchored.get("state", "")) == "anchored", "Clump remains anchored outside its trigger radius")
	clump.free()

	var faceling: Node = _make_brain("faceling", "Level 3")
	var avoid: Dictionary = faceling.call("evaluate_perception", {
		"distance_to_player": 2.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(avoid.get("state", "")) == "avoid", "Faceling avoids a player who approaches closely")
	var passive: Dictionary = faceling.call("evaluate_perception", {
		"distance_to_player": 12.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(passive.get("state", "")) == "passive", "Faceling remains passive outside its avoidance radius")
	faceling.free()

	var duller: Node = _make_brain("duller", "Level 4")
	var retreat: Dictionary = duller.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(retreat.get("state", "")) == "retreat", "Duller withdraws when the player enters its personal radius")
	var duller_passive: Dictionary = duller.call("evaluate_perception", {
		"distance_to_player": 12.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(duller_passive.get("state", "")) == "passive", "Duller returns to passive state outside its retreat radius")
	duller.free()

func _assert_deathmoth_policy() -> void:
	var deathmoth: Node = _make_brain("deathmoth", "Level 5")
	var pursue: Dictionary = deathmoth.call("evaluate_perception", {
		"distance_to_player": 10.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(pursue.get("state", "")) == "pursue", "Deathmoth pursues a visible player inside its sight radius")
	var investigate: Dictionary = deathmoth.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.6,
		"noise_distance": 18.0
	}, 0.1)
	_expect(str(investigate.get("state", "")) == "investigate", "Deathmoth investigates nearby sound when the player is not visible")
	var patrol: Dictionary = deathmoth.call("evaluate_perception", {
		"distance_to_player": 30.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, 0.1)
	_expect(str(patrol.get("state", "")) == "fly_patrol", "Deathmoth returns to aerial patrol without a usable signal")
	deathmoth.free()

func _assert_invalid_perception_is_transactional() -> void:
	var brain: Node = _make_brain("hound", "Level 2")
	var valid: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"player_position": Vector3(3.0, 0.0, 1.0)
	}, 0.25)
	_expect(bool(valid.get("ok", false)), "valid perception is accepted before invalid-input checks")
	var before: Dictionary = brain.call("get_behavior_snapshot")
	var invalid_distance: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": NAN,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.5)
	_expect(not bool(invalid_distance.get("ok", true)), "non-finite player distance is rejected")
	_expect(brain.call("get_behavior_snapshot") == before, "invalid distance leaves the complete brain snapshot unchanged")
	var invalid_noise: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": false,
		"noise_strength": 1.1
	}, 0.5)
	_expect(not bool(invalid_noise.get("ok", true)), "noise strength outside zero-to-one is rejected")
	_expect(brain.call("get_behavior_snapshot") == before, "invalid noise leaves state, elapsed time and target unchanged")
	var invalid_delta: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}, -0.1)
	_expect(not bool(invalid_delta.get("ok", true)), "negative decision delta is rejected")
	_expect(brain.call("get_behavior_snapshot") == before, "negative delta cannot mutate the current decision")
	var invalid_position: Dictionary = brain.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0,
		"player_position": Vector3(0.0, NAN, 0.0)
	}, 0.5)
	_expect(not bool(invalid_position.get("ok", true)), "non-finite target positions are rejected")
	_expect(brain.call("get_behavior_snapshot") == before, "invalid target positions cannot mutate the current decision")
	brain.free()

func _assert_deterministic_state_and_elapsed_time() -> void:
	var first: Node = _make_brain("hound", "Level 2")
	var second: Node = _make_brain("hound", "Level 2")
	var patrol_input := {
		"distance_to_player": 40.0,
		"has_line_of_sight": false,
		"noise_strength": 0.0
	}
	var first_decision: Dictionary = first.call("evaluate_perception", patrol_input, 0.25)
	var second_decision: Dictionary = second.call("evaluate_perception", patrol_input, 0.25)
	_expect(first_decision.get("state") == second_decision.get("state"), "identical spawn identity and perception produce identical behavior state")
	_expect(first_decision.get("intent") == second_decision.get("intent"), "identical perception produces identical behavior intent")
	var continued: Dictionary = first.call("evaluate_perception", patrol_input, 0.5)
	_expect(is_equal_approx(float(continued.get("state_elapsed_seconds", -1.0)), 0.5), "elapsed time advances only while the same state remains active")
	var changed: Dictionary = first.call("evaluate_perception", {
		"distance_to_player": 5.0,
		"has_line_of_sight": true,
		"noise_strength": 0.0
	}, 0.5)
	_expect(str(changed.get("state", "")) == "pursue" and is_zero_approx(float(changed.get("state_elapsed_seconds", -1.0))), "state transitions reset the state elapsed timer")
	_expect(bool(first.call("reset_behavior")), "configured brain can reset to its entity-specific initial state")
	_expect(str(first.call("get_behavior_snapshot").get("state", "")) == "patrol", "Hound reset restores its initial patrol state")
	first.free()
	second.free()

func _assert_runtime_perception_gate() -> void:
	var runtime: Node3D = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	var prepared: Dictionary = runtime.call("prepare_destination", "Level 1", 20261118, Vector3.ZERO, 8.0, 1)
	_expect(bool(prepared.get("ok", false)), "production runtime prepares a Level 1 test window")
	if not bool(prepared.get("ok", false)):
		runtime.queue_free()
		await process_frame
		return

	var smiler_cell_key: String = ""
	for key_value in runtime.call("get_loaded_cell_keys"):
		var cell_key: String = str(key_value)
		var cell_root: Node3D = runtime.call("get_cell_root", cell_key) as Node3D
		if cell_root == null:
			continue
		for child in cell_root.get_children():
			if child is Node3D and child.get_meta("backrooms_entity_id", "") == "smiler":
				smiler_cell_key = cell_key
				var brain: Node = child.get_node_or_null("AI")
				_expect(brain != null, "production maze entity root owns its configured AI child")
				_expect(child.get_node_or_null("Visuals") == null, "headless runtime keeps the AI logic separate from renderer visuals")
				break
		if not smiler_cell_key.is_empty():
			break
	_expect(not smiler_cell_key.is_empty(), "deterministic Level 1 test window contains a Smiler spawn")
	if not smiler_cell_key.is_empty():
		var inactive_result: Dictionary = runtime.call("submit_entity_perception", smiler_cell_key, "smiler", {
			"distance_to_player": 8.0,
			"has_line_of_sight": false,
			"noise_strength": 0.0,
			"is_dark": true
		}, 0.1)
		_expect(not bool(inactive_result.get("ok", true)) and str(inactive_result.get("reason", "")) == "destination_not_active", "inactive Backrooms runtime rejects entity perception")
		_expect(bool(runtime.call("activate_destination")), "runtime activates before accepting entity perception")
		var approach: Dictionary = runtime.call("submit_entity_perception", smiler_cell_key, "smiler", {
			"distance_to_player": 8.0,
			"has_line_of_sight": false,
			"noise_strength": 0.0,
			"is_dark": true
		}, 0.1)
		_expect(bool(approach.get("ok", false)) and str(approach.get("state", "")) == "approach", "active runtime routes perception into the loaded Smiler brain")
		var freeze: Dictionary = runtime.call("submit_entity_perception", smiler_cell_key, "smiler", {
			"distance_to_player": 8.0,
			"has_line_of_sight": true,
			"noise_strength": 0.0,
			"is_dark": true,
			"player_position": Vector3(2.0, 0.0, 1.0)
		}, 0.1)
		_expect(str(freeze.get("state", "")) == "freeze" and bool(freeze.get("has_target_position", false)), "runtime returns the Smiler's observed target and freeze intent")
		var invalid: Dictionary = runtime.call("submit_entity_perception", smiler_cell_key, "smiler", {
			"distance_to_player": 8.0,
			"has_line_of_sight": true,
			"noise_strength": 2.0,
			"is_dark": true
		}, 0.1)
		_expect(not bool(invalid.get("ok", true)), "runtime forwards invalid perception as a rejected decision")
		var snapshot: Dictionary = runtime.call("submit_entity_perception", smiler_cell_key, "smiler", {
			"distance_to_player": 8.0,
			"has_line_of_sight": true,
			"noise_strength": 0.0,
			"is_dark": true
		}, 0.1)
		_expect(str(snapshot.get("state", "")) == "freeze", "invalid perception does not corrupt the live entity state")
	_expect(bool(runtime.call("deactivate_destination")), "runtime deactivation stops the active entity decision path")
	if not smiler_cell_key.is_empty():
		var after_deactivation: Dictionary = runtime.call("submit_entity_perception", smiler_cell_key, "smiler", {
			"distance_to_player": 8.0,
			"has_line_of_sight": false,
			"noise_strength": 0.0,
			"is_dark": true
		}, 0.1)
		_expect(not bool(after_deactivation.get("ok", true)), "deactivated runtime rejects further perception submissions")
	runtime.queue_free()
	await process_frame

func _make_brain(entity_id: String, level_id: String) -> Node:
	var brain: Node = BrainScript.new()
	_expect(bool(brain.call("configure", entity_id, level_id, Vector2i(2, -3), 20261118)), "%s test brain configures on %s" % [entity_id, level_id])
	return brain

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
