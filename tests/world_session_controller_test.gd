extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")

var _failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world: Node3D = PlaygroundScene.instantiate() as Node3D
    assert(world != null, "Surface streaming scene must instantiate")
    root.add_child(world)
    await process_frame

    _check(world.has_method("initialize_world_session"), "Active world must inherit the formal world-session controller")
    _check(world.has_method("get_world_session_status"), "World-session diagnostics API must be available")
    _check(bool(world.call("initialize_world_session")), "World-session initialization must be idempotent")
    var status: Dictionary = world.call("get_world_session_status")
    _check(bool(status.get("ready", false)), "World-session components must report ready")
    var active_ids: PackedStringArray = status.get("active_chunk_ids", PackedStringArray())
    _check(active_ids.size() == 9, "World-session controller must own the initial 3x3 streamed window")
    _check(int(status.get("saved_vein_count", 0)) == 9, "World-session controller must own mineral registry state")
    _check(int(status.get("saved_world_object_count", -1)) == 0, "World-session controller must own an initially empty object-state registry")
    _check(status.has("inventory") and status.has("player_position"), "Status snapshot must expose inventory and player position")

    var world_player: CharacterBody3D = world.get("player") as CharacterBody3D
    var world_chunk_controller: Node3D = world.get("chunk_controller") as Node3D
    var inventory_bridge: Node = world.get("inventory_bridge") as Node
    var object_registry: Node = world.get("object_state_registry") as Node
    _check(world_player != null and world_chunk_controller != null and inventory_bridge != null and object_registry != null, "World player, chunk controller, inventory bridge and object registry must be bound")
    var child_count: int = world.get_child_count()
    _check(bool(world.call("initialize_world_session")), "Repeated initialization must succeed")
    _check(world.get_child_count() == child_count, "Repeated initialization must not duplicate registries or controllers")

    _check(bool(inventory_bridge.call("collect_world_item", "iron_ore", 2)), "World-session inventory bridge should accept registered ore")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), 6.0), "Two iron ore must add six kilograms")
    _check(bool(object_registry.call("set_object_state", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", {"opened": false, "loot_seed": 42})), "World-object registry accepts stable object state")
    var save_payload: Dictionary = world.call("serialize_stream_state")
    _check(int(save_payload.get("schema_version", 0)) == 1, "World-session save envelope must remain schema 1")
    _check(save_payload.has("minerals") and save_payload.has("crops") and save_payload.has("inventory") and save_payload.has("world_objects") and save_payload.has("player_position"), "Save envelope must include minerals, crops, inventory, world objects and player position")
    var original_position: Vector3 = world_player.global_position
    var now: int = int(Time.get_unix_time_from_system())
    _check(bool(world.call("debug_move_player_to", Vector3(21.0, 2.0, 1.0), now)), "World-session should stream when the player crosses chunk boundaries")
    _check(bool(inventory_bridge.call("drop_item", "iron_ore", 1)), "Dropping ore should recalculate inventory weight")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), 3.0), "Dropping one ore must remove three kilograms")
    _check(bool(object_registry.call("set_property", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", "opened", true)), "Object state can change after saving")
    _check(bool(world.call("restore_stream_state", save_payload, now)), "Valid schema-1 world snapshot should restore")
    _check(world_player.global_position.is_equal_approx(original_position), "Valid restore must recover the saved player position")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), 6.0), "Valid restore must recover inventory counts and weight")
    _check(not bool(object_registry.call("get_object_state", "surface/chunk_0_0/crate_1")["state"]["opened"]), "Valid restore must recover the saved unopened crate state")

    var before_position: Vector3 = world_player.global_position
    var before_ids: PackedStringArray = world_chunk_controller.get_loaded_chunk_ids()
    var invalid_payload: Dictionary = save_payload.duplicate(true)
    invalid_payload["schema_version"] = 99
    _check(not bool(world.call("restore_stream_state", invalid_payload, now)), "Unsupported schema must be rejected")
    _check(world_player.global_position.is_equal_approx(before_position), "Rejected restore must preserve player position")
    _check(world_chunk_controller.get_loaded_chunk_ids() == before_ids, "Rejected restore must preserve the active chunk window")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), 6.0), "Rejected schema must preserve inventory weight")

    var invalid_inventory_save: Dictionary = save_payload.duplicate(true)
    var invalid_inventory: Dictionary = invalid_inventory_save["inventory"].duplicate(true)
    invalid_inventory["schema_version"] = 99
    invalid_inventory_save["inventory"] = invalid_inventory
    _check(not bool(world.call("restore_stream_state", invalid_inventory_save, now)), "Invalid inventory payload must be rejected before world mutation")
    _check(world_player.global_position.is_equal_approx(before_position), "Rejected inventory payload must preserve player position")
    _check(world_chunk_controller.get_loaded_chunk_ids() == before_ids, "Rejected inventory payload must preserve active chunks")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), 6.0), "Rejected inventory payload must preserve current weight")

    var invalid_objects_save: Dictionary = save_payload.duplicate(true)
    var invalid_objects: Dictionary = invalid_objects_save["world_objects"].duplicate(true)
    invalid_objects["objects"]["surface/chunk_0_0/crate_1"]["state"]["opened"] = ["invalid"]
    invalid_objects_save["world_objects"] = invalid_objects
    _check(not bool(world.call("restore_stream_state", invalid_objects_save, now)), "Invalid world-object payload must be rejected before world mutation")
    _check(not bool(object_registry.call("get_object_state", "surface/chunk_0_0/crate_1")["state"]["opened"]), "Rejected object payload preserves the live object state")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), 6.0), "Rejected object payload preserves inventory weight")

    var legacy_save: Dictionary = save_payload.duplicate(true)
    legacy_save.erase("inventory")
    legacy_save.erase("world_objects")
    _check(bool(inventory_bridge.call("drop_item", "iron_ore", 1)), "Legacy compatibility setup should change the current inventory")
    var legacy_weight: float = float(inventory_bridge.call("get_weight_kg"))
    _check(bool(object_registry.call("set_property", "surface/chunk_0_0/crate_1", "surface/chunk_0_0", "opened", true)), "Legacy compatibility setup changes current object state")
    _check(bool(world.call("restore_stream_state", legacy_save, now)), "Schema-1 legacy save without optional inventory/object fields must remain loadable")
    _check(is_equal_approx(float(inventory_bridge.call("get_weight_kg")), legacy_weight), "Legacy save without inventory must preserve the current inventory")
    _check(bool(object_registry.call("get_object_state", "surface/chunk_0_0/crate_1")["state"]["opened"]), "Legacy save without world_objects preserves current object state")

    world.queue_free()
    await process_frame
    if _failed:
        print("World session controller integration tests failed.")
        quit(1)
    else:
        print("World session controller integration tests passed.")
        quit(0)

func _check(condition: bool, message: String) -> void:
    if not condition:
        _failed = true
        push_error(message)
