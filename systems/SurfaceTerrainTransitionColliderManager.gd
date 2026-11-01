extends Node3D
class_name SurfaceTerrainTransitionColliderManager

## Owns exactly one shared ramp collider/visual for each accepted unequal-height edge.
## A patch pair is activated only after every candidate edge has passed preflight and staging.
const COLLISION_LAYER: int = 1
const COLLISION_THICKNESS: float = 0.04
const EDGE_RUN_PER_PATCH: float = 0.75
const POSITION_TOLERANCE: float = 0.01
const VALID_SIDES: Array[String] = ["east", "west", "north", "south"]

var _managed_edges: Dictionary = {}

func sync_transitions(descriptors: Dictionary, patches_by_stable_id: Dictionary) -> Dictionary:
    var candidates: Dictionary = {}
    for edge_key_value in descriptors.keys():
        var edge_key: String = str(edge_key_value)
        var descriptor: Dictionary = descriptors[edge_key_value]
        if not bool(descriptor.get("transition_required", false)):
            continue
        var first_id: String = str(descriptor.get("first_stable_id", ""))
        var second_id: String = str(descriptor.get("second_stable_id", ""))
        var first_side: String = str(descriptor.get("first_side", ""))
        var second_side: String = str(descriptor.get("second_side", ""))
        var first_patch: Node3D = patches_by_stable_id.get(first_id) as Node3D
        var second_patch: Node3D = patches_by_stable_id.get(second_id) as Node3D
        if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
            return {"ok": false, "error": "invalid_stable_ids", "active_count": _managed_edges.size()}
        if not VALID_SIDES.has(first_side) or not VALID_SIDES.has(second_side):
            return {"ok": false, "error": "invalid_edge_sides", "active_count": _managed_edges.size()}
        if not is_instance_valid(first_patch) or not is_instance_valid(second_patch):
            return {"ok": false, "error": "missing_live_patch", "active_count": _managed_edges.size()}
        if not first_patch.has_method("set_shared_transition_active") or not second_patch.has_method("set_shared_transition_active"):
            return {"ok": false, "error": "patch_missing_transition_api", "active_count": _managed_edges.size()}
        var geometry: Dictionary = _build_geometry(first_patch, second_patch, descriptor)
        if not bool(geometry.get("ok", false)):
            return {"ok": false, "error": str(geometry.get("error", "invalid_geometry")), "active_count": _managed_edges.size()}
        candidates[edge_key] = {
            "first_id": first_id,
            "second_id": second_id,
            "first_side": first_side,
            "second_side": second_side,
            "first_patch": first_patch,
            "second_patch": second_patch,
            "geometry": geometry
        }

    var blocked_edges: Dictionary = _find_perpendicular_conflicts(candidates)
    var staged: Dictionary = {}
    for edge_key in candidates.keys():
        if blocked_edges.has(edge_key):
            continue
        var edge: Dictionary = candidates[edge_key]
        var staged_edge: Dictionary = _stage_edge(str(edge_key), edge)
        if staged_edge.is_empty():
            _free_staged(staged)
            return {"ok": false, "error": "edge_staging_failed", "active_count": _managed_edges.size()}
        staged[str(edge_key)] = staged_edge

    var newly_activated: Array[Dictionary] = []
    for edge_key in staged.keys():
        var edge: Dictionary = staged[edge_key]
        var first_patch: Node3D = edge["first_patch"]
        var second_patch: Node3D = edge["second_patch"]
        var first_side: String = str(edge["first_side"])
        var second_side: String = str(edge["second_side"])
        var first_was_active: bool = bool(first_patch.call("is_shared_transition_active", first_side)) if first_patch.has_method("is_shared_transition_active") else false
        var second_was_active: bool = bool(second_patch.call("is_shared_transition_active", second_side)) if second_patch.has_method("is_shared_transition_active") else false
        var first_activated: bool = bool(first_patch.call("set_shared_transition_active", first_side, true))
        if not first_activated:
            for activation in newly_activated:
                var activated_patch: Node3D = activation["patch"]
                if is_instance_valid(activated_patch):
                    activated_patch.call("set_shared_transition_active", str(activation["side"]), false)
            _free_staged(staged)
            return {"ok": false, "error": "first_patch_activation_failed", "active_count": _managed_edges.size()}
        if not first_was_active:
            newly_activated.append({"patch": first_patch, "side": first_side})
        var second_activated: bool = bool(second_patch.call("set_shared_transition_active", second_side, true))
        if not second_activated:
            if not first_was_active:
                first_patch.call("set_shared_transition_active", first_side, false)
            for activation in newly_activated:
                var activated_patch: Node3D = activation["patch"]
                if is_instance_valid(activated_patch):
                    activated_patch.call("set_shared_transition_active", str(activation["side"]), false)
            _free_staged(staged)
            return {"ok": false, "error": "second_patch_activation_failed", "active_count": _managed_edges.size()}
        if not second_was_active:
            newly_activated.append({"patch": second_patch, "side": second_side})

    for old_key in _managed_edges.keys():
        var old_edge: Dictionary = _managed_edges[old_key]
        var replacement: Dictionary = staged.get(str(old_key), {})
        _retire_old_edge(old_edge, replacement)

    for edge_key in staged.keys():
        var edge: Dictionary = staged[edge_key]
        var body: StaticBody3D = edge["body"] as StaticBody3D
        body.collision_layer = COLLISION_LAYER
    _managed_edges = staged
    return {
        "ok": true,
        "active_count": _managed_edges.size(),
        "blocked_count": blocked_edges.size(),
        "blocked_edge_keys": blocked_edges.keys()
    }

