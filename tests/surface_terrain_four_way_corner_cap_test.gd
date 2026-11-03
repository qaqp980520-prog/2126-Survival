extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const POSITION_TOLERANCE: float = 0.025
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _test_checkerboard_junction_builds_four_caps(true)
    await _test_checkerboard_junction_builds_four_caps(false)
    if failures.is_empty():
        print("Four-way terrain corner cap geometry regression passed for both checkerboard diagonals.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_checkerboard_junction_builds_four_caps(high_nw_se: bool) -> void:
    var holder := Node3D.new()
    holder.name = "FourWayCornerCapTestRoot_NW_SE" if high_nw_se else "FourWayCornerCapTestRoot_NE_SW"
    root.add_child(holder)

    var north_west: Node3D = PatchScript.new()
    north_west.name = "NorthWest"
    north_west.position = Vector3.ZERO
    var north_east: Node3D = PatchScript.new()
    north_east.name = "NorthEast"
    north_east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
    var south_west: Node3D = PatchScript.new()
    south_west.name = "SouthWest"
    south_west.position = Vector3(0.0, 0.0, PatchScript.PATCH_SIZE)
    var south_east: Node3D = PatchScript.new()
    south_east.name = "SouthEast"
    south_east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, PatchScript.PATCH_SIZE)
    holder.add_child(north_west)
    holder.add_child(north_east)
    holder.add_child(south_west)
    holder.add_child(south_east)
    await process_frame
    await physics_frame

    var high_state := {"height_level": 2, "surface_type": "metal", "revision": 1}
    var low_state := {"height_level": 0, "surface_type": "soil", "revision": 1}
    var high_patches: Array[Node3D] = [north_west, south_east] if high_nw_se else [north_east, south_west]
    var low_patches: Array[Node3D] = [north_east, south_west] if high_nw_se else [north_west, south_east]
    for patch in high_patches:
        _expect(bool(patch.call("apply_world_object_state", high_state)), "high diagonal patch accepts state")
    for patch in low_patches:
        _expect(bool(patch.call("apply_world_object_state", low_state)), "low diagonal patch accepts state")

    var stable_ids := {
        north_west.get_instance_id(): "cap/nw",
        north_east.get_instance_id(): "cap/ne",
        south_west.get_instance_id(): "cap/sw",
        south_east.get_instance_id(): "cap/se"
    }
    var patches := {
        "cap/nw": north_west,
        "cap/ne": north_east,
        "cap/sw": south_west,
        "cap/se": south_east
    }
    var binding: Dictionary = BinderScript.bind_patches([north_west, north_east, south_west, south_east], stable_ids)
    _expect(bool(binding.get("ok", false)), "checkerboard patches bind into four unequal cardinal edges")
    _expect(int(binding.get("pair_count", -1)) == 4, "all four junction edges are present")
    if not bool(binding.get("ok", false)):
        holder.queue_free()
        await process_frame
        return

    var manager: Node3D = ManagerScript.new()
    holder.add_child(manager)
    var descriptors: Dictionary = binding.get("descriptors", {})
    var report: Dictionary = manager.call("sync_transitions", descriptors, patches)
    await process_frame
    await physics_frame
    _expect(bool(report.get("ok", false)), "manager accepts the height-continuous checkerboard junction")
    _expect(int(report.get("active_count", -1)) == 4, "all four edge ramps are activated around the cap")
    _expect(int(report.get("blocked_count", -1)) == 0, "height-continuous edges are not left in fallback")
    _expect(int(report.get("corner_cap_count", -1)) == 4, "one cap is staged for each patch corner")
    _expect(int(manager.call("get_corner_cap_count")) == 4, "manager owns four live corner cap bodies")
    _expect(int(manager.call("get_transition_count")) == 4, "manager owns all four trimmed shared edge bodies")
    if not bool(report.get("ok", false)):
        holder.queue_free()
        await process_frame
        return

    var expected_corners := {
        "cap/nw": "south_east",
        "cap/ne": "south_west",
        "cap/sw": "north_east",
        "cap/se": "north_west"
    }
    var patch_by_id := {
        "cap/nw": north_west,
        "cap/ne": north_east,
        "cap/sw": south_west,
        "cap/se": south_east
    }
    var signs := {
        "cap/nw": Vector2i(1, 1),
        "cap/ne": Vector2i(-1, 1),
        "cap/sw": Vector2i(1, -1),
        "cap/se": Vector2i(-1, -1)
    }
    var midpoint_height: float = (float(north_west.call("get_top_height")) + float(north_east.call("get_top_height"))) * 0.5
    for stable_id in expected_corners.keys():
        var corner: String = expected_corners[stable_id]
        var cap_body: StaticBody3D = manager.call("get_corner_cap_body", stable_id, corner)
        _expect(is_instance_valid(cap_body), stable_id + " owns a corner cap body")
        if not is_instance_valid(cap_body):
            continue
        _expect(cap_body.collision_layer == 1, stable_id + " cap collision is enabled only after commit")
        var collision := cap_body.get_node_or_null("CornerCapCollision") as CollisionShape3D
        _expect(collision != null and collision.shape is ConcavePolygonShape3D, stable_id + " cap uses a concave static collision shape")
        if collision != null and collision.shape is ConcavePolygonShape3D:
            var faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
            _expect(faces.size() == 36, stable_id + " cap collision contains two top triangles and closed thickness walls")
        _expect(str(cap_body.get_meta("terrain_corner_owner", "")) == stable_id, stable_id + " cap has deterministic patch ownership")

        var patch: Node3D = patch_by_id[stable_id]
        var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
        _expect(base_collision != null and base_collision.disabled, stable_id + " full patch box is replaced while shared edges are active")
        var corner_sign: Vector2i = signs[stable_id]
        var x_index: int = 2 if corner_sign.x > 0 else 0
        var z_index: int = 2 if corner_sign.y > 0 else 0
        var corner_segment := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionSegment_X%d_Z%d" % [x_index, z_index]) as CollisionShape3D
        _expect(corner_segment != null and corner_segment.disabled, stable_id + " base corner segment is clipped under the cap")
        _expect(bool(patch.call("is_shared_transition_active", "east" if corner_sign.x > 0 else "west")), stable_id + " horizontal shared edge is active")
        _expect(bool(patch.call("is_shared_transition_active", "south" if corner_sign.y > 0 else "north")), stable_id + " vertical shared edge is active")

        var top_height: float = float(patch.call("get_top_height"))
        var sample_x: float = float(corner_sign.x) * (PatchScript.PATCH_SIZE * 0.5 - 0.375)
        var sample_z: float = float(corner_sign.y) * (PatchScript.PATCH_SIZE * 0.5 - 0.375)
        var sample_position: Vector3 = patch.global_position + Vector3(sample_x, 0.0, sample_z)
        var query := PhysicsRayQueryParameters3D.create(
            sample_position + Vector3.UP * 2.0,
            sample_position - Vector3.UP * 1.0,
            1
        )
        var hit: Dictionary = holder.get_world_3d().direct_space_state.intersect_ray(query)
        if hit.is_empty() or hit.get("collider") != cap_body:
            print("CAP_DIAGNOSTIC owner=" + stable_id + " body=" + str(cap_body.global_position) + " sample=" + str(sample_position) + " hit=" + str(hit))
        _expect(not hit.is_empty(), stable_id + " cap center is raycastable")
        if not hit.is_empty():
            _expect(hit.get("collider") == cap_body, stable_id + " ray hits its own cap rather than a clipped ramp or base segment")
            var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
            _expect(absf(hit_position.y - (patch.global_position.y + (top_height + midpoint_height) * 0.5)) <= POSITION_TOLERANCE, stable_id + " cap center height matches the diagonal triangulation")

    for edge_key in descriptors.keys():
        var edge_body: StaticBody3D = manager.call("get_transition_body", str(edge_key))
        _expect(is_instance_valid(edge_body), "trimmed edge body exists for " + str(edge_key))
        if not is_instance_valid(edge_body):
            continue
        var edge_collision := edge_body.get_node_or_null("SharedTransitionCollision") as CollisionShape3D
        var box: BoxShape3D = null
        if edge_collision != null:
            box = edge_collision.shape as BoxShape3D
        _expect(box != null, "trimmed edge has a box collision shape")
        if box != null:
            _expect(absf(box.size.z - (PatchScript.PATCH_SIZE - PatchScript.EDGE_RAMP_RUN)) <= POSITION_TOLERANCE, "edge ramp is clipped by one corner run at the junction end")

    var reports: Array = report.get("blocked_corner_reports", [])
    _expect(reports.size() == 4, "all four per-patch corner reports remain available")
    for report_value in reports:
        _expect(str(report_value.get("policy", "")) == "shared_corner_cap", "eligible report advertises shared_corner_cap instead of fallback")

    var malformed: Dictionary = descriptors.duplicate(true)
    var first_key: String = str(malformed.keys()[0])
    malformed[first_key]["height_delta"] = float(malformed[first_key]["height_delta"]) + 0.5
    var rejected: Dictionary = manager.call("sync_transitions", malformed, patches)
    _expect(not bool(rejected.get("ok", false)), "stale geometry is rejected before replacing the live cap set")
    _expect(int(manager.call("get_corner_cap_count")) == 4, "failed preflight preserves all four committed caps")
    _expect(int(manager.call("get_transition_count")) == 4, "failed preflight preserves all four committed ramps")

    manager.call("clear_all")
    await process_frame
    await physics_frame
    _expect(int(manager.call("get_corner_cap_count")) == 0, "clear_all retires all corner caps")
    _expect(int(manager.call("get_transition_count")) == 0, "clear_all retires all shared ramps")
    for patch in [north_west, north_east, south_west, south_east]:
        var base_collision := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
        _expect(base_collision != null and not base_collision.disabled, "clear_all restores full patch collision")
        for side in ["east", "west", "north", "south"]:
            _expect(not bool(patch.call("is_shared_transition_active", side)), "clear_all clears shared side ownership")

    holder.queue_free()
    await process_frame
    await process_frame

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
