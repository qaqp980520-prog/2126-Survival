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
		_assert_entity_visuals(str(entity_id), int(EXPECTED_PART_COUNTS[entity_id]))
	_assert_window_wall_orientations()
	_assert_invalid_specs_are_rejected_atomically()
	_assert_production_headless_guard()
	await process_frame

	if failures.is_empty():
		print("Backrooms entity visual factory tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_entity_visuals(entity_id: String, expected_parts: int) -> void:
	var entity_root := Node3D.new()
	entity_root.set_meta("backrooms_entity_id", entity_id)
	if entity_id == "window":
		entity_root.set_meta("backrooms_wall_direction", Vector2i(0, -1))
	root.add_child(entity_root)
	var built: bool = FactoryScript.attach_visuals_for_testing(entity_root)
	_expect(built, "%s visual factory builds a complete visual subtree" % entity_id)
	var visuals: Node3D = entity_root.get_node_or_null("Visuals") as Node3D
	_expect(visuals != null, "%s publishes one Visuals subtree" % entity_id)
	if visuals != null:
		_expect(visuals.get_child_count() == expected_parts, "%s creates exactly %d geometry parts" % [entity_id, expected_parts])
		var names: Dictionary = {}
		for child in visuals.get_children():
			_expect(child is MeshInstance3D, "%s visual child is a MeshInstance3D" % entity_id)
			if not (child is MeshInstance3D):
				continue
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			_expect(not names.has(mesh_instance.name), "%s part names are unique" % entity_id)
			names[mesh_instance.name] = true
			_expect(mesh_instance.mesh is PrimitiveMesh, "%s part has a primitive mesh" % entity_id)
			_expect(mesh_instance.material_override is Material, "%s part has a material" % entity_id)
	_expect(int(entity_root.get_meta("backrooms_entity_visual_version", 0)) == FactoryScript.VISUAL_FACTORY_VERSION, "%s records its visual factory version" % entity_id)
	_expect(entity_root.get_meta("backrooms_entity_visual_state", "") == "attached", "%s records an attached visual state" % entity_id)
	_expect(not FactoryScript.attach_visuals_for_testing(entity_root), "%s rejects duplicate visual attachment" % entity_id)
	_expect(entity_root.get_child_count() == 1, "%s keeps exactly one published visual subtree" % entity_id)
	entity_root.queue_free()

func _assert_window_wall_orientations() -> void:
	var west_window := Node3D.new()
	west_window.set_meta("backrooms_entity_id", "window")
	west_window.set_meta("backrooms_wall_direction", Vector2i(-1, 0))
	root.add_child(west_window)
	var west_built: bool = FactoryScript.attach_visuals_for_testing(west_window)
	_expect(west_built, "West-wall Window visual is built")
	_expect(is_equal_approx(west_window.rotation.y, PI * 0.5), "West-wall Window is rotated ninety degrees")
	west_window.queue_free()

func _assert_invalid_specs_are_rejected_atomically() -> void:
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
	var unknown_root := Node3D.new()
	unknown_root.set_meta("backrooms_entity_id", "unknown_entity")
	_expect(not FactoryScript.attach_visuals_for_testing(unknown_root), "unknown entity visual contract is rejected")
	_expect(unknown_root.get_child_count() == 0, "rejected visual contract leaves the entity root unchanged")
	var invalid_window := Node3D.new()
	invalid_window.set_meta("backrooms_entity_id", "window")
	invalid_window.set_meta("backrooms_wall_direction", Vector2i(1, 0))
	_expect(not FactoryScript.attach_visuals_for_testing(invalid_window), "unowned east-wall Window is rejected")
	_expect(invalid_window.rotation.is_equal_approx(Vector3.ZERO) and invalid_window.get_child_count() == 0, "rejected Window leaves its transform and children unchanged")
	invalid_window.free()
	unknown_root.free()

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
