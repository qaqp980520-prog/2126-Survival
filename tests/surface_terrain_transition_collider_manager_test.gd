extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
const CornerResolverScript = preload("res://systems/SurfaceTerrainCornerConflictResolver.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _test_single_shared_transition()
    await _test_all_cardinal_directions()
    await _test_perpendicular_conflict_falls_back_to_step()
    _test_corner_resolver_all_orientations()
    _test_duplicate_patch_side_rejected()
    _test_resolver_rejects_non_opposite_sides_and_stable_order()
    _test_manager_rejects_non_string_public_inputs()
    await _test_manager_rejects_mismatched_cardinal_side()
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
    var has_render_visuals: bool = DisplayServer.get_name() != "headless"
    if has_render_visuals:
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
    var lower_surface: MeshInstance3D
    var higher_surface: MeshInstance3D
    var lower_cut_visual: MeshInstance3D
    var lower_inner_visual: MeshInstance3D
    var higher_cut_visual: MeshInstance3D
    if has_render_visuals:
        lower_surface = lower.get_node("TerrainCollisionBody/TerrainSurfaceMesh") as MeshInstance3D
        higher_surface = higher.get_node("TerrainCollisionBody/TerrainSurfaceMesh") as MeshInstance3D
        _expect(lower_surface != null and not lower_surface.visible, "lower full visual mesh is hidden while a shared edge is active")
        _expect(higher_surface != null and not higher_surface.visible, "higher full visual mesh is hidden while a shared edge is active")
        lower_cut_visual = lower.get_node("TerrainCollisionBody/TerrainSurfaceSegment_X2_Z1") as MeshInstance3D
        lower_inner_visual = lower.get_node("TerrainCollisionBody/TerrainSurfaceSegment_X1_Z1") as MeshInstance3D
        higher_cut_visual = higher.get_node("TerrainCollisionBody/TerrainSurfaceSegment_X0_Z1") as MeshInstance3D
        _expect(lower_cut_visual != null and not lower_cut_visual.visible, "lower east visual strip is removed beneath the shared ramp")
        _expect(higher_cut_visual != null and not higher_cut_visual.visible, "higher west visual strip is removed beneath the shared ramp")
        _expect(lower_inner_visual != null and lower_inner_visual.visible, "unshared interior terrain visual remains visible")
    else:
        _expect(not bool(lower.call("is_surface_base_visual_visible")), "headless lower base-visual state is hidden while the shared edge is active")
        _expect(not bool(higher.call("is_surface_base_visual_visible")), "headless higher base-visual state is hidden while the shared edge is active")
        _expect(not bool(lower.call("is_surface_segment_visual_visible", 2, 1)), "headless lower east visual strip is logically removed")
        _expect(not bool(higher.call("is_surface_segment_visual_visible", 0, 1)), "headless higher west visual strip is logically removed")
        _expect(bool(lower.call("is_surface_segment_visual_visible", 1, 1)), "headless unshared interior visual remains logically visible")

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
    if has_render_visuals:
        _expect(lower_surface.visible and higher_surface.visible, "full terrain visuals return when the shared transition retires")
        _expect(not lower_cut_visual.visible and not lower_inner_visual.visible and not higher_cut_visual.visible, "segmented terrain visuals are hidden after transition retirement")
    else:
        _expect(bool(lower.call("is_surface_base_visual_visible")) and bool(higher.call("is_surface_base_visual_visible")), "headless full terrain visual state returns after transition retirement")
        _expect(not bool(lower.call("is_surface_segment_visual_visible", 2, 1)) and not bool(lower.call("is_surface_segment_visual_visible", 1, 1)) and not bool(higher.call("is_surface_segment_visual_visible", 0, 1)), "headless segmented visual states are hidden after transition retirement")

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
    var blocked_keys: Array = report.get("blocked_edge_keys", [])
    var sorted_blocked_keys: Array = blocked_keys.duplicate()
    sorted_blocked_keys.sort()
    _expect(blocked_keys.size() == 2, "manager exposes both blocked edge keys")
    _expect(blocked_keys == sorted_blocked_keys, "manager forwards blocked edge keys in deterministic sorted order")
    var corner_reports: Array = report.get("blocked_corner_reports", [])
    _expect(corner_reports.size() == 1, "one perpendicular conflict produces one explicit corner report")
    if corner_reports.size() == 1:
        _expect(str(corner_reports[0].get("stable_id", "")) == "surface/conflict/center", "corner report identifies the shared center patch")
        _expect(str(corner_reports[0].get("corner", "")) == "south_east", "east/south ramps resolve to the south-east corner")
        _expect(str(corner_reports[0].get("policy", "")) == "step_fallback", "blocked corner reports the conservative step fallback")
    var center_base: CollisionShape3D = center.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
    _expect(not center_base.disabled, "conflicted center patch retains its complete step collision")
    _expect(not bool(center.call("is_shared_transition_active", "east")) and not bool(center.call("is_shared_transition_active", "south")), "conflicted edges do not cut collision strips")
    holder.queue_free()
    await process_frame
    await process_frame


func _test_corner_resolver_all_orientations() -> void:
    var cases: Array[Dictionary] = [
        {"first":"east","second":"north","corner":"north_east"},
        {"first":"east","second":"south","corner":"south_east"},
        {"first":"west","second":"north","corner":"north_west"},
        {"first":"west","second":"south","corner":"south_west"}
    ]
    for case in cases:
        var first_side: String = str(case["first"])
        var second_side: String = str(case["second"])
        var candidates := {
            "edge_a": {
                "first_id":"surface/corner/center",
                "second_id":"surface/corner/a",
                "first_side":first_side,
                "second_side":_opposite_side(first_side)
            },
            "edge_b": {
                "first_id":"surface/corner/center",
                "second_id":"surface/corner/b",
                "first_side":second_side,
                "second_side":_opposite_side(second_side)
            }
        }
        var result: Dictionary = CornerResolverScript.resolve(candidates)
        _expect(bool(result.get("ok", false)), "%s/%s corner topology is accepted" % [first_side, second_side])
        _expect(result.get("blocked_edges", {}).size() == 2, "%s/%s blocks both intersecting ramps" % [first_side, second_side])
        var reports: Array = result.get("reports", [])
        _expect(reports.size() == 1, "%s/%s produces exactly one corner report" % [first_side, second_side])
        if reports.size() == 1:
            _expect(str(reports[0].get("corner", "")) == str(case["corner"]), "%s/%s maps to %s" % [first_side, second_side, str(case["corner"])])

    var three_edges := {
        "east_edge":{"first_id":"center","second_id":"east","first_side":"east","second_side":"west"},
        "north_edge":{"first_id":"center","second_id":"north","first_side":"north","second_side":"south"},
        "south_edge":{"first_id":"center","second_id":"south","first_side":"south","second_side":"north"}
    }
    var three_result: Dictionary = CornerResolverScript.resolve(three_edges)
    var three_reports: Array = three_result.get("reports", [])
    _expect(bool(three_result.get("ok", false)) and three_result.get("blocked_edges", {}).size() == 3, "three perpendicular edge candidates are all conservatively blocked")
    _expect(three_reports.size() == 2, "three-way topology reports both occupied corners")
    if three_reports.size() == 2:
        _expect(str(three_reports[0].get("corner", "")) == "north_east" and str(three_reports[1].get("corner", "")) == "south_east", "three-way corner reports have deterministic order")

    var aligned := {
        "east_edge":{"first_id":"center","second_id":"east","first_side":"east","second_side":"west"},
        "west_edge":{"first_id":"center","second_id":"west","first_side":"west","second_side":"east"}
    }
    var aligned_result: Dictionary = CornerResolverScript.resolve(aligned)
    _expect(bool(aligned_result.get("ok", false)) and aligned_result.get("blocked_edges", {}).is_empty() and aligned_result.get("reports", []).is_empty(), "parallel opposite edges do not create a corner conflict")

    var malformed := {"bad_edge":{"first_id":"center","second_id":"east","first_side":"east"}}
    _expect(not bool(CornerResolverScript.resolve(malformed).get("ok", true)), "incomplete edge candidate is rejected")

func _test_duplicate_patch_side_rejected() -> void:
    var duplicate_side := {
        "east_a":{"first_id":"center","second_id":"east_a","first_side":"east","second_side":"west"},
        "east_b":{"first_id":"center","second_id":"east_b","first_side":"east","second_side":"west"}
    }
    var duplicate_result: Dictionary = CornerResolverScript.resolve(duplicate_side)
    _expect(not bool(duplicate_result.get("ok", true)) and str(duplicate_result.get("error", "")) == "duplicate_patch_side", "two transitions cannot claim the same patch side")
    _expect(str(duplicate_result.get("stable_id", "")) == "center" and str(duplicate_result.get("side", "")) == "east", "duplicate-side report identifies the affected patch edge")
    _expect(duplicate_result.get("edge_keys", []) == ["east_a", "east_b"], "duplicate-side report sorts the conflicting edge keys deterministically")

    var invalid_descriptor := {"bad_edge":"not a dictionary"}
    _expect(str(CornerResolverScript.resolve(invalid_descriptor).get("error", "")) == "invalid_edge_descriptor", "non-dictionary edge candidates are rejected safely")
    var empty_key := {"":{"first_id":"center","second_id":"east","first_side":"east","second_side":"west"}}
    _expect(str(CornerResolverScript.resolve(empty_key).get("error", "")) == "invalid_edge_key", "empty edge keys are rejected safely")

func _test_resolver_rejects_non_opposite_sides_and_stable_order() -> void:
    var same_side := {"same":{"first_id":"center","second_id":"neighbor","first_side":"east","second_side":"east"}}
    var non_opposite := {"crossed":{"first_id":"center","second_id":"neighbor","first_side":"east","second_side":"north"}}
    var numeric_key := {7:{"first_id":"center","second_id":"neighbor","first_side":"east","second_side":"west"}}
    var numeric_id := {"numeric_id":{"first_id":7,"second_id":"neighbor","first_side":"east","second_side":"west"}}
    _expect(str(CornerResolverScript.resolve(same_side).get("error", "")) == "invalid_edge_sides", "same-side edge descriptors are rejected")
    _expect(str(CornerResolverScript.resolve(non_opposite).get("error", "")) == "invalid_edge_sides", "non-opposite edge descriptors are rejected")
    _expect(str(CornerResolverScript.resolve(numeric_key).get("error", "")) == "invalid_edge_key", "non-string edge keys are rejected")
    _expect(str(CornerResolverScript.resolve(numeric_id).get("error", "")) == "invalid_patch_ids", "non-string stable patch IDs are rejected")
    var east_edge := {"first_id":"center","second_id":"east","first_side":"east","second_side":"west"}
    var north_edge := {"first_id":"center","second_id":"north","first_side":"north","second_side":"south"}
    var forward := {"z_north":north_edge,"a_east":east_edge}
    var reverse := {"a_east":east_edge,"z_north":north_edge}
    var forward_result: Dictionary = CornerResolverScript.resolve(forward)
    var reverse_result: Dictionary = CornerResolverScript.resolve(reverse)
    _expect(bool(forward_result.get("ok", false)) and bool(reverse_result.get("ok", false)), "valid perpendicular descriptors resolve in either insertion order")
    _expect(forward_result.get("blocked_edge_keys", []) == ["a_east", "z_north"], "blocked edge keys are returned in sorted order")
    _expect(forward_result.get("reports", []) == reverse_result.get("reports", []), "corner reports are stable across candidate insertion order")

func _opposite_side(side: String) -> String:
    match side:
        "east": return "west"
        "west": return "east"
        "north": return "south"
        "south": return "north"
        _: return ""

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


func _test_manager_rejects_non_string_public_inputs() -> void:
    var manager: Node3D = ManagerScript.new()
    var valid_descriptor := {
        "transition_required": true,
        "first_stable_id": "a",
        "second_stable_id": "b",
        "first_side": "east",
        "second_side": "west",
        "edge_key": "a|b",
        "owner_stable_id": "a"
    }
    var numeric_key_result: Dictionary = manager.call("sync_transitions", {7: valid_descriptor}, {})
    _expect(not bool(numeric_key_result.get("ok", true)) and str(numeric_key_result.get("error", "")) == "invalid_edge_key", "manager rejects non-string edge keys before coercion")
    var numeric_id_descriptor: Dictionary = valid_descriptor.duplicate(true)
    numeric_id_descriptor["first_stable_id"] = 7
    numeric_id_descriptor["edge_key"] = "7|b"
    numeric_id_descriptor["owner_stable_id"] = "7"
    var numeric_id_result: Dictionary = manager.call("sync_transitions", {"7|b": numeric_id_descriptor}, {})
    _expect(not bool(numeric_id_result.get("ok", true)) and str(numeric_id_result.get("error", "")) == "invalid_stable_ids", "manager rejects non-string stable IDs before patch lookup")
    var numeric_side_descriptor: Dictionary = valid_descriptor.duplicate(true)
    numeric_side_descriptor["first_side"] = 1
    var numeric_side_result: Dictionary = manager.call("sync_transitions", {"a|b": numeric_side_descriptor}, {})
    _expect(not bool(numeric_side_result.get("ok", true)) and str(numeric_side_result.get("error", "")) == "invalid_edge_sides", "manager rejects non-string side values before coercion")
    manager.free()


func _test_manager_rejects_mismatched_cardinal_side() -> void:
    var holder := Node3D.new()
    holder.name = "TransitionSideMismatchTestRoot"
    root.add_child(holder)
    var lower: Node3D = PatchScript.new()
    lower.name = "Lower"
    var higher: Node3D = PatchScript.new()
    higher.name = "Higher"
    higher.position = Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0)
    holder.add_child(lower)
    holder.add_child(higher)
    await process_frame
    lower.call("apply_world_object_state", {"height_level": 0, "surface_type": "soil", "revision": 1})
    higher.call("apply_world_object_state", {"height_level": 2, "surface_type": "metal", "revision": 1})
    var stable_ids := {
        lower.get_instance_id(): "a/side-mismatch/lower",
        higher.get_instance_id(): "z/side-mismatch/higher"
    }
    var binding: Dictionary = BinderScript.bind_patches([lower, higher], stable_ids)
    _expect(bool(binding.get("ok", false)), "side-mismatch fixture receives a valid east/west descriptor")
    var descriptors: Dictionary = binding.get("descriptors", {}).duplicate(true)
    var edge_key: String = ""
    for key in descriptors.keys():
        edge_key = str(key)
    if edge_key.is_empty():
        holder.queue_free()
        await process_frame
        return
    var malformed: Dictionary = descriptors[edge_key].duplicate(true)
    malformed["first_side"] = "north"
    malformed["second_side"] = "south"
    descriptors[edge_key] = malformed
    var patches := {
        "a/side-mismatch/lower": lower,
        "z/side-mismatch/higher": higher
    }
    var manager: Node3D = ManagerScript.new()
    holder.add_child(manager)
    var report: Dictionary = manager.call("sync_transitions", descriptors, patches)
    _expect(not bool(report.get("ok", true)), "manager rejects a cardinal side that disagrees with patch positions")
    _expect(str(report.get("error", "")) == "descriptor_side_mismatch", "side mismatch returns a stable diagnostic code")
    _expect(int(manager.call("get_transition_count")) == 0, "invalid orientation creates no shared collider")
    _expect(not bool(lower.call("is_shared_transition_active", "east")) and not bool(lower.call("is_shared_transition_active", "north")), "invalid orientation leaves lower patch collision strips untouched")
    _expect(not bool(higher.call("is_shared_transition_active", "west")) and not bool(higher.call("is_shared_transition_active", "south")), "invalid orientation leaves higher patch collision strips untouched")
    holder.queue_free()
    await process_frame
    await process_frame


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
