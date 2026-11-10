extends SceneTree

const PatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const DescriptorScript = preload("res://systems/SurfaceTerrainTransitionDescriptor.gd")
const ManagerScript = preload("res://systems/SurfaceTerrainTransitionColliderManager.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await _test_partial_replacement_preserves_unaffected_edge()
    await _test_partial_removal_preserves_unaffected_edge()
    await _test_underseeded_change_fails_closed()
    await _test_partial_junction_uses_committed_weak_refs_without_edge_bodies()
    await _test_connected_two_junction_closure_preserves_unrelated_edge()
    if failures.is_empty():
        print("Surface terrain partial collider transaction tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error("FAIL: " + failure)
    quit(1)


func _test_partial_replacement_preserves_unaffected_edge() -> void:
    var fixture: Dictionary = await _make_two_pair_fixture()
    if fixture.is_empty():
        return
    var manager: Node3D = fixture["manager"]
    var holder: Node3D = fixture["holder"]
    var edge_a: String = str(fixture["edge_a"])
    var edge_b: String = str(fixture["edge_b"])
    var old_a: StaticBody3D = manager.call("get_transition_body", edge_a) as StaticBody3D
    var old_b: StaticBody3D = manager.call("get_transition_body", edge_b) as StaticBody3D

    _expect(_apply_height(fixture["b1"], 1), "changed patch accepts a new height")
    var candidate_descriptors: Dictionary = _build_descriptors(fixture["pairs"])
    var prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        fixture["patches_by_stable_id"],
        [edge_a]
    )
    _expect(bool(prepared.get("ok", false)), "partial replacement prepare succeeds")
    if not bool(prepared.get("ok", false)):
        await _release_holder(holder)
        return
    _expect(int(prepared.get("pending_staged_edge_count", -1)) == 1, "partial replacement stages only the changed edge")
    _expect(int(prepared.get("pending_reused_edge_count", -1)) == 1, "partial replacement preserves the unrelated edge")
    _expect(manager.call("get_transition_body", edge_a) == old_a, "prepare leaves the committed changed edge untouched")
    _expect(manager.call("get_transition_body", edge_b) == old_b, "prepare leaves the unrelated committed edge untouched")

    var transaction_id: int = int(prepared.get("transaction_id", -1))
    var committed: Dictionary = manager.call("commit_sync_transitions", transaction_id)
    _expect(bool(committed.get("ok", false)), "partial replacement commit succeeds")
    _expect(bool(committed.get("partial_update", false)), "commit reports the partial-update mode")
    _expect(int(committed.get("affected_edge_count", -1)) == 1, "commit reports one affected edge")
    var new_a: StaticBody3D = manager.call("get_transition_body", edge_a) as StaticBody3D
    var current_b: StaticBody3D = manager.call("get_transition_body", edge_b) as StaticBody3D
    _expect(is_instance_valid(new_a) and new_a != old_a, "changed edge receives a replacement body")
    _expect(is_instance_valid(current_b) and current_b == old_b, "unrelated edge retains its exact original body")
    _expect(is_instance_valid(new_a) and new_a.collision_layer == 1 and new_a.collision_mask == 0, "replacement edge publishes canonical collision state")
    _expect(int(committed.get("staged_edge_count", -1)) == 1, "commit reports one staged edge")
    _expect(int(committed.get("retired_edge_count", -1)) == 1, "commit retires only the replaced old edge")
    await process_frame
    await process_frame
    _expect(not is_instance_valid(old_a), "replaced old edge is released")
    await _release_holder(holder)


func _test_partial_removal_preserves_unaffected_edge() -> void:
    var fixture: Dictionary = await _make_two_pair_fixture()
    if fixture.is_empty():
        return
    var manager: Node3D = fixture["manager"]
    var holder: Node3D = fixture["holder"]
    var edge_a: String = str(fixture["edge_a"])
    var edge_b: String = str(fixture["edge_b"])
    var old_a: StaticBody3D = manager.call("get_transition_body", edge_a) as StaticBody3D
    var old_b: StaticBody3D = manager.call("get_transition_body", edge_b) as StaticBody3D
    var candidate_descriptors: Dictionary = _build_descriptors([fixture["pair_a"]])
    var candidate_patch_map: Dictionary = {
        "pair/a": fixture["a1"],
        "pair/b": fixture["b1"]
    }

    var prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        candidate_patch_map,
        [edge_b]
    )
    _expect(bool(prepared.get("ok", false)), "partial removal prepare succeeds")
    if not bool(prepared.get("ok", false)):
        await _release_holder(holder)
        return
    _expect(int(prepared.get("pending_staged_edge_count", -1)) == 0, "partial removal stages no replacement edge")
    _expect(int(prepared.get("pending_reused_edge_count", -1)) == 1, "partial removal preserves the unrelated edge")
    var committed: Dictionary = manager.call("commit_sync_transitions", int(prepared.get("transaction_id", -1)))
    _expect(bool(committed.get("ok", false)), "partial removal commit succeeds")
    _expect(manager.call("get_transition_body", edge_a) == old_a, "partial removal keeps the unrelated edge instance")
    _expect(manager.call("get_transition_body", edge_b) == null, "partial removal removes the targeted edge")
    _expect(int(committed.get("retired_edge_count", -1)) == 1, "partial removal retires exactly one old edge")
    _expect(not bool(fixture["a2"].call("is_shared_transition_active", "east")), "removed edge deactivates its old first patch side")
    _expect(not bool(fixture["b2"].call("is_shared_transition_active", "west")), "removed edge deactivates its old second patch side")
    await process_frame
    await process_frame
    _expect(not is_instance_valid(old_b), "removed old edge is released")
    await _release_holder(holder)