func clear_all() -> void:
    for edge in _managed_edges.values():
        _retire_old_edge(edge, {})
    _managed_edges.clear()

func get_transition_count() -> int:
    return _managed_edges.size()

func get_transition_body(edge_key: String) -> StaticBody3D:
    var edge: Dictionary = _managed_edges.get(edge_key, {})
    var body: StaticBody3D = edge.get("body") as StaticBody3D
    return body if is_instance_valid(body) else null

func _build_geometry(first_patch: Node3D, second_patch: Node3D, descriptor: Dictionary) -> Dictionary:
    for key in ["first_top_height", "second_top_height", "patch_size", "height_delta"]:
        if not descriptor.has(key):
            return {"ok": false, "error": "missing_descriptor_" + key}
    var patch_size: float = float(descriptor["patch_size"])
    if is_nan(patch_size) or is_inf(patch_size) or patch_size <= 0.0:
        return {"ok": false, "error": "invalid_patch_size"}
    var first_position: Vector3 = first_patch.global_position
    var second_position: Vector3 = second_patch.global_position
    var horizontal_delta := Vector3(second_position.x - first_position.x, 0.0, second_position.z - first_position.z)
    if absf(first_position.y - second_position.y) > POSITION_TOLERANCE or absf(horizontal_delta.length() - patch_size) > POSITION_TOLERANCE:
        return {"ok": false, "error": "patches_not_level_cardinal_neighbors"}
    var first_top: float = float(descriptor["first_top_height"])
    var second_top: float = float(descriptor["second_top_height"])
    var height_delta: float = absf(first_top - second_top)
    if height_delta <= POSITION_TOLERANCE or absf(height_delta - float(descriptor["height_delta"])) > POSITION_TOLERANCE:
        return {"ok": false, "error": "descriptor_height_mismatch"}
    var low_patch: Node3D = first_patch if first_top < second_top else second_patch
    var high_patch: Node3D = second_patch if first_top < second_top else first_patch
    var low_top: float = minf(first_top, second_top)
    var high_top: float = maxf(first_top, second_top)
    var horizontal_direction := high_patch.global_position - low_patch.global_position
    horizontal_direction.y = 0.0
    horizontal_direction = horizontal_direction.normalized()
    var run: float = minf(EDGE_RUN_PER_PATCH, patch_size * 0.45)
    var total_run: float = run * 2.0
    var tangent := (horizontal_direction * total_run + Vector3.UP * height_delta).normalized()
    var width_axis := tangent.cross(Vector3.UP).normalized()
    var normal := width_axis.cross(tangent).normalized()
    if normal.y <= 0.0:
        return {"ok": false, "error": "invalid_transition_basis"}
    var basis := Basis(tangent, normal, width_axis)
    var seam_center := (first_position + second_position) * 0.5
    var center := Vector3(seam_center.x, (low_top + high_top) * 0.5, seam_center.z)
    var slope_length: float = sqrt(total_run * total_run + height_delta * height_delta)
    return {
        "ok": true,
        "basis": basis,
        "center": center,
        "body_origin": center - normal * (COLLISION_THICKNESS * 0.5),
        "slope_length": slope_length,
        "patch_size": patch_size,
        "low_top": low_top,
        "high_top": high_top,
        "horizontal_run": total_run
    }

