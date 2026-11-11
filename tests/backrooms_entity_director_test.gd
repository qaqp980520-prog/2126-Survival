extends SceneTree

const EntityDirector = preload("res://systems/BackroomsEntityDirector.gd")
const EXPECTED_ROSTERS := {
    "Level 0": [],
    "Level 1": ["window", "smiler"],
    "Level 2": ["hound", "skin_stealer"],
    "Level 3": ["clump", "faceling"],
    "Level 4": ["duller"],
    "Level 5": ["deathmoth"]
}

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for level_name in EXPECTED_ROSTERS:
        var expected: Array = EXPECTED_ROSTERS[level_name]
        _expect(EntityDirector.get_allowed_entities(level_name) == expected, "%s has its exact level-specific roster" % level_name)
        if expected.is_empty():
            _expect(EntityDirector.get_cell_spawns(level_name, Vector2i(3, 7)).is_empty(), "%s remains intentionally entity-free" % level_name)
            continue

        var observed: Dictionary = {}
        var deterministic := true
        var whitelist_valid := true
        for z in range(-40, 41):
            for x in range(-40, 41):
                var cell := Vector2i(x, z)
                var first: Array[String] = EntityDirector.get_cell_spawns(level_name, cell)
                var second: Array[String] = EntityDirector.get_cell_spawns(level_name, cell)
                if first != second:
                    deterministic = false
                for entity_id in first:
                    if not expected.has(entity_id):
                        whitelist_valid = false
                    observed[entity_id] = true
        _expect(deterministic, "%s cell selection is deterministic across the sampled grid" % level_name)
        _expect(whitelist_valid, "%s spawns remain on their own whitelist" % level_name)
        for entity_id in expected:
            _expect(observed.has(entity_id), "%s entity %s can spawn in the sampled grid" % [level_name, entity_id])

    _expect(EntityDirector.get_allowed_entities("Unknown Level").is_empty(), "Unknown levels fail closed with no entities")
    _expect(EntityDirector.get_cell_spawns("Unknown Level", Vector2i(-17, 29)).is_empty(), "Unknown levels never roll configured entities")
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
