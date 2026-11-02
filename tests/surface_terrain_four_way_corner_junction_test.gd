extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const BinderScript = preload("res://systems/SurfaceTerrainAdjacencyBinder.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _test_four_way_junction_falls_back_atomically()
    if failures.is_empty():
        print("Four-way terrain corner junction regression passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_four_way_junction_falls_back_atomically() -> void:
    var holder := Node3D.new()
    holder.name = "FourWayCornerJunctionTestRoot"
    root.add_child(holder)

    var north_west: Node3D = PatchScript.new()
    north_west.name = "NorthWest"
    north_west.position = Vector3(0.0, 0.0, 0.0)
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
    _expect(bool(north_west.call("apply_world_object_state", high_state)), "north-west patch accepts its high state")
    _expect(bool(north_east.call("apply_world_object_state", low_state)), "north-east patch accepts its low state")
    _expect(bool(south_west.call("apply_world_object_state", low_state)), "south-west patch accepts its low state")
    _expect(bool(south_east.call("apply_world_object_state", high_state)), "south-east patch accepts its high state")

    var stable_ids := {
        north_west.get_instance_id(): "corner/nw",
        north_east.get_instance_id(): "corner/ne",
        south_west.get_instance_id(): "corner/sw",
        south_east.get_instance_id(): "corner/se"
    }
    var binding: Dictionary = BinderScript.bind_patches([north_west, north_east, south_west, south_east], stable_ids)
    _expect(bool(binding.get("ok", false)), "four live patches bind into a 2x2 terrain junction")
    _expect(int(binding.get("pair_count", -1)) == 4, "four unequal cardinal edges meet at the central corner")
    if not bool(binding.get("ok", false)):
        holder.queue_free()
        await process_frame
        return

    var patches := {
        "corner/nw": north_west,
        "corner/ne": north_east,
        "corner/sw": south_west,
        "corner/se": south_east
    }
    var manager: Node3D = ManagerScript.new()
    holder.add_child(manager)
    var descriptors: Dictionary = binding.get("descriptors", {}).duplicate(true)
    var report: Dictionary = manager.call("sync_transitions", descriptors, patches)
    _expect(bool(report.get("ok", false)), "manager accepts the valid four-way topology")
    _expect(int(report.get("active_count", -1)) == 0, "no edge ramp is staged through the unresolved four-way junction")
    _expect(int(report.get("blocked_count", -1)) == 4, "all four intersecting ramps are blocked atomically")
    _expect(int(manager.call("get_transition_count")) == 0, "manager owns no partial shared collider after fallback")
    _expect(manager.get_child_count() == 0, "no staged collider node remains under the manager")

    var expected_corners := {
        "corner/nw": "south_east",
        "corner/ne": "south_west",
        "corner/sw": "north_east",
        "corner/se": "north_west"
    }
    var reports: Array = report.get("blocked_corner_reports", [])
    _expect(reports.size() == 4, "one deterministic report is emitted for each patch at the four-way junction")
    var seen_reports: Dictionary = {}
    for report_value in reports:
        if not (report_value is Dictionary):
            _expect(false, "corner report is a dictionary")
            continue
        var stable_id: String = str(report_value.get("stable_id", ""))
        seen_reports[stable_id] = str(report_value.get("corner", ""))
        _expect(str(report_value.get("policy", "")) == "step_fallback", "four-way report retains the safe step fallback")
        _expect(report_value.get("edge_keys", []).size() == 2, "each local corner report identifies both participating edges")
    _expect(seen_reports == expected_corners, "all four patch corners map to the correct compass orientation")

    var blocked_keys: Array = report.get("blocked_edge_keys", [])
    var sorted_keys: Array = blocked_keys.duplicate()
    sorted_keys.sort()
    _expect(blocked_keys.size() == 4 and blocked_keys == sorted_keys, "all four blocked edge keys are returned in stable order")
    for edge_key in descriptors.keys():
        _expect(blocked_keys.has(edge_key), "junction report includes descriptor " + str(edge_key))

    for patch in [north_west, north_east, south_west, south_east]:
        var base_collision := patch.get_node("TerrainCollisionBody/TerrainCollisionShape") as CollisionShape3D
        _expect(base_collision != null and not base_collision.disabled, "full patch collision remains active under step fallback")
        for side in ["east", "west", "north", "south"]:
            _expect(not bool(patch.call("is_shared_transition_active", side)), "no shared edge strip is cut during four-way fallback")

    var reversed_descriptors: Dictionary = {}
    var descriptor_keys: Array = descriptors.keys()
    descriptor_keys.reverse()
    for edge_key in descriptor_keys:
        reversed_descriptors[edge_key] = descriptors[edge_key]
    var reversed_report: Dictionary = manager.call("sync_transitions", reversed_descriptors, patches)
    _expect(bool(reversed_report.get("ok", false)), "reversed descriptor insertion order is accepted")
    _expect(reversed_report.get("blocked_corner_reports", []) == reports, "four-way reports are invariant to descriptor insertion order")
    _expect(reversed_report.get("blocked_edge_keys", []) == blocked_keys, "blocked edge ordering is invariant to descriptor insertion order")

    holder.queue_free()
    await process_frame
    await process_frame

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