func _stage_edge(edge_key: String, edge: Dictionary) -> Dictionary:
    var geometry: Dictionary = edge["geometry"]
    var body := StaticBody3D.new()
    body.name = "TerrainTransition_" + str(abs(hash(edge_key)))
    body.collision_layer = 0
    body.collision_mask = 0
    var collision := CollisionShape3D.new()
    collision.name = "SharedTransitionCollision"
    var box := BoxShape3D.new()
    box.size = Vector3(float(geometry["slope_length"]), COLLISION_THICKNESS, float(geometry["patch_size"]))
    collision.shape = box
    body.add_child(collision)
    var visual := MeshInstance3D.new()
    visual.name = "SharedTransitionVisual"
    var plane := PlaneMesh.new()
    plane.size = Vector2(float(geometry["slope_length"]), float(geometry["patch_size"]))
    visual.mesh = plane
    visual.position = Vector3(0.0, COLLISION_THICKNESS * 0.5, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#9bb7b5")
    material.roughness = 0.82
    material.metallic = 0.12
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    visual.material_override = material
    body.add_child(visual)
    add_child(body)
    body.global_transform = Transform3D(geometry["basis"], geometry["body_origin"])
    return {
        "body": body,
        "first_patch": edge["first_patch"],
        "second_patch": edge["second_patch"],
        "first_side": edge["first_side"],
        "second_side": edge["second_side"],
        "first_id": edge["first_id"],
        "second_id": edge["second_id"]
    }

func _find_perpendicular_conflicts(candidates: Dictionary) -> Dictionary:
    var sides_by_patch: Dictionary = {}
    for edge_key in candidates.keys():
        var edge: Dictionary = candidates[edge_key]
        _record_side(sides_by_patch, str(edge["first_id"]), str(edge["first_side"]), str(edge_key))
        _record_side(sides_by_patch, str(edge["second_id"]), str(edge["second_side"]), str(edge_key))
    var blocked: Dictionary = {}
    for stable_id in sides_by_patch.keys():
        var entries: Array = sides_by_patch[stable_id]
        for first_index in range(entries.size()):
            for second_index in range(first_index + 1, entries.size()):
                var first_side: String = str(entries[first_index]["side"])
                var second_side: String = str(entries[second_index]["side"])
                if first_side == second_side or _opposite_side(first_side) == second_side:
                    continue
                blocked[str(entries[first_index]["edge_key"])] = true
                blocked[str(entries[second_index]["edge_key"])] = true
    return blocked

func _record_side(target: Dictionary, stable_id: String, side: String, edge_key: String) -> void:
    if not target.has(stable_id):
        target[stable_id] = []
    target[stable_id].append({"side": side, "edge_key": edge_key})

func _retire_old_edge(old_edge: Dictionary, replacement: Dictionary) -> void:
    var old_first: Node3D = old_edge.get("first_patch") as Node3D
    var old_second: Node3D = old_edge.get("second_patch") as Node3D
    var old_body: StaticBody3D = old_edge.get("body") as StaticBody3D
    if is_instance_valid(old_first):
        var replacement_first: Node3D = replacement.get("first_patch") as Node3D
        if replacement_first != old_first or str(replacement.get("first_side", "")) != str(old_edge.get("first_side", "")):
            old_first.call("set_shared_transition_active", str(old_edge["first_side"]), false)
    if is_instance_valid(old_second):
        var replacement_second: Node3D = replacement.get("second_patch") as Node3D
        if replacement_second != old_second or str(replacement.get("second_side", "")) != str(old_edge.get("second_side", "")):
            old_second.call("set_shared_transition_active", str(old_edge["second_side"]), false)
    if is_instance_valid(old_body):
        old_body.collision_layer = 0
        old_body.queue_free()

func _free_staged(staged: Dictionary) -> void:
    for edge in staged.values():
        var body: StaticBody3D = edge.get("body") as StaticBody3D
        if is_instance_valid(body):
            body.collision_layer = 0
            body.queue_free()

func _opposite_side(side: String) -> String:
    match side:
        "east": return "west"
        "west": return "east"
        "north": return "south"
        "south": return "north"
        _: return ""
