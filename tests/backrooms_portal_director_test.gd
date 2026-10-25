extends SceneTree

const Director = preload("res://systems/BackroomsPortalDirector.gd")
const BOUNDS := Rect2(0.0, 0.0, 1000.0, 1000.0)

func _initialize() -> void:
    _test_spawn_timer_and_distance()
    _test_spawn_retry_when_no_safe_point_exists()
    _test_portal_consumption_is_single_use()
    _test_save_round_trip()
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
    var director = Director.new(314, BOUNDS, 40.0)
    director.tick(director.next_spawn_in + 0.1, Vector2(500.0, 500.0))
    var saved: Dictionary = director.to_save_dict()
    var restored = Director.new(2718, BOUNDS, 40.0)
    assert(restored.load_save_dict(saved))
    assert(restored.to_save_dict() == saved)

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
