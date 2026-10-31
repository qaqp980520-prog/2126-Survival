extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    world = WorldScene.instantiate() as Node3D
    _expect(world != null, "production SurfaceWorld instantiates for target-lifecycle coverage")
    if world == null:
        quit(1)
        return
    root.add_child(world)
    await process_frame
    await physics_frame
    var prompt: Label = world.get("interaction_prompt") as Label
    _expect(prompt != null, "production HUD exposes the interaction prompt")
    if prompt == null:
        _finish(1)
        return

    var crate: Node3D = _find_world_prop("SalvageCrate", "Chunk_0_0")
    _expect(crate != null, "surface origin chunk exposes a real salvage crate")
    if crate != null:
        await _aim_at(crate)
        var target: Dictionary = world.call("get_camera_interaction_target")
        var proxy: Area3D = target.get("proxy") as Area3D
        _expect(str(target.get("kind", "")) == "prop" and target.get("node") == crate, "camera ray caches the registered crate target")
        _expect(proxy != null and is_instance_valid(proxy), "cached target retains its exact interaction proxy")
        if proxy != null and is_instance_valid(proxy):
            proxy.queue_free()
            var stale_proxy_target: Dictionary = world.call("get_camera_interaction_target")
            _expect(stale_proxy_target.is_empty(), "queued interaction proxy invalidates the cached target immediately")
            world.call("_refresh_hud")
            _expect(prompt.text == "NO INTERACTION IN SIGHT", "HUD clears a target whose proxy is being removed")
            var stale_action: Dictionary = world.call("_interact_nearest_world_prop")
            _expect(not bool(stale_action.get("ok", false)) and str(stale_action.get("action", "")) == "out_of_reach", "F action safely rejects a removed interaction proxy")

    var crop_plots: Array = world.chunk_controller.call("get_loaded_crop_plots")
    _expect(not crop_plots.is_empty(), "surface world exposes a real crop plot")
    if not crop_plots.is_empty():
        var crop_plot: Node3D = crop_plots[0] as Node3D
        await _aim_at(crop_plot, Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.9, 0.0))
        var crop_target: Dictionary = world.call("get_camera_interaction_target")
        _expect(str(crop_target.get("kind", "")) == "crop" and crop_target.get("node") == crop_plot, "camera ray caches the crop target before chunk teardown")
        var chunk_root: Node = crop_plot
        while chunk_root.get_parent() != null and chunk_root.get_parent() != world:
            chunk_root = chunk_root.get_parent()
        _expect(chunk_root != world and chunk_root.get_parent() == world, "crop target belongs to a removable streamed chunk subtree")
        if chunk_root != world and chunk_root.get_parent() == world:
            chunk_root.queue_free()
            var stale_chunk_target: Dictionary = world.call("get_camera_interaction_target")
            _expect(stale_chunk_target.is_empty(), "queued chunk ancestor invalidates a cached crop target immediately")
            var stale_crop_action: Dictionary = world.call("_interact_nearest_crop_plot")
            _expect(not bool(stale_crop_action.get("ok", false)) and str(stale_crop_action.get("action", "")) == "out_of_reach", "E action cannot invoke a crop plot after its chunk is queued for unload")

    _finish(0 if failures.is_empty() else 1)

func _aim_at(target: Node3D, player_offset: Vector3 = Vector3(0.0, 1.0, 2.0), target_offset: Vector3 = Vector3(0.0, 0.55, 0.0)) -> void:
    world.player.global_position = target.global_position + player_offset
    world.camera.look_at(target.global_position + target_offset, Vector3.UP)
    await physics_frame
    await physics_frame

func _find_world_prop(node_name: String, chunk_name: String) -> Node3D:
    var candidates: Array = world.chunk_controller.call("get_loaded_world_state_nodes")
    for candidate in candidates:
        if not is_instance_valid(candidate) or candidate.name != node_name:
            continue
        var parent_node: Node = candidate.get_parent()
        if is_instance_valid(parent_node) and parent_node.name == chunk_name:
            return candidate as Node3D
    return null

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
        print("Production SurfaceWorld interaction lifecycle tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAILED: " + failure)
        quit(1)
