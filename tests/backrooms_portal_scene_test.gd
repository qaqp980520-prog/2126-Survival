extends SceneTree

const PortalScene = preload("res://systems/BackroomsPortalVisual.tscn")

func _initialize() -> void:
    call_deferred("_run_scene_test")

func _run_scene_test() -> void:
    var portal = PortalScene.instantiate()
    var headless: bool = DisplayServer.get_name() == "headless"
    if not headless:
        root.add_child(portal)
        await process_frame
    assert(portal is Area3D)
    assert(portal.get_node("PortalRing") is MeshInstance3D)
    assert((portal.get_node("PortalRing") as MeshInstance3D).mesh != null)
    assert(portal.get_node("PortalFieldFront") is MeshInstance3D)
    assert((portal.get_node("PortalFieldFront") as MeshInstance3D).mesh != null)
    assert(portal.get_node("PortalFieldBack") is MeshInstance3D)
    assert((portal.get_node("PortalFieldBack") as MeshInstance3D).mesh != null)
    assert(portal.get_node("CollisionShape3D").shape != null)
    assert(portal.get_node("InteractPrompt") is Label3D)
    assert(portal.configure_from_director({"id": 7, "position": Vector2(12.0, 34.0)}, 2.0))
    assert(portal.portal_id == 7)
    var portal_ring: MeshInstance3D = portal.get_node("PortalRing") as MeshInstance3D
    assert(is_equal_approx(portal_ring.rotation.x, PI / 2.0))
    var expected_position := Vector3(12.0, 3.0, 34.0)
    if headless:
        assert(portal.position.is_equal_approx(expected_position))
    else:
        assert(portal.global_position.is_equal_approx(expected_position))
    var before: Vector3 = portal.position if headless else portal.global_position
    assert(not portal.configure_from_director({"id": -1, "position": Vector2.ZERO}, 0.0))
    var after: Vector3 = portal.position if headless else portal.global_position
    assert(after == before)
    if headless:
        portal.free()
    else:
        portal.queue_free()
        await process_frame
    print("Backrooms portal visual scene smoke test passed.")
    quit()
