extends SceneTree

const EntityDirector = preload("res://systems/BackroomsEntityDirector.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(EntityDirector.get_allowed_entities("Level 0").is_empty(), "Level 0 has no configured entities yet")
	_expect(EntityDirector.get_allowed_entities("Level 1") == ["window", "smiler"], "Level 1 allows only windows and Smilers")
	_expect(EntityDirector.get_allowed_entities("Level 2") == ["hound", "skin_stealer"], "Level 2 has its own Hound and Skin-Stealer roster")
	_expect(EntityDirector.get_allowed_entities("Level 3") == ["clump", "faceling"], "Level 3 has its own Clump and Faceling roster")
	_expect(EntityDirector.get_allowed_entities("Unknown Level").is_empty(), "Unknown levels fail closed with no entities")

	var observed: Dictionary = {}
	for z in range(-40, 41):
		for x in range(-40, 41):
			var cell := Vector2i(x, z)
			var first: Array[String] = EntityDirector.get_cell_spawns("Level 1", cell)
			var second: Array[String] = EntityDirector.get_cell_spawns("Level 1", cell)
			_expect(first == second, "Cell spawn selection is deterministic")
			for entity_id in first:
				_expect(entity_id == "window" or entity_id == "smiler", "Level 1 spawn is on its whitelist")
				observed[entity_id] = true
	_expect(observed.has("window"), "Window entity can spawn in Level 1")
	_expect(observed.has("smiler"), "Smiler entity can spawn in Level 1")
	_expect(EntityDirector.get_cell_spawns("Level 0", Vector2i(3, 7)).is_empty(), "Level 0 never rolls Level 1 entities")
	var level_2_seen: Dictionary = {}
	var level_3_seen: Dictionary = {}
	for z in range(-40, 41):
		for x in range(-40, 41):
			for entity_id in EntityDirector.get_cell_spawns("Level 2", Vector2i(x, z)):
				level_2_seen[entity_id] = true
			for entity_id in EntityDirector.get_cell_spawns("Level 3", Vector2i(x, z)):
				level_3_seen[entity_id] = true
	_expect(level_2_seen.has("hound") and level_2_seen.has("skin_stealer"), "Both Level 2 entities can spawn")
	_expect(level_3_seen.has("clump") and level_3_seen.has("faceling"), "Both Level 3 entities can spawn")
	for entity_id in EntityDirector.get_cell_spawns("Level 2", Vector2i(3, 7)):
		_expect(entity_id == "hound" or entity_id == "skin_stealer", "Level 2 spawn stays on its own whitelist")
	for entity_id in EntityDirector.get_cell_spawns("Level 3", Vector2i(3, 7)):
		_expect(entity_id == "clump" or entity_id == "faceling", "Level 3 spawn stays on its own whitelist")
	_finish()

func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _finish() -> void:
	if failures.is_empty():
		print("Backrooms entity director tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
