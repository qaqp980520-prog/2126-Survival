extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const INTERACTION_LAYER: int = 1 << 1
const CHUNK_ID: String = "surface/chunk_0_0"
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    world = WorldScene.instantiate() as Node3D
    _expect(world != null, "production SurfaceWorld instantiates for controller-driven stream reload coverage")
    if world == null:
        quit(1)
        return
    root.add_child(world)
    await process_frame
    await physics_frame

    var original_root: Node3D = world.chunk_controller.call("get_chunk_root", CHUNK_ID) as Node3D
    var original_crate: Node3D = _find_crate(CHUNK_ID)
    _expect(original_root != null and original_crate != null, "origin chunk exposes a real stateful salvage crate")
    if original_root == null or original_crate == null:
        await _finish(1)
        return
    var stable_id: String = world.chunk_controller.call(
        "_make_world_object_stable_id",
        CHUNK_ID,
        "%s/%s" % [str(original_root.name), str(original_crate.name)]
    )
    _expect(stable_id == "surface/chunk_0_0/object/Chunk_0_0/SalvageCrate", "crate uses the deterministic chunk/local-path stable ID")
    await _aim_at(original_crate)
    var original_target: Dictionary = world.call("get_camera_interaction_target")
    var original_proxy: Area3D = original_target.get("proxy") as Area3D
    _expect(str(original_target.get("kind", "")) == "prop" and original_target.get("node") == original_crate, "camera ray selects the original crate")
    _expect(original_proxy != null and is_instance_valid(original_proxy) and original_proxy.is_inside_tree(), "original crate has a registered interaction proxy")
    if original_proxy == null or not is_instance_valid(original_proxy):
        await _finish(1)
        return
    var old_crate_instance: int = original_crate.get_instance_id()
    var old_proxy_instance: int = original_proxy.get_instance_id()
    _expect(bool(original_crate.call("interact")), "crate state changes before the controller unload")
    _expect(bool(original_crate.get("opened")) and int(original_crate.get("loot_remaining")) == 1, "pre-unload crate state is opened with one item remaining")

    var moved_away: bool = bool(world.call("debug_move_player_to", Vector3(21.5, 2.0, 7.5)))
    _expect(moved_away, "production streaming director moves the active window away from the origin")
    _expect(not bool(world.chunk_controller.call("is_chunk_loaded", CHUNK_ID)), "controller unloads the origin chunk through the director")
    var saved_record: Dictionary = world.object_state_registry.call("get_object_state", stable_id)
    _expect(not saved_record.is_empty(), "unload stores the crate record under its stable ID")
    _expect(str(saved_record.get("chunk_id", "")) == CHUNK_ID, "saved record retains its owning chunk ID")
    var saved_state: Dictionary = saved_record.get("state", {})
    _expect(bool(saved_state.get("opened", false)) and int(saved_state.get("loot_remaining", -1)) == 1, "unload captures the live crate state")
    _expect(world.director.call("get_managed_chunk_ids").size() == 9, "director retains a complete nine-chunk active window after unload")
    var stale_target: Dictionary = world.call("get_camera_interaction_target")
    _expect(stale_target.is_empty(), "cached target is cleared when its streamed chunk is unloaded")
    await process_frame
    _expect(not is_instance_valid(original_root) and not is_instance_valid(original_crate) and not is_instance_valid(original_proxy), "old chunk, crate and proxy are freed after the unload frame")

    var returned: bool = bool(world.call("debug_move_player_to", Vector3(1.5, 2.0, 7.5)))
    _expect(returned, "production streaming director reloads the origin window")
    var restored_root: Node3D = world.chunk_controller.call("get_chunk_root", CHUNK_ID) as Node3D
    var restored_crate: Node3D = _find_crate(CHUNK_ID)
    _expect(restored_root != null and restored_crate != null, "reloaded origin chunk registers a new stateful crate")
    if restored_root == null or restored_crate == null:
        await _finish(1)
        return
    _expect(restored_crate.get_instance_id() != old_crate_instance, "reloaded crate is a new node instance, not the stale node")
    _expect(bool(restored_crate.get("opened")) and int(restored_crate.get("loot_remaining")) == 1, "controller applies the saved state to the new crate instance")
    var restored_record: Dictionary = world.object_state_registry.call("get_object_state", stable_id)
    _expect(not restored_record.is_empty() and str(restored_record.get("chunk_id", "")) == CHUNK_ID, "the same stable ID remains registered after reload")
    var restored_proxy: Area3D = restored_crate.get_node_or_null("InteractionArea") as Area3D
    _expect(restored_proxy != null and is_instance_valid(restored_proxy) and restored_proxy.is_inside_tree(), "new crate recreates an in-tree interaction proxy")
    if restored_proxy != null and is_instance_valid(restored_proxy):
        _expect(restored_proxy.get_instance_id() != old_proxy_instance, "reloaded crate registers a fresh proxy instance")
        _expect((restored_proxy.collision_layer & INTERACTION_LAYER) != 0, "fresh proxy remains on the interaction collision layer")

    await _aim_at(restored_crate)
    var restored_target: Dictionary = world.call("get_camera_interaction_target")
    _expect(str(restored_target.get("kind", "")) == "prop" and restored_target.get("node") == restored_crate, "camera ray selects the reloaded crate through its new proxy")
    _expect(restored_target.get("proxy") == restored_proxy, "cached target references the reloaded proxy, not the stale proxy")
    var action_result: Dictionary = world.call("_interact_nearest_world_prop")
    _expect(bool(action_result.get("ok", false)) and int(action_result.get("remaining", -1)) == 0, "F interaction works after controller-driven unload and reload")
    await _finish(0 if failures.is_empty() else 1)

func _find_crate(chunk_id: String) -> Node3D:
    var nodes: Array = world.chunk_controller.call("get_loaded_world_state_nodes")
    var chunk_root: Node = world.chunk_controller.call("get_chunk_root", chunk_id)
    for candidate in nodes:
        if not is_instance_valid(candidate) or candidate.name != "SalvageCrate":
            continue
        var ancestor: Node = candidate.get_parent()
        while ancestor != null and ancestor != world.chunk_controller:
            if ancestor == chunk_root:
                return candidate as Node3D
            ancestor = ancestor.get_parent()
    return null

func _aim_at(target: Node3D) -> void:
    world.player.global_position = target.global_position + Vector3(0.0, 1.0, 2.0)
    world.camera.look_at(target.global_position + Vector3(0.0, 0.55, 0.0), Vector3.UP)
    await physics_frame
    await physics_frame

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

func _finish(exit_code: int) -> void:
    if is_instance_valid(world):
        world.queue_free()
    await process_frame
    if exit_code == 0 and failures.is_empty():
        print("Production SurfaceWorld interaction stream reload tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAILED: " + failure)
        quit(1)
