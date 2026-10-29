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
    _check(status.has("inventory") and status.has("player_position"), "Status snapshot must expose inventory and player position")

    var child_count: int = world.get_child_count()
    _check(bool(world.call("initialize_world_session")), "Repeated initialization must succeed")
    _check(world.get_child_count() == child_count, "Repeated initialization must not duplicate registries or controllers")

    var save_payload: Dictionary = world.call("serialize_stream_state")
    _check(int(save_payload.get("schema_version", 0)) == 1, "World-session save envelope must remain schema 1")
    _check(save_payload.has("minerals") and save_payload.has("crops") and save_payload.has("player_position"), "Save envelope must include minerals, crops and player position")
    var original_position: Vector3 = world.get("player").global_position
    var now: int = int(Time.get_unix_time_from_system())
    _check(bool(world.call("debug_move_player_to", Vector3(21.0, 2.0, 1.0), now)), "World-session should stream when the player crosses chunk boundaries")
    _check(bool(world.call("restore_stream_state", save_payload, now)), "Valid schema-1 world snapshot should restore")
    _check(world.get("player").global_position.is_equal_approx(original_position), "Valid restore must recover the saved player position")

    var before_position: Vector3 = world.get("player").global_position
    var before_ids: PackedStringArray = world.get("chunk_controller").get_loaded_chunk_ids()
    var invalid_payload: Dictionary = save_payload.duplicate(true)
    invalid_payload["schema_version"] = 99
    _check(not bool(world.call("restore_stream_state", invalid_payload, now)), "Unsupported schema must be rejected")
    _check(world.get("player").global_position.is_equal_approx(before_position), "Rejected restore must preserve player position")
    _check(world.get("chunk_controller").get_loaded_chunk_ids() == before_ids, "Rejected restore must preserve the active chunk window")

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
