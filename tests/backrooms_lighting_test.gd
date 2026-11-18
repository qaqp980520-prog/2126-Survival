extends SceneTree

const ProfileScript = preload("res://systems/BackroomsLightingProfile.gd")
const ControllerScript = preload("res://systems/BackroomsLightingController.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert_profiles_and_determinism()
	_assert_darkness_sampling()
	await _assert_environment_transaction()
	if failures.is_empty():
		print("Backrooms lighting profile tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_profiles_and_determinism() -> void:
	var levels: Array[String] = ProfileScript.get_supported_levels()
	_expect(levels.size() == 6, "lighting profiles cover Backrooms Level 0 through Level 5")
	for level_id in levels:
		var profile: Dictionary = ProfileScript.get_level_profile(level_id)
		_expect(not profile.is_empty(), "%s exposes a lighting profile" % level_id)
		_expect(float(profile.get("light_energy", 0.0)) > 0.0, "%s has positive local light energy" % level_id)
		_expect(float(profile.get("light_range", 0.0)) > 0.0, "%s has positive local light range" % level_id)
	var unsupported: Dictionary = ProfileScript.get_cell_light_descriptor("Level 99", Vector2i.ZERO, 1)
	_expect(unsupported.is_empty(), "unsupported levels cannot create light descriptors")
	var first: Dictionary = ProfileScript.get_cell_light_descriptor("Level 1", Vector2i(2, -3), 20261118)
	var repeated: Dictionary = ProfileScript.get_cell_light_descriptor("Level 1", Vector2i(2, -3), 20261118)
	_expect(first == repeated, "same level, seed and cell produce identical light descriptors")
	var differs: bool = false
	for x in range(-4, 5):
		for z in range(-4, 5):
			var candidate: Dictionary = ProfileScript.get_cell_light_descriptor("Level 1", Vector2i(x, z), 20261118)
			if bool(candidate.get("enabled", false)) != bool(first.get("enabled", false)):
				differs = true
	_expect(differs, "Level 1 distributes lit and unlit cells deterministically")

func _assert_darkness_sampling() -> void:
	var cell_root := Node3D.new()
	root.add_child(cell_root)
	_expect(cell_root.is_inside_tree(), "darkness sampler fixture is inside the SceneTree before global-transform sampling")
	cell_root.set_meta("backrooms_light_descriptor", ProfileScript.get_cell_light_descriptor("Level 1", Vector2i(1, 0), 0))
	var descriptor: Dictionary = cell_root.get_meta("backrooms_light_descriptor")
	_expect(not bool(descriptor.get("enabled", true)), "chosen Level 1 cell is an unlit dark pocket")
	_expect(ProfileScript.is_position_dark(cell_root, Vector3.ZERO, false), "unlit Level 1 cell is sampled as dark")
	cell_root.set_meta("backrooms_light_descriptor", ProfileScript.get_cell_light_descriptor("Level 1", Vector2i.ZERO, 0))
	descriptor = cell_root.get_meta("backrooms_light_descriptor")
	_expect(bool(descriptor.get("enabled", false)), "adjacent Level 1 cell receives a deterministic light")
	var light_position: Vector3 = cell_root.to_global(descriptor.get("local_position", Vector3.ZERO))
	_expect(not ProfileScript.is_position_dark(cell_root, light_position, true), "position directly beneath an enabled ceiling light is not dark")
	_expect(ProfileScript.is_position_dark(cell_root, light_position + Vector3(0.0, 0.0, 20.0), false), "position outside the light range is dark")
	cell_root.set_meta("backrooms_light_descriptor", ProfileScript.get_cell_light_descriptor("Level 0", Vector2i.ZERO, 0))
	_expect(not ProfileScript.is_position_dark(cell_root, Vector3(50.0, 0.0, 50.0), true), "bright ambient Level 0 remains non-dark outside the local light radius")
	cell_root.free()

func _assert_environment_transaction() -> void:
	var root := Node3D.new()
	var world_environment := WorldEnvironment.new()
	var original_environment := Environment.new()
	original_environment.background_mode = Environment.BG_COLOR
	original_environment.background_color = Color(0.1, 0.2, 0.3)
	original_environment.ambient_light_energy = 0.7
	world_environment.environment = original_environment
	root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.visible = true
	root.add_child(sun)
	var controller = ControllerScript.new()
	var invalid: Dictionary = controller.call("enter_backrooms", world_environment, sun, "Level 99")
	_expect(not bool(invalid.get("ok", true)) and world_environment.environment == original_environment and is_equal_approx(sun.light_energy, 1.4), "unsupported level rejects lighting without mutating SurfaceWorld")
	var entered: Dictionary = controller.call("enter_backrooms", world_environment, sun, "Level 1")
	_expect(bool(entered.get("ok", false)) and bool(controller.call("is_active")), "valid Backrooms level applies a lighting transaction")
	_expect(world_environment.environment != original_environment and is_zero_approx(sun.light_energy), "Backrooms override replaces environment and disables surface sun energy")
	var backrooms_environment: Environment = world_environment.environment
	_expect(is_equal_approx(backrooms_environment.ambient_light_energy, 0.035), "Level 1 applies its dark ambient profile")
	_expect(bool(controller.call("restore_surface")), "lighting transaction restores the SurfaceWorld")
	_expect(world_environment.environment == original_environment and is_equal_approx(sun.light_energy, 1.4) and bool(sun.visible), "surface environment and sun state are restored exactly")
	_expect(not bool(controller.call("is_active")), "controller clears its active snapshot after restoration")
	controller = null
	root.free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
