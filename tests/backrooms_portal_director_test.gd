extends SceneTree

const Director = preload("res://systems/BackroomsPortalDirector.gd")
const EXPECTED_TARGET_LEVELS: Array[String] = ["Level 0", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]
const BOUNDS := Rect2(0.0, 0.0, 1000.0, 1000.0)

func _initialize() -> void:
    assert(Director.TARGET_LEVELS == EXPECTED_TARGET_LEVELS)
    _test_spawn_timer_and_distance()
    _test_spawn_retry_when_no_safe_point_exists()
    _test_portal_consumption_is_single_use()
    _test_save_round_trip()
    _test_active_portal_survives_spawn_bounds_change()
    _test_invalid_save_is_atomic()
    print("BackroomsPortalDirector tests passed.")
    quit()

func _test_spawn_timer_and_distance() -> void:
    var director = Director.new(42, BOUNDS, 180.0)
    assert(director.next_spawn_in >= Director.MIN_SPAWN_INTERVAL)
    assert(director.next_spawn_in <= Director.MAX_SPAWN_INTERVAL)
    var early: Dictionary = director.tick(director.next_spawn_in - 0.1, Vector2(500.0, 500.0))
    assert(early["event"] == "none")
    assert(director.active_portal.is_empty())
    var spawned: Dictionary = director.tick(0.2, Vector2(500.0, 500.0))
    assert(spawned["event"] == "spawned")
    var portal: Dictionary = spawned["portal"]
    var point: Vector2 = portal["position"]
    assert(BOUNDS.has_point(point))
    assert(point.distance_to(Vector2(500.0, 500.0)) >= 180.0)
    assert(director.tick(1000.0, Vector2(500.0, 500.0))["event"] == "none")

func _test_spawn_retry_when_no_safe_point_exists() -> void:
    var tiny_bounds := Rect2(0.0, 0.0, 50.0, 50.0)
    var director = Director.new(7, tiny_bounds, 10000.0)
    var result: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(25.0, 25.0))
    assert(result["event"] == "retry")
    assert(is_equal_approx(director.next_spawn_in, Director.RETRY_INTERVAL))
    assert(director.active_portal.is_empty())

func _test_portal_consumption_is_single_use() -> void:
    var director = Director.new(99, BOUNDS, 40.0)
    var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
    var portal_id: int = int(spawned["portal"]["id"])
    assert(not director.consume_portal(portal_id + 1)["ok"])
    assert(not director.active_portal.is_empty())
    var entered: Dictionary = director.consume_portal(portal_id)
    assert(entered["ok"])
    assert(Director.TARGET_LEVELS.has(entered["destination_level"]))
    assert(director.active_portal.is_empty())
    assert(not director.consume_portal(portal_id)["ok"])
    assert(director.next_spawn_in >= Director.MIN_SPAWN_INTERVAL)
    assert(director.next_spawn_in <= Director.MAX_SPAWN_INTERVAL)

func _test_save_round_trip() -> void:
    var player_position := Vector2(500.0, 500.0)
    var director = Director.new(314, BOUNDS, 40.0)
    var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, player_position)
    assert(spawned["event"] == "spawned")
    var saved: Dictionary = director.to_save_dict()
    assert(saved.has("rng_state"))
    assert(saved["rng_state"] is String)
    var serialized := JSON.stringify(saved)
    var parsed: Variant = JSON.parse_string(serialized)
    assert(parsed is Dictionary)
    var restored = Director.new(2718, BOUNDS, 40.0)
    assert(restored.load_save_dict(parsed))
    assert(restored.to_save_dict() == saved)

    var portal_id: int = int(spawned["portal"]["id"])
    var original_entered: Dictionary = director.consume_portal(portal_id)
    var restored_entered: Dictionary = restored.consume_portal(portal_id)
    assert(original_entered == restored_entered)
    assert(restored.to_save_dict() == director.to_save_dict())

    var original_next: Dictionary = director.tick(director.next_spawn_in + 0.1, player_position)
    var restored_next: Dictionary = restored.tick(restored.next_spawn_in + 0.1, player_position)
    assert(original_next == restored_next)
    assert(restored.to_save_dict() == director.to_save_dict())

    var legacy_payload: Dictionary = saved.duplicate(true)
    legacy_payload.erase("rng_state")
    legacy_payload["active_portal"].erase("spawn_bounds")
    var legacy_restored = Director.new(2718, BOUNDS, 40.0)
    var constructor_rng_state: String = str(legacy_restored.to_save_dict()["rng_state"])
    assert(legacy_restored.load_save_dict(legacy_payload))
    assert(legacy_restored.to_save_dict().has("rng_state"))
    assert(legacy_restored.to_save_dict()["rng_state"] == constructor_rng_state)

