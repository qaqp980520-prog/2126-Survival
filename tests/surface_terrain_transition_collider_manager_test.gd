extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _test_single_shared_transition()
    await _test_all_cardinal_directions()
    await _test_perpendicular_conflict_falls_back_to_step()
    if failures.is_empty():
        print("Surface terrain shared transition collider manager tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_single_shared_transition() -> void:
    var holder := Node3D.new()
    holder.name = "SharedTransitionTestRoot"
    root.add_child(holder)
    var lower: Node3D = PatchScript.new()
    lower.name = "LowerPatch"
    var higher: Node3D = PatchScript.new()
    higher.name = "HigherPatch"
    higher.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
    holder.add_child(lower)
    holder.add_child(higher)
    await process_frame
    await physics_frame
    _ensure_visuals(lower)
    _ensure_visuals(higher)

    var lower_state: Dictionary = lower.call("get_world_object_state")
    lower_state["revision"] = 1
    var higher_state := {"height_level": 2, "surface_type": "metal", "revision": 1}
    _expect(bool(lower.call("apply_world_object_state", lower_state)), "lower patch accepts its persisted baseline")
    _expect(bool(higher.call("apply_world_object_state", higher_state)), "higher patch accepts its raised state")
    var stable_ids := {
        lower.get_instance_id(): "surface/test/lower",
        higher.get_instance_id(): "surface/test/higher"
    }
    var binding: Dictionary = BinderScript.bind_patches([lower, higher], stable_ids)
    _expect(bool(binding.get("ok", false)), "binder creates a valid unequal-height descriptor")
    var edge_key: String = ""
    for key in binding.get("descriptors", {}).keys():
        edge_key = str(key)
    _expect(not edge_key.is_empty(), "unequal-height descriptor has a stable edge key")

    var manager: Node3D = ManagerScript.new()
    holder.add_child(manager)
    var patches := {
        "surface/test/lower": lower,
        "surface/test/higher": higher
    }
    var report: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches)
    _expect(bool(report.get("ok", false)), "manager accepts the production descriptor and live patches")
    _expect(int(report.get("active_count", -1)) == 1, "one unequal-height seam creates exactly one shared transition")
    _expect(bool(lower.call("is_shared_transition_active", "east")), "lower patch marks its east collision strip as shared")
    _expect(bool(higher.call("is_shared_transition_active", "west")), "higher patch marks its west collision strip as shared")
    var lower_base: CollisionShape3D = lower.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
    var higher_base: CollisionShape3D = higher.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
    _expect(lower_base.disabled and higher_base.disabled, "full overlapping base boxes are disabled while edge strips are segmented")
    _expect(_edge_segments_disabled(lower, 2), "all three lower-patch east edge collision segments are removed")
    _expect(_edge_segments_disabled(higher, 0), "all three higher-patch west edge collision segments are removed")
    _expect(not _segment_disabled(lower, 1, 1) and not _segment_disabled(higher, 1, 1), "interior collision segments remain active")
    var lower_surface := lower.get_node("TerrainCollisionBody/TerrainSurfaceMesh") as MeshInstance3D
    var higher_surface := higher.get_node("TerrainCollisionBody/TerrainSurfaceMesh") as MeshInstance3D
    _expect(lower_surface != null and not lower_surface.visible, "lower full visual mesh is hidden while a shared edge is active")
    _expect(higher_surface != null and not higher_surface.visible, "higher full visual mesh is hidden while a shared edge is active")
    var lower_cut_visual := lower.get_node("TerrainCollisionBody/TerrainSurfaceSegment_X2_Z1") as MeshInstance3D
    var lower_inner_visual := lower.get_node("TerrainCollisionBody/TerrainSurfaceSegment_X1_Z1") as MeshInstance3D
    var higher_cut_visual := higher.get_node("TerrainCollisionBody/TerrainSurfaceSegment_X0_Z1") as MeshInstance3D
    _expect(lower_cut_visual != null and not lower_cut_visual.visible, "lower east visual strip is removed beneath the shared ramp")
    _expect(higher_cut_visual != null and not higher_cut_visual.visible, "higher west visual strip is removed beneath the shared ramp")
    _expect(lower_inner_visual != null and lower_inner_visual.visible, "unshared interior terrain visual remains visible")

    var body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
    _expect(body != null and body.collision_layer == 1, "one owner-managed shared static body is active")
    if body != null:
        _expect(str(body.get_meta("terrain_edge_key", "")) == edge_key, "shared body stores its stable edge identity")
        _expect(str(body.get_meta("terrain_edge_owner", "")) == str(binding["descriptors"][edge_key]["owner_stable_id"]), "shared body records the descriptor's canonical owner")
    if body != null:
        var collision: CollisionShape3D = body.get_node("SharedTransitionCollision") as CollisionShape3D
        var box := collision.shape as BoxShape3D
        var expected_length: float = sqrt(1.5 * 1.5 + 0.5 * 0.5)
        _expect(box != null and absf(box.size.x - expected_length) <= 0.0001, "shared collider spans both 0.75 m edge strips and the 0.5 m rise")
        _expect(box != null and absf(box.size.z - PatchScript.PATCH_SIZE) <= 0.0001, "shared collider spans the full two-metre seam width")
        var visual_node: Node = body.get_node_or_null("SharedTransitionVisual")
        if DisplayServer.get_name() == "headless":
            _expect(visual_node == null, "headless transition body omits render-only mesh while preserving collision")
        else:
            _expect(visual_node is MeshInstance3D, "shared transition has a matching visible ramp mesh")
            if visual_node is MeshInstance3D:
                var visual := visual_node as MeshInstance3D
                var visual_box := visual.mesh as BoxMesh
                _expect(visual_box != null and absf(visual_box.size.y - 0.04) <= 0.0001, "ramp visual includes side faces matching the collision slab")

    var malformed_descriptors: Dictionary = binding.get("descriptors", {}).duplicate(true)
    var malformed_descriptor: Dictionary = malformed_descriptors[edge_key].duplicate(true)
    malformed_descriptor["height_delta"] = 0.25
    malformed_descriptors[edge_key] = malformed_descriptor
    var rejected_sync: Dictionary = manager.call("sync_transitions", malformed_descriptors, patches)
    _expect(not bool(rejected_sync.get("ok", true)), "malformed transition geometry is rejected during preflight")
    _expect(manager.call("get_transition_body", edge_key) == body and manager.call("get_transition_count") == 1, "failed preflight preserves the existing live shared ramp")
    _expect(bool(lower.call("is_shared_transition_active", "east")) and bool(higher.call("is_shared_transition_active", "west")), "failed preflight preserves both segmented patch edges")

    await physics_frame
    await physics_frame
    for sample_x in [0.5, 1.0, 1.5]:
        var query := PhysicsRayQueryParameters3D.create(Vector3(sample_x, 1.5, 0.0), Vector3(sample_x, -0.5, 0.0))
        query.collision_mask = 1
        query.collide_with_areas = false
        query.collide_with_bodies = true
        var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
        _expect(not hit.is_empty(), "shared ramp physics is queryable at x=%.2f" % sample_x)
        if not hit.is_empty():
            var expected_y: float = 0.05 + ((sample_x - 0.25) / 1.5) * 0.5
            _expect(absf(float(hit["position"].y) - expected_y) <= 0.015, "shared ramp collision follows the continuous slope at x=%.2f" % sample_x)

    var body_weak: WeakRef = weakref(body)
    var equal_lower := {"height_level": 0, "surface_type": "soil", "revision": 2}
    var equal_higher := {"height_level": 0, "surface_type": "rock", "revision": 2}
    lower.call("apply_world_object_state", equal_lower)
    higher.call("apply_world_object_state", equal_higher)
    binding = BinderScript.bind_patches([lower, higher], stable_ids)
    report = manager.call("sync_transitions", binding.get("descriptors", {}), patches)
    _expect(bool(report.get("ok", false)) and int(report.get("active_count", -1)) == 0, "equal-height seam removes the shared ramp")
    await process_frame
    await process_frame
    _expect(manager.call("get_transition_body", edge_key) == null and body_weak.get_ref() == null, "retired shared body is released")
    _expect(not lower_base.disabled and not higher_base.disabled, "full base collision returns when the transition is removed")
    _expect(not bool(lower.call("is_shared_transition_active", "east")) and not bool(higher.call("is_shared_transition_active", "west")), "both patches restore their unsegmented collision policy")
    _expect(lower_surface.visible and higher_surface.visible, "full terrain visuals return when the shared transition retires")
    _expect(not lower_cut_visual.visible and not lower_inner_visual.visible and not higher_cut_visual.visible, "segmented terrain visuals are hidden after transition retirement")

    holder.queue_free()
    await process_frame
    await process_frame