func _test_underseeded_change_fails_closed() -> void:
    var fixture: Dictionary = await _make_two_pair_fixture()
    if fixture.is_empty():
        return
    var manager: Node3D = fixture["manager"]
    var holder: Node3D = fixture["holder"]
    var old_a: StaticBody3D = manager.call("get_transition_body", str(fixture["edge_a"])) as StaticBody3D
    var old_b: StaticBody3D = manager.call("get_transition_body", str(fixture["edge_b"])) as StaticBody3D
    _expect(_apply_height(fixture["b1"], 1), "first changed patch accepts a new height")
    _expect(_apply_height(fixture["b2"], 1), "second changed patch accepts a new height")
    var candidate_descriptors: Dictionary = _build_descriptors(fixture["pairs"])
    var rejected: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        fixture["patches_by_stable_id"],
        [str(fixture["edge_a"])]
    )
    _expect(not bool(rejected.get("ok", true)), "partial prepare rejects an incomplete changed-edge seed list")
    _expect(
        str(rejected.get("error", "")) == "candidate_edge_changed_outside_affected_closure",
        "under-seeded partial update reports the changed edge outside the closure"
    )
    _expect(manager.call("get_transition_body", str(fixture["edge_a"])) == old_a, "under-seeded rejection preserves the first committed edge")
    _expect(manager.call("get_transition_body", str(fixture["edge_b"])) == old_b, "under-seeded rejection preserves the second committed edge")
    var pending: Dictionary = manager.get("_pending_sync_transaction")
    _expect(pending.is_empty(), "under-seeded rejection leaves no pending transaction")
    await _release_holder(holder)


