extends SceneTree

const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const ObjectRegistry = preload("res://systems/WorldObjectStateRegistry.gd")
const StatefulProp = preload("res://systems/WorldObjectStatefulProp.gd")

var failures: Array[String] = []
var factory_calls: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var registry: Node = Registry.new()
    var controller: Node3D = Controller.new()
    var director: Node = Director.new()
    var object_registry: Node = ObjectRegistry.new()
    root.add_child(registry)
    root.add_child(object_registry)
    root.add_child(controller)
    root.add_child(director)
    await process_frame

    _expect(bool(controller.call("bind_registry", registry)), "production controller binds its mineral registry")
    _expect(bool(controller.call("bind_object_state_registry", object_registry)), "production controller binds its world-object registry")
    director.set("chunk_size_x", 10.0)
    director.set("chunk_size_z", 10.0)
    director.set("load_radius", 0)
    _expect(bool(director.call("bind_controller", controller)), "director binds production controller")
    _expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "director binds a fresh-root factory")

    var chunk_id := "surface/chunk_0_0"
    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, 1700000100)), "initial chunk window loads")
    var old_root: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
    _expect(is_instance_valid(old_root), "controller exposes the initial chunk root")
    var old_ref: WeakRef = weakref(old_root)
    _expect(bool(controller.call("is_chunk_loaded", chunk_id)), "initial chunk is reported loaded")
    var old_crate: Node3D = _find_crate(controller)
    _expect(is_instance_valid(old_crate), "initial root registers a stateful SalvageCrate")
    var old_crate_ref: WeakRef = weakref(old_crate)
    _expect(bool(old_crate.call("set_loot_item", "gold_ore")), "crate accepts a valid deterministic loot identity")
    _expect(bool(old_crate.call("interact")), "crate state changes before its root is queued")
    _expect(int(old_crate.get("loot_remaining")) == 1 and bool(old_crate.get("opened")), "crate has a non-default state before recovery")

    old_root.queue_free()
    _expect(not bool(controller.call("is_chunk_loaded", chunk_id)), "queued root is no longer reported as loaded")
    _expect(controller.call("get_chunk_root", chunk_id) == null, "queued root is hidden from the live-root getter")
    _expect(not controller.call("get_loaded_chunk_ids").has(chunk_id), "queued root is omitted from loaded chunk IDs")
    _expect(controller.call("get_loaded_world_state_nodes").is_empty(), "queued-root children are omitted from live world-state enumeration")
    _expect(director.call("get_managed_chunk_ids").has(chunk_id), "director retains the desired coordinate until replacement commits")

    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, 1700000101)), "same-coordinate sync replaces a queued root")
    var replacement: Node3D = controller.call("get_chunk_root", chunk_id) as Node3D
    _expect(is_instance_valid(replacement), "replacement root is registered")
    _expect(replacement != old_root, "replacement uses a different Node3D instance")
    _expect(bool(controller.call("is_chunk_loaded", chunk_id)), "replacement is reported loaded")
    _expect(controller.call("get_loaded_chunk_ids").has(chunk_id), "loaded ID list contains the replacement")
    _expect(director.call("get_managed_chunk_ids").has(chunk_id), "director and controller ownership remain aligned")
    var replacement_crate: Node3D = _find_crate(controller)
    _expect(is_instance_valid(replacement_crate), "replacement root registers a new SalvageCrate")
    _expect(replacement_crate != old_crate, "replacement crate is a different node instance")
    _expect(bool(replacement_crate.get("opened")) and int(replacement_crate.get("loot_remaining")) == 1, "queued-root recovery preserves live crate state")
    _expect(str(replacement_crate.get("loot_item_id")) == "gold_ore", "queued-root recovery preserves the exact loot identity")
    var stable_id := "surface/chunk_0_0/object/Chunk_0_0/SalvageCrate"
    var saved_record: Dictionary = object_registry.call("get_object_state", stable_id)
    _expect(not saved_record.is_empty() and str(saved_record.get("chunk_id", "")) == chunk_id, "normal unload stores the crate under its stable chunk ID")

    await process_frame
    _expect(old_ref.get_ref() == null, "the previously queued root is released exactly once")
    _expect(old_crate_ref.get_ref() == null, "the previously queued crate is released with its root")
    _expect(controller.call("get_chunk_root", chunk_id) == replacement, "replacement survives the old root's deferred deletion")
    _expect(factory_calls == 2, "recovery creates exactly one replacement root")

    director.queue_free()
    controller.queue_free()
    registry.queue_free()
    object_registry.queue_free()
    await process_frame

    if failures.is_empty():
        print("Mineral grid queued-root recovery regression passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _find_crate(controller: Node) -> Node3D:
    var nodes: Array = controller.call("get_loaded_world_state_nodes")
    for node_value in nodes:
        var node: Node3D = node_value as Node3D
        if is_instance_valid(node) and node.name == "SalvageCrate":
            return node
    return null

func _make_chunk(_coordinate: Vector2i) -> Node3D:
    factory_calls += 1
    var candidate := Node3D.new()
    candidate.name = "Chunk_0_0"
    var crate: Node3D = StatefulProp.new()
    crate.name = "SalvageCrate"
    candidate.add_child(crate)
    return candidate

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
