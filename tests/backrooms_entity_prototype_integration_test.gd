extends SceneTree

const PlaygroundScript = preload("res://prototypes/BackroomsPortalPlayground.gd")
const EntityDirector = preload("res://systems/BackroomsEntityDirector.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var playground: Node3D = PlaygroundScript.new()
	var checked_cells: int = 0
	var rendered_entities: int = 0

	for level_name in ["Level 1", "Level 2", "Level 3"]:
		playground.set("current_level", level_name)
		var seen: Dictionary = {}
		for z in range(-40, 41):
			for x in range(-40, 41):
				var cell := Vector2i(x, z)
				var expected: Array[String] = EntityDirector.get_cell_spawns(level_name, cell)
				if expected.is_empty():
					continue

				var cell_root := Node3D.new()
				playground.call("_spawn_level_entities_for_cell", cell_root, cell)
				var actual: Array[String] = []
				for child in cell_root.get_children():
					if not child.has_meta("backrooms_entity_id"):
						_expect(false, "%s created an entity root without an entity ID at %s" % [level_name, cell])
						continue
					var entity_id: String = str(child.get_meta("backrooms_entity_id"))
					actual.append(entity_id)
					seen[entity_id] = true
					_expect(child.has_meta("spawn_cell") and child.get_meta("spawn_cell") == cell, "%s %s visual records its source cell" % [level_name, entity_id])
					if entity_id == "window":
						_expect(not bool(playground.call("_edge_is_open", cell, Vector2i(0, -1))), "Window visuals attach only to a closed north boundary")

				var expected_visuals: Array[String] = []
				for entity_id in expected:
					if entity_id == "window" and bool(playground.call("_edge_is_open", cell, Vector2i(0, -1))):
						continue
					expected_visuals.append(entity_id)
				_expect(actual == expected_visuals, "%s visual dispatch matches director output at %s" % [level_name, cell])
				rendered_entities += actual.size()
				checked_cells += 1
				cell_root.free()

		for entity_id in EntityDirector.get_allowed_entities(level_name):
			_expect(seen.has(entity_id), "%s has a reachable visual factory for %s" % [level_name, entity_id])

	playground.set("current_level", "Level 0")
	for cell in [Vector2i.ZERO, Vector2i(3, 7), Vector2i(-13, 21)]:
		var empty_root := Node3D.new()
		playground.call("_spawn_level_entities_for_cell", empty_root, cell)
		_expect(empty_root.get_child_count() == 0, "Level 0 remains entity-free")
		empty_root.free()

	playground.set("current_level", "Unknown Level")
	for cell in [Vector2i.ZERO, Vector2i(3, 7), Vector2i(-13, 21)]:
		var unknown_root := Node3D.new()
		playground.call("_spawn_level_entities_for_cell", unknown_root, cell)
		_expect(unknown_root.get_child_count() == 0, "Unknown levels fail closed without prototype visuals")
		unknown_root.free()

	playground.free()
	_finish(checked_cells, rendered_entities)

func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _finish(checked_cells: int, rendered_entities: int) -> void:
	if failures.is_empty():
		print("Backrooms entity prototype integration tests passed: %d cells, %d rendered entities." % [checked_cells, rendered_entities])
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