func _test_partial_junction_uses_committed_weak_refs_without_edge_bodies() -> void:
    var holder := Node3D.new()
    holder.name = "PartialJunctionWeakRefFixture"
    root.add_child(holder)
    await process_frame
    var nw: Node3D = _new_patch(holder, "NW", Vector3.ZERO)
    var ne: Node3D = _new_patch(holder, "NE", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
    var sw: Node3D = _new_patch(holder, "SW", Vector3(0.0, 0.0, PatchScript.PATCH_SIZE))
    var se: Node3D = _new_patch(holder, "SE", Vector3(PatchScript.PATCH_SIZE, 0.0, PatchScript.PATCH_SIZE))
    await process_frame
    _expect(_apply_height(nw, 0), "weak-ref junction NW state is valid")
    _expect(_apply_height(ne, 2), "weak-ref junction NE state is valid")
    _expect(_apply_height(sw, 2), "weak-ref junction SW state is valid")
    _expect(_apply_height(se, 1), "weak-ref junction SE initial state is valid")

    var pairs: Array[Dictionary] = [
        _bind_pair(nw, "cap/nw", "east", ne, "cap/ne", "west"),
        _bind_pair(sw, "cap/sw", "east", se, "cap/se", "west"),
        _bind_pair(nw, "cap/nw", "south", sw, "cap/sw", "north"),
        _bind_pair(ne, "cap/ne", "south", se, "cap/se", "north")
    ]
    var patch_map: Dictionary = {
        "cap/nw": nw,
        "cap/ne": ne,
        "cap/sw": sw,
        "cap/se": se
    }
    var initial_descriptors: Dictionary = _build_descriptors(pairs)
    _expect(initial_descriptors.size() == 4, "weak-ref junction starts with four transition descriptors")
    var manager := ManagerScript.new()
    manager.name = "WeakRefJunctionManager"
    holder.add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call("sync_transitions", initial_descriptors, patch_map)
    _expect(bool(initial.get("ok", false)), "ineligible initial junction commits its fallback topology")
    _expect(manager.call("get_transition_count") == 0, "ineligible initial junction has no managed edge bodies")
    _expect(manager.call("get_corner_cap_count") == 0, "ineligible initial junction has no corner-cap bodies")
    var initial_reports: Variant = manager.call("get_blocked_corner_reports")
    _expect(initial_reports is Array and initial_reports.size() == 4, "ineligible initial junction still stores four committed corner reports")
    if not bool(initial.get("ok", false)):
        await _release_holder(holder)
        return

    _expect(_apply_height(se, 0), "candidate SE state restores matching junction midpoint heights")
    var candidate_descriptors: Dictionary = _build_descriptors(pairs)
    var edge_ne_se: String = _edge_key_for_pair_ids(candidate_descriptors, "cap/ne", "cap/se")
    var edge_sw_se: String = _edge_key_for_pair_ids(candidate_descriptors, "cap/sw", "cap/se")
    var prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        patch_map,
        [edge_ne_se, edge_sw_se]
    )
    _expect(bool(prepared.get("ok", false)), "partial junction prepare resolves old reports through committed WeakRefs")
    if not bool(prepared.get("ok", false)):
        await _release_holder(holder)
        return
    _expect(int(prepared.get("affected_edge_count", -1)) == 4, "single-junction closure includes all four transition edges")
    _expect(int(prepared.get("affected_junction_count", -1)) == 1, "single-junction closure includes exactly one junction")
    _expect(int(prepared.get("pending_staged_edge_count", -1)) == 4, "newly eligible junction stages its four edge resources")
    _expect(int(prepared.get("pending_staged_corner_cap_count", -1)) == 4, "newly eligible junction stages all four corner caps")
    var committed: Dictionary = manager.call("commit_sync_transitions", int(prepared.get("transaction_id", -1)))
    _expect(bool(committed.get("ok", false)), "weak-ref junction partial commit succeeds")
    _expect(int(manager.call("get_transition_count")) == 4, "weak-ref junction publishes four edge resources")
    _expect(int(manager.call("get_corner_cap_count")) == 4, "weak-ref junction publishes four corner caps")
    await _release_holder(holder)