func _test_active_portal_survives_spawn_bounds_change() -> void:
    var moved_bounds := Rect2(2000.0, 2000.0, 1000.0, 1000.0)
    var director = Director.new(8181, BOUNDS, 40.0)
    var spawned: Dictionary = director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
    assert(spawned["event"] == "spawned")
    var portal_id: int = int(spawned["portal"]["id"])
    var portal_position: Vector2 = spawned["portal"]["position"]
    var saved: Dictionary = director.to_save_dict()
    assert(saved["active_portal"].has("spawn_bounds"))
    assert(saved["active_portal"]["spawn_bounds"] == [0.0, 0.0, 1000.0, 1000.0])

    # Simulate a player-relative candidate window moving after the portal exists.
    # The already-active portal must remain loadable at its original world position.
    director.world_bounds = moved_bounds
    var restored = Director.new(2718, moved_bounds, 40.0)
    assert(restored.load_save_dict(saved))
    assert(restored.active_portal["id"] == portal_id)
    assert(restored.active_portal["position"] == portal_position)
    assert(restored.active_portal["spawn_bounds"] == BOUNDS)
    assert(restored.to_save_dict() == saved)

    var entered: Dictionary = restored.consume_portal(portal_id)
    assert(entered["ok"])
    var next_spawn: Dictionary = restored.tick(restored.next_spawn_in + 0.1, Vector2(2500.0, 2500.0))
    assert(next_spawn["event"] == "spawned")
    assert(moved_bounds.has_point(next_spawn["portal"]["position"]))
    assert(restored.active_portal["spawn_bounds"] == moved_bounds)


func _test_invalid_save_is_atomic() -> void:
    var director = Director.new(17, BOUNDS, 40.0)
    director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
    var before: Dictionary = director.to_save_dict()
    var bad: Dictionary = before.duplicate(true)
    bad["schema_version"] = 99
    assert(not director.load_save_dict(bad))
    assert(director.to_save_dict() == before)
    bad = before.duplicate(true)
    bad["active_portal"]["position"] = [2000.0, 2000.0]
    assert(not director.load_save_dict(bad))
    assert(director.to_save_dict() == before)
    bad = before.duplicate(true)
    bad["active_portal"]["spawn_bounds"] = [0.0, 0.0, -1000.0, 1000.0]
    assert(not director.load_save_dict(bad))
    assert(director.to_save_dict() == before)
    bad = before.duplicate(true)
    bad["active_portal"]["spawn_bounds"] = [0.0, 0.0, 1000.0]
    assert(not director.load_save_dict(bad))
    assert(director.to_save_dict() == before)
    var invalid_rng_states: Array[String] = [
        "invalid",
        "999999999999999999999999999999999999999999",
        "-999999999999999999999999999999999999999999",
        "+1",
        "01",
        "-0"
    ]
    for invalid_state in invalid_rng_states:
        bad = before.duplicate(true)
        bad["rng_state"] = invalid_state
        assert(not director.load_save_dict(bad))
        assert(director.to_save_dict() == before)
    bad = before.duplicate(true)
    bad["rng_state"] = 1
    assert(not director.load_save_dict(bad))
    assert(director.to_save_dict() == before)
