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
	_assert_window_wall_orientations()
	_assert_invalid_specs_are_rejected()
	_assert_duplicate_visual_attachment_is_rejected()
	_assert_production_headless_guard()

	if failures.is_empty():
		print("Backrooms entity visual factory tests passed.")
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

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