func _test_connected_two_junction_closure_preserves_unrelated_edge() -> void:
    var fixture: Dictionary = await _make_connected_junction_fixture()
    if fixture.is_empty():
        return
    var holder: Node3D = fixture["holder"]
    var manager: Node3D = fixture["manager"]
    var independent_edge: String = str(fixture["independent_edge"])
    var independent_body: StaticBody3D = manager.call("get_transition_body", independent_edge) as StaticBody3D
    var old_grid_edges: Dictionary = {}
    for edge_key_value in fixture["grid_edge_keys"]:
        var edge_key: String = str(edge_key_value)
        old_grid_edges[edge_key] = manager.call("get_transition_body", edge_key)
    var old_caps: Dictionary = manager.get("_managed_corner_caps").duplicate(false)
    _expect(int(manager.call("get_corner_cap_count")) == 8, "connected fixture begins with eight eligible corner caps")

    _expect(_apply_height(fixture["nw"], 1), "changed NW patch accepts a new height")
    var candidate_descriptors: Dictionary = _build_descriptors(fixture["pairs"])
    var prepared: Dictionary = manager.call(
        "prepare_partial_sync_transitions",
        candidate_descriptors,
        fixture["patches_by_stable_id"],
        [str(fixture["seed_ab"]), str(fixture["seed_ad"])]
    )
    _expect(bool(prepared.get("ok", false)), "connected two-junction partial prepare succeeds")
    if not bool(prepared.get("ok", false)):
        await _release_holder(holder)
        return
    _expect(int(prepared.get("affected_edge_count", -1)) == 7, "connected closure reaches all seven grid edges")
    _expect(int(prepared.get("affected_junction_count", -1)) == 2, "connected closure crosses the shared edge into both junctions")
    _expect(int(prepared.get("pending_reused_edge_count", -1)) >= 1, "partial plan preserves the unrelated independent edge")
    _expect(manager.call("get_transition_body", independent_edge) == independent_body, "prepare keeps the unrelated edge committed")

    var committed: Dictionary = manager.call("commit_sync_transitions", int(prepared.get("transaction_id", -1)))
    _expect(bool(committed.get("ok", false)), "connected two-junction partial commit succeeds")
    _expect(int(committed.get("retired_edge_count", -1)) == 7, "connected fallback retires only the seven affected grid edges")
    _expect(int(committed.get("retired_corner_cap_count", -1)) == 8, "connected fallback retires all eight caps across both linked junctions")
    _expect(manager.call("get_transition_body", independent_edge) == independent_body, "unrelated independent edge retains its exact Node instance")
    _expect(int(manager.call("get_transition_count")) == 1, "only the unrelated independent edge remains managed")
    _expect(int(manager.call("get_corner_cap_count")) == 0, "both linked junctions fall back without corner caps")
    await process_frame
    await process_frame
    for edge_key_value in old_grid_edges.keys():
        var old_body: StaticBody3D = old_grid_edges[edge_key_value] as StaticBody3D
        _expect(not is_instance_valid(old_body), "retired connected grid edge is released: " + str(edge_key_value))
    for cap_key_value in old_caps.keys():
        var old_cap: Dictionary = old_caps[cap_key_value]
        var old_body: StaticBody3D = old_cap.get("body") as StaticBody3D
        _expect(not is_instance_valid(old_body), "retired connected corner cap is released: " + str(cap_key_value))
    await _release_holder(holder)


