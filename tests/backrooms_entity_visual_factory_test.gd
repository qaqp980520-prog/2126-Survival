extends SceneTree

const FactoryScript = preload("res://systems/BackroomsEntityVisualFactory.gd")

const EXPECTED_PART_COUNTS := {
	"window": 5,
	"smiler": 3,
	"hound": 8,
	"skin_stealer": 6,
	"clump": 7,
	"faceling": 6,
	"duller": 6,
	"deathmoth": 17
}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for entity_id in EXPECTED_PART_COUNTS.keys():
		_assert_entity_visual_contract(str(entity_id), int(EXPECTED_PART_COUNTS[entity_id]))
	_assert_geometry_specs_are_isolated()
	_assert_window_wall_orientations()
	_assert_invalid_specs_are_rejected()
	_assert_duplicate_visual_attachment_is_rejected()
	_assert_production_headless_guard()
	_assert_entity_specific_geometry_semantics()

	if failures.is_empty():
		print("Backrooms entity visual factory contract tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_entity_visual_contract(entity_id: String, expected_parts: int) -> void:
	var specs: Array[Dictionary] = FactoryScript.get_geometry_specs(entity_id)
	_expect(specs.size() == expected_parts, "%s exposes exactly %d geometry specs" % [entity_id, expected_parts])
	_expect(FactoryScript.are_geometry_specs_valid_for_testing(entity_id, specs), "%s geometry/material-key contract is valid" % entity_id)
	_expect(FactoryScript.are_materials_valid_for_testing(entity_id), "%s creates every required Material role" % entity_id)
	var names: Dictionary = {}
	for spec in specs:
		var part_name: String = str(spec.get("name", ""))
		_expect(not part_name.is_empty() and not names.has(part_name), "%s geometry part names are unique" % entity_id)
		names[part_name] = true
		_expect(str(spec.get("kind", "")) in ["box", "sphere"], "%s uses a supported primitive geometry kind" % entity_id)
		_expect(typeof(spec.get("position", null)) == TYPE_VECTOR3, "%s part has a Vector3 position" % entity_id)
		_expect(typeof(spec.get("rotation", null)) == TYPE_VECTOR3, "%s part has a Vector3 rotation" % entity_id)

func _assert_geometry_specs_are_isolated() -> void:
	var caller_specs: Array[Dictionary] = FactoryScript.get_geometry_specs("duller")
	var baseline_specs: Array[Dictionary] = FactoryScript.get_geometry_specs("duller")
	_expect(not caller_specs.is_empty() and not baseline_specs.is_empty(), "Duller exposes a canonical geometry contract")
	if caller_specs.is_empty() or baseline_specs.is_empty():
		return
	caller_specs[0]["size"] = Vector3.ZERO
	var fresh_specs: Array[Dictionary] = FactoryScript.get_geometry_specs("duller")
	_expect(
		FactoryScript.are_geometry_specs_valid_for_testing("duller", fresh_specs),
		"mutating a returned geometry spec does not corrupt the next factory result"
	)
	_expect(
		fresh_specs[0].get("size") == baseline_specs[0].get("size"),
		"geometry specs are rebuilt independently for each caller"
	)

func _assert_window_wall_orientations() -> void:
	var north: Dictionary = FactoryScript.get_window_yaw_for_testing(Vector2i(0, -1))
	_expect(bool(north.get("ok", false)), "North-wall Window orientation is supported")
	_expect(is_equal_approx(float(north.get("yaw", -1.0)), 0.0), "North-wall Window yaw is zero")
	var west: Dictionary = FactoryScript.get_window_yaw_for_testing(Vector2i(-1, 0))
	_expect(bool(west.get("ok", false)), "West-wall Window orientation is supported")
	_expect(is_equal_approx(float(west.get("yaw", -1.0)), PI * 0.5), "West-wall Window yaw is ninety degrees")
	var east: Dictionary = FactoryScript.get_window_yaw_for_testing(Vector2i(1, 0))
	_expect(not bool(east.get("ok", false)), "Unowned east-wall Window orientation is rejected")

func _assert_invalid_specs_are_rejected() -> void:
	var invalid_specs: Array[Dictionary] = [
		{
			"name": "InvalidZeroWidth",
			"kind": "box",
			"position": Vector3.ZERO,
			"rotation": Vector3.ZERO,
			"size": Vector3(0.0, 1.0, 1.0),
			"material": "body"
		}
	]
	_expect(
		not FactoryScript.are_geometry_specs_valid_for_testing("duller", invalid_specs),
		"zero-width geometry is rejected before node construction"
	)
	_expect(FactoryScript.get_geometry_specs("unknown_entity").is_empty(), "unknown entity has no geometry specs")
	_expect(not FactoryScript.are_materials_valid_for_testing("unknown_entity"), "unknown entity has no material contract")

func _assert_duplicate_visual_attachment_is_rejected() -> void:
	var entity_root := Node3D.new()
	entity_root.set_meta("backrooms_entity_id", "duller")
	var existing_visuals := Node3D.new()
	existing_visuals.name = "Visuals"
	entity_root.add_child(existing_visuals)
	_expect(not FactoryScript.attach_visuals(entity_root), "existing Visuals subtree rejects duplicate attachment")
	_expect(entity_root.get_child_count() == 1, "duplicate attachment leaves the existing root unchanged")
	entity_root.free()

func _assert_production_headless_guard() -> void:
	if DisplayServer.get_name() != "headless":
		return
	var root_node := Node3D.new()
	root_node.set_meta("backrooms_entity_id", "duller")
	_expect(not FactoryScript.attach_visuals(root_node), "production visual factory refuses renderer construction in headless mode")
	_expect(root_node.get_child_count() == 0, "headless production guard leaves the metadata root unchanged")
	root_node.free()

func _assert_entity_specific_geometry_semantics() -> void:
	var window := _specs_by_name(FactoryScript.get_geometry_specs("window"))
	_expect(_has_material(window, "DarkWindowPane", "glass"), "Window pane uses the glass material role")
	for frame_name in ["FrameTop", "FrameBottom", "FrameLeft", "FrameRight"]:
		_expect(_has_material(window, frame_name, "frame"), "%s uses the frame material role" % frame_name)
	_expect(_pair_is_mirrored_x(window, "FrameLeft", "FrameRight"), "Window side frames remain mirrored")

	var smiler := _specs_by_name(FactoryScript.get_geometry_specs("smiler"))
	_expect(_has_material(smiler, "DarkSilhouette", "body"), "Smiler silhouette uses the body material role")
	_expect(_has_material(smiler, "Eye_0", "eye") and _has_material(smiler, "Eye_1", "eye"), "Smiler eyes use the eye material role")
	_expect(_pair_is_mirrored_x(smiler, "Eye_0", "Eye_1"), "Smiler eyes remain bilaterally symmetric")

	var hound := _specs_by_name(FactoryScript.get_geometry_specs("hound"))
	_expect(_has_material(hound, "Body", "body") and _has_material(hound, "Head", "body"), "Hound body and head use the body material role")
	_expect(_has_material(hound, "Eye_0", "eye") and _has_material(hound, "Eye_1", "eye"), "Hound eyes use the eye material role")
	_expect(_pair_is_mirrored_x(hound, "Leg_0_0", "Leg_1_0"), "Hound front legs remain mirrored")
	_expect(_pair_is_mirrored_x(hound, "Leg_0_1", "Leg_1_1"), "Hound rear legs remain mirrored")

	var skin_stealer := _specs_by_name(FactoryScript.get_geometry_specs("skin_stealer"))
	_expect(_has_material(skin_stealer, "Torso", "body") and _has_material(skin_stealer, "Head", "body"), "Skin-Stealer torso and head use the body material role")
	_expect(_pair_is_mirrored_x(skin_stealer, "Arm_0", "Arm_1"), "Skin-Stealer arms remain mirrored")
	_expect(_pair_is_mirrored_x(skin_stealer, "Leg_0", "Leg_1"), "Skin-Stealer legs remain mirrored")

	var clump := _specs_by_name(FactoryScript.get_geometry_specs("clump"))
	for index in range(7):
		var part_name := "Mass_%d" % index
		_expect(clump.has(part_name) and str(clump[part_name].get("kind", "")) == "sphere", "Clump mass %d remains spherical" % index)
		_expect(_has_material(clump, part_name, "body"), "Clump mass %d uses the body material role" % index)

	var faceling := _specs_by_name(FactoryScript.get_geometry_specs("faceling"))
	_expect(_has_material(faceling, "Torso", "body") and _has_material(faceling, "FeaturelessHead", "body"), "Faceling torso and featureless head use the body material role")
	_expect(_pair_is_mirrored_x(faceling, "Arm_0", "Arm_1"), "Faceling arms remain mirrored")
	_expect(_pair_is_mirrored_x(faceling, "Leg_0", "Leg_1"), "Faceling legs remain mirrored")

	var duller := _specs_by_name(FactoryScript.get_geometry_specs("duller"))
	_expect(_has_material(duller, "Torso", "body") and _has_material(duller, "FeaturelessHead", "body"), "Duller torso and featureless head use the body material role")
	_expect(_pair_is_mirrored_x(duller, "LongArmLeft", "LongArmRight"), "Duller long arms remain mirrored")
	_expect(_pair_is_mirrored_x(duller, "LegLeft", "LegRight"), "Duller legs remain mirrored")

	var deathmoth := _specs_by_name(FactoryScript.get_geometry_specs("deathmoth"))
	_expect(_has_material(deathmoth, "Wing_0", "wing") and _has_material(deathmoth, "Wing_1", "wing"), "Deathmoth front wings use the wing material role")
	_expect(_has_material(deathmoth, "RearWing_0", "wing") and _has_material(deathmoth, "RearWing_1", "wing"), "Deathmoth rear wings use the wing material role")
	_expect(_has_material(deathmoth, "CompoundEye_0", "eye") and _has_material(deathmoth, "CompoundEye_1", "eye"), "Deathmoth compound eyes use the eye material role")
	_expect(_pair_is_mirrored_x(deathmoth, "Wing_0", "Wing_1"), "Deathmoth front wings remain mirrored with opposite tilt")
	_expect(_pair_is_mirrored_x(deathmoth, "RearWing_0", "RearWing_1"), "Deathmoth rear wings remain mirrored with opposite tilt")
	_expect(_pair_is_mirrored_x(deathmoth, "CompoundEye_0", "CompoundEye_1"), "Deathmoth compound eyes remain mirrored")
	_expect(_pair_is_mirrored_x(deathmoth, "Antenna_0", "Antenna_1"), "Deathmoth antennae remain mirrored")
	for leg_index in range(3):
		_expect(_pair_is_mirrored_x(deathmoth, "Leg_0_%d" % leg_index, "Leg_1_%d" % leg_index), "Deathmoth leg pair %d remains mirrored" % leg_index)

func _specs_by_name(specs: Array[Dictionary]) -> Dictionary:
	var by_name: Dictionary = {}
	for spec in specs:
		by_name[str(spec.get("name", ""))] = spec
	return by_name

func _has_material(specs: Dictionary, part_name: String, material_key: String) -> bool:
	return specs.has(part_name) and str(specs[part_name].get("material", "")) == material_key

func _pair_is_mirrored_x(specs: Dictionary, left_name: String, right_name: String) -> bool:
	if not specs.has(left_name) or not specs.has(right_name):
		return false
	var left: Dictionary = specs[left_name]
	var right: Dictionary = specs[right_name]
	if str(left.get("kind", "")) != str(right.get("kind", "")):
		return false
	if str(left.get("material", "")) != str(right.get("material", "")):
		return false
	var left_position: Vector3 = left.get("position", Vector3.ZERO)
	var right_position: Vector3 = right.get("position", Vector3.ZERO)
	var expected_position := Vector3(-left_position.x, left_position.y, left_position.z)
	if not expected_position.is_equal_approx(right_position):
		return false
	var left_rotation: Vector3 = left.get("rotation", Vector3.ZERO)
	var right_rotation: Vector3 = right.get("rotation", Vector3.ZERO)
	var expected_rotation := Vector3(left_rotation.x, left_rotation.y, -left_rotation.z)
	if not expected_rotation.is_equal_approx(right_rotation):
		return false
	if left.has("size") != right.has("size") or left.has("radius") != right.has("radius") or left.has("height") != right.has("height"):
		return false
	if left.has("size"):
		var left_size: Vector3 = left.get("size", Vector3.ZERO)
		var right_size: Vector3 = right.get("size", Vector3.ZERO)
		if not left_size.is_equal_approx(right_size):
			return false
	if left.has("radius") and not is_equal_approx(float(left.get("radius", 0.0)), float(right.get("radius", 0.0))):
		return false
	if left.has("height") and not is_equal_approx(float(left.get("height", 0.0)), float(right.get("height", 0.0))):
		return false
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