func _test_all_cardinal_directions() -> void:
    var cases: Array[Dictionary] = [
        {"side": "east", "offset": Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0), "direction": Vector3.RIGHT},
        {"side": "west", "offset": Vector3(-PatchScript.PATCH_SIZE, 0.0, 0.0), "direction": Vector3.LEFT},
        {"side": "north", "offset": Vector3(0.0, 0.0, -PatchScript.PATCH_SIZE), "direction": Vector3.FORWARD},
        {"side": "south", "offset": Vector3(0.0, 0.0, PatchScript.PATCH_SIZE), "direction": Vector3.BACK}
    ]
    for case in cases:
        var holder := Node3D.new()
        holder.name = "TransitionDirection_" + str(case["side"])
        root.add_child(holder)
        var lower: Node3D = PatchScript.new()
        lower.name = "Lower"
        var higher: Node3D = PatchScript.new()
        higher.name = "Higher"
        higher.position = case["offset"]
        holder.add_child(lower)
        holder.add_child(higher)
        await process_frame
        lower.call("apply_world_object_state", {"height_level": 0, "surface_type": "soil", "revision": 1})
        higher.call("apply_world_object_state", {"height_level": 2, "surface_type": "metal", "revision": 1})
        var stable_ids := {
            lower.get_instance_id(): "a/lower",
            higher.get_instance_id(): "z/higher"
        }
        var binding: Dictionary = BinderScript.bind_patches([lower, higher], stable_ids)
        var edge_key: String = ""
        for key in binding.get("descriptors", {}).keys():
            edge_key = str(key)
        var manager: Node3D = ManagerScript.new()
        holder.add_child(manager)
        var patches := {"a/lower": lower, "z/higher": higher}
        var report: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches)
        _expect(bool(report.get("ok", false)) and int(report.get("active_count", -1)) == 1, "%s seam creates one shared ramp" % str(case["side"]))
        var side: String = str(case["side"])
        var opposite: String = ""
        match side:
            "east": opposite = "west"
            "west": opposite = "east"
            "north": opposite = "south"
            "south": opposite = "north"
        _expect(bool(lower.call("is_shared_transition_active", side)), "%s lower edge is segmented" % side)
        _expect(bool(higher.call("is_shared_transition_active", opposite)), "%s higher edge is segmented" % side)
        var lower_base: CollisionShape3D = lower.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
        var higher_base: CollisionShape3D = higher.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
        _expect(lower_base.disabled and higher_base.disabled, "%s full base boxes are replaced by segmented collision" % side)
        var body: StaticBody3D = manager.call("get_transition_body", edge_key) as StaticBody3D
        _expect(body != null and body.collision_layer == 1, "%s shared collider is active" % side)
        await physics_frame
        await physics_frame
        var direction: Vector3 = case["direction"]
        for progress in [0.2, 0.5, 0.8]:
            var point: Vector3 = direction * (0.25 + 1.5 * float(progress))
            var query := PhysicsRayQueryParameters3D.create(
                Vector3(point.x, 1.5, point.z),
                Vector3(point.x, -0.5, point.z)
            )
            query.collision_mask = 1
            query.collide_with_areas = false
            query.collide_with_bodies = true
            var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
            _expect(not hit.is_empty(), "%s ramp collision is queryable at progress %.1f" % [side, progress])
            if not hit.is_empty():
                var expected_y: float = 0.05 + 0.5 * float(progress)
                _expect(absf(float(hit["position"].y) - expected_y) <= 0.015, "%s ramp surface height is continuous at progress %.1f" % [side, progress])
        holder.queue_free()
        await process_frame
        await process_frame