func _make_connected_junction_fixture() -> Dictionary:
    var holder := Node3D.new()
    holder.name = "ConnectedTwoJunctionPartialFixture"
    root.add_child(holder)
    await process_frame
    var nw: Node3D = _new_patch(holder, "NW", Vector3.ZERO)
    var ne: Node3D = _new_patch(holder, "NE", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
    var n2: Node3D = _new_patch(holder, "N2", Vector3(PatchScript.PATCH_SIZE * 2.0, 0.0, 0.0))
    var sw: Node3D = _new_patch(holder, "SW", Vector3(0.0, 0.0, PatchScript.PATCH_SIZE))
    var se: Node3D = _new_patch(holder, "SE", Vector3(PatchScript.PATCH_SIZE, 0.0, PatchScript.PATCH_SIZE))
    var s2: Node3D = _new_patch(holder, "S2", Vector3(PatchScript.PATCH_SIZE * 2.0, 0.0, PatchScript.PATCH_SIZE))
    var solo_a: Node3D = _new_patch(holder, "SoloA", Vector3(100.0, 0.0, 0.0))
    var solo_b: Node3D = _new_patch(holder, "SoloB", Vector3(100.0 + PatchScript.PATCH_SIZE, 0.0, 0.0))
    await process_frame
    for pair in [
        {"patch": nw, "height": 0},
        {"patch": ne, "height": 2},
        {"patch": n2, "height": 0},
        {"patch": sw, "height": 2},
        {"patch": se, "height": 0},
        {"patch": s2, "height": 2},
        {"patch": solo_a, "height": 0},
        {"patch": solo_b, "height": 2}
    ]:
        _expect(_apply_height(pair["patch"], int(pair["height"])), "connected fixture patch state is valid: " + str(pair["patch"].name))

    var pairs: Array[Dictionary] = [
        _bind_pair(nw, "grid/nw", "east", ne, "grid/ne", "west"),
        _bind_pair(ne, "grid/ne", "east", n2, "grid/n2", "west"),
        _bind_pair(sw, "grid/sw", "east", se, "grid/se", "west"),
        _bind_pair(se, "grid/se", "east", s2, "grid/s2", "west"),
        _bind_pair(nw, "grid/nw", "south", sw, "grid/sw", "north"),
        _bind_pair(ne, "grid/ne", "south", se, "grid/se", "north"),
        _bind_pair(n2, "grid/n2", "south", s2, "grid/s2", "north"),
        _bind_pair(solo_a, "solo/a", "east", solo_b, "solo/b", "west")
    ]
    var patch_map: Dictionary = {
        "grid/nw": nw,
        "grid/ne": ne,
        "grid/n2": n2,
        "grid/sw": sw,
        "grid/se": se,
        "grid/s2": s2,
        "solo/a": solo_a,
        "solo/b": solo_b
    }
    var descriptors: Dictionary = _build_descriptors(pairs)
    _expect(descriptors.size() == 8, "connected fixture builds seven grid edges and one independent edge")
    var manager := ManagerScript.new()
    manager.name = "ConnectedTwoJunctionManager"
    holder.add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call("sync_transitions", descriptors, patch_map)
    _expect(bool(initial.get("ok", false)), "connected fixture initial full rebuild succeeds")
    if not bool(initial.get("ok", false)):
        await _release_holder(holder)
        return {}
    var grid_edges: Array[String] = []
    for pair_index in range(7):
        var pair: Dictionary = pairs[pair_index]
        grid_edges.append(_edge_key_for_pair_ids(descriptors, str(pair["first_id"]), str(pair["second_id"])))
    return {
        "holder": holder,
        "manager": manager,
        "nw": nw,
        "pairs": pairs,
        "patches_by_stable_id": patch_map,
        "grid_edge_keys": grid_edges,
        "independent_edge": _edge_key_for_pair_ids(descriptors, "solo/a", "solo/b"),
        "seed_ab": _edge_key_for_pair_ids(descriptors, "grid/nw", "grid/ne"),
        "seed_ad": _edge_key_for_pair_ids(descriptors, "grid/nw", "grid/sw")
    }


func _bind_pair(first: Node3D, first_id: String, first_side: String, second: Node3D, second_id: String, second_side: String) -> Dictionary:
    _expect(bool(first.call("bind_neighbor_patch", first_side, second)), "neighbor binding succeeds: " + first_id + " -> " + second_id)
    _expect(bool(second.call("bind_neighbor_patch", second_side, first)), "reciprocal neighbor binding succeeds: " + second_id + " -> " + first_id)
    return {"first": first, "first_id": first_id, "second": second, "second_id": second_id}


func _edge_key_for_pair_ids(descriptors: Dictionary, first_id: String, second_id: String) -> String:
    for key_value in descriptors.keys():
        var descriptor: Dictionary = descriptors[key_value]
        var descriptor_first: String = str(descriptor.get("first_stable_id", ""))
        var descriptor_second: String = str(descriptor.get("second_stable_id", ""))
        if (descriptor_first == first_id and descriptor_second == second_id) or (descriptor_first == second_id and descriptor_second == first_id):
            return str(key_value)
    return ""


func _make_two_pair_fixture() -> Dictionary:
    var holder := Node3D.new()
    holder.name = "PartialColliderTransactionFixture"
    root.add_child(holder)
    await process_frame

    var a1: Node3D = _new_patch(holder, "A1", Vector3.ZERO)
    var b1: Node3D = _new_patch(holder, "B1", Vector3(PatchScript.PATCH_SIZE, 0.0, 0.0))
    var a2: Node3D = _new_patch(holder, "A2", Vector3(100.0, 0.0, 0.0))
    var b2: Node3D = _new_patch(holder, "B2", Vector3(100.0 + PatchScript.PATCH_SIZE, 0.0, 0.0))
    await process_frame
    _expect(_apply_height(a1, 0), "first pair lower patch state is valid")
    _expect(_apply_height(b1, 2), "first pair higher patch state is valid")
    _expect(_apply_height(a2, 0), "second pair lower patch state is valid")
    _expect(_apply_height(b2, 2), "second pair higher patch state is valid")
    _expect(bool(a1.call("bind_neighbor_patch", "east", b1)), "first pair forward neighbor binding succeeds")
    _expect(bool(b1.call("bind_neighbor_patch", "west", a1)), "first pair reciprocal neighbor binding succeeds")
    _expect(bool(a2.call("bind_neighbor_patch", "east", b2)), "second pair forward neighbor binding succeeds")
    _expect(bool(b2.call("bind_neighbor_patch", "west", a2)), "second pair reciprocal neighbor binding succeeds")

    var patch_map: Dictionary = {
        "pair/a": a1,
        "pair/b": b1,
        "other/a": a2,
        "other/b": b2
    }
    var pairs: Array[Dictionary] = [
        {"first": a1, "first_id": "pair/a", "second": b1, "second_id": "pair/b"},
        {"first": a2, "first_id": "other/a", "second": b2, "second_id": "other/b"}
    ]
    var descriptors: Dictionary = _build_descriptors(pairs)
    _expect(descriptors.size() == 2, "initial full topology contains two transition descriptors")
    var manager := ManagerScript.new()
    manager.name = "PartialColliderManager"
    holder.add_child(manager)
    await process_frame
    var initial: Dictionary = manager.call("sync_transitions", descriptors, patch_map)
    _expect(bool(initial.get("ok", false)), "initial full-rebuild transaction commits both edges")
    if not bool(initial.get("ok", false)):
        await _release_holder(holder)
        return {}
    return {
        "holder": holder,
        "manager": manager,
        "a1": a1,
        "b1": b1,
        "a2": a2,
        "b2": b2,
        "pair_a": pairs[0],
        "pairs": pairs,
        "patches_by_stable_id": patch_map,
        "edge_a": _edge_key_for_pair(descriptors, "pair/a"),
        "edge_b": _edge_key_for_pair(descriptors, "other/a")
    }


func _new_patch(holder: Node3D, patch_name: String, position: Vector3) -> Node3D:
    var patch: Node3D = PatchScript.new()
    patch.name = patch_name
    patch.position = position
    holder.add_child(patch)
    return patch


func _build_descriptors(pairs: Array) -> Dictionary:
    var result: Dictionary = {}
    for pair_value in pairs:
        if not (pair_value is Dictionary):
            continue
        var pair: Dictionary = pair_value
        var first: Node3D = pair.get("first") as Node3D
        var second: Node3D = pair.get("second") as Node3D
        if not is_instance_valid(first) or not is_instance_valid(second):
            continue
        var built: Dictionary = DescriptorScript.build(
            _snapshot(first, str(pair.get("first_id", ""))),
            _snapshot(second, str(pair.get("second_id", "")))
        )
        if not bool(built.get("ok", false)):
            continue
        var descriptor: Dictionary = built.get("descriptor", {})
        if bool(descriptor.get("transition_required", false)):
            result[str(descriptor.get("edge_key", ""))] = descriptor
    return result


func _snapshot(patch: Node3D, stable_id: String) -> Dictionary:
    var state: Dictionary = patch.call("get_world_object_state")
    return {
        "stable_id": stable_id,
        "position": patch.global_position,
        "patch_size": PatchScript.PATCH_SIZE,
        "height_level": int(state.get("height_level", 0)),
        "revision": int(state.get("revision", 0))
    }


func _edge_key_for_pair(descriptors: Dictionary, first_id: String) -> String:
    for key_value in descriptors.keys():
        var descriptor: Dictionary = descriptors[key_value]
        if str(descriptor.get("first_stable_id", "")) == first_id:
            return str(key_value)
    return ""


func _apply_height(patch: Node3D, height_level: int) -> bool:
    var current: Dictionary = patch.call("get_world_object_state")
    var surface_types: Array[String] = ["soil", "rock", "metal"]
    if height_level < 0 or height_level >= surface_types.size():
        return false
    return bool(patch.call("apply_world_object_state", {
        "height_level": height_level,
        "surface_type": surface_types[height_level],
        "revision": int(current.get("revision", 0)) + 1
    }))


func _release_holder(holder: Node3D) -> void:
    if not is_instance_valid(holder):
        return
    for child in holder.get_children():
        if child.has_method("clear_all"):
            child.call("clear_all")
    holder.queue_free()
    await process_frame
    await process_frame


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