func _test_perpendicular_conflict_falls_back_to_step() -> void:
    var holder := Node3D.new()
    holder.name = "TransitionConflictTestRoot"
    root.add_child(holder)
    var center: Node3D = PatchScript.new()
    center.name = "Center"
    var east: Node3D = PatchScript.new()
    east.name = "East"
    east.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
    var south: Node3D = PatchScript.new()
    south.name = "South"
    south.position = Vector3(0.0, 0.0, PatchScript.PATCH_SIZE)
    holder.add_child(center)
    holder.add_child(east)
    holder.add_child(south)
    await process_frame
    var raised := {"height_level": 2, "surface_type": "metal", "revision": 1}
    var low := {"height_level": 0, "surface_type": "soil", "revision": 1}
    center.call("apply_world_object_state", raised)
    east.call("apply_world_object_state", low)
    south.call("apply_world_object_state", low)
    var stable_ids := {
        center.get_instance_id(): "surface/conflict/center",
        east.get_instance_id(): "surface/conflict/east",
        south.get_instance_id(): "surface/conflict/south"
    }
    var binding: Dictionary = BinderScript.bind_patches([center, east, south], stable_ids)
    var patches := {
        "surface/conflict/center": center,
        "surface/conflict/east": east,
        "surface/conflict/south": south
    }
    var manager: Node3D = ManagerScript.new()
    holder.add_child(manager)
    var report: Dictionary = manager.call("sync_transitions", binding.get("descriptors", {}), patches)
    _expect(bool(report.get("ok", false)), "manager safely handles a perpendicular corner conflict")
    _expect(int(report.get("active_count", -1)) == 0 and int(report.get("blocked_count", -1)) == 2, "both crossing ramps are rejected instead of overlapping at a corner")
    var center_base: CollisionShape3D = center.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
    _expect(not center_base.disabled, "conflicted center patch retains its complete step collision")
    _expect(not bool(center.call("is_shared_transition_active", "east")) and not bool(center.call("is_shared_transition_active", "south")), "conflicted edges do not cut collision strips")
    holder.queue_free()
    await process_frame
    await process_frame

func _ensure_visuals(patch: Node3D) -> void:
    if patch.get("_surface_mesh") == null:
        patch.call("_build_visual")
        patch.call("_refresh_geometry")

func _edge_segments_disabled(patch: Node3D, x_index: int) -> bool:
    for z_index in range(3):
        if not _segment_disabled(patch, x_index, z_index):
            return false
    return true

func _segment_disabled(patch: Node3D, x_index: int, z_index: int) -> bool:
    var segment := patch.get_node_or_null("TerrainCollisionBody/TerrainCollisionSegment_X%d_Z%d" % [x_index, z_index]) as CollisionShape3D
    return segment == null or segment.disabled

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
