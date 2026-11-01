extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SurfaceChunkFactoryScript = preload("res://systems/SurfaceChunkFactory.gd")

var failures: Array[String] = []
var _delegate_factory: Callable
var _fail_coordinate: Vector2i = Vector2i(4, 4)
var _test_time: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_time = int(Time.get_unix_time_from_system()) + 20
    await _test_playground_async_requests()
    await _test_production_surface_world_async_movement()
    if failures.is_empty():
        print("Mineral grid bounded async streaming tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _test_playground_async_requests() -> void:
    var playground := PlaygroundScene.instantiate()
    root.add_child(playground)
    await process_frame
    await physics_frame
    var controller: Node = playground.get("chunk_controller") as Node
    var director: Node = playground.get("director") as Node
    _expect(controller != null and director != null, "playground exposes its production chunk controller and grid director")
    if controller == null or director == null:
        playground.queue_free()
        await process_frame
        return

    var original_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
    var original_root: Node3D = controller.call("get_chunk_root", "surface/chunk_0_0") as Node3D
    _expect(original_ids.size() == 9 and original_root != null, "playground starts with a valid 3x3 active window")
    var original_factory: Callable = director.get("chunk_factory")
    _delegate_factory = original_factory
    director.set("chunk_factory", Callable(self, "_make_fault_injected_chunk"))
    var failed_request: int = int(director.call("request_sync_to_world_position_async", Vector3(35.0, 0.0, 35.0), _test_time, 1))
    var failed_report: Dictionary = await _wait_for_request(director, failed_request)
    _expect(failed_request > 0 and not bool(failed_report.get("success", true)) and str(failed_report.get("phase", "")) == "load_factory", "invalid staged root rejects the async request before commit")
    _expect(controller.call("get_loaded_chunk_ids") == original_ids, "staging failure preserves the original active chunk IDs")
    _expect(controller.call("get_chunk_root", "surface/chunk_0_0") == original_root, "staging failure preserves the original live chunk root")
    _expect(bool(failed_report.get("rollback_complete", false)), "staging failure reports a complete no-mutation rollback")

    director.set("chunk_factory", original_factory)
    var first_request: int = int(director.call("request_sync_to_world_position_async", Vector3(35.0, 0.0, 35.0), _test_time + 1, 1))
    await process_frame
    await process_frame
    var second_request: int = int(director.call("request_sync_to_world_position_async", Vector3(-25.0, 0.0, -25.0), _test_time + 2, 2))
    var first_report: Dictionary = await _wait_for_request(director, first_request)
    var second_report: Dictionary = await _wait_for_request(director, second_request)
    _expect(str(first_report.get("phase", "")) == "cancelled" and bool(first_report.get("rollback_complete", false)), "newer request cancels the older staging request")
    _expect(int(first_report.get("details", {}).get("staged_roots_released", 0)) > 0, "superseded request releases roots already staged across earlier frames")
    _expect(bool(second_report.get("success", false)) and str(second_report.get("phase", "")) == "complete", "latest async request commits its target window")
    _expect(controller.call("get_loaded_chunk_ids") == director.call("get_managed_chunk_ids"), "async commit keeps controller and director IDs synchronized")
    _expect(controller.call("get_loaded_chunk_ids").size() == 9, "async commit retains exactly nine active surface chunks")
    await process_frame
    await process_frame
    _expect(not is_instance_valid(original_root), "chunks leaving the committed window release their previous root instances")
    playground.queue_free()
    await process_frame

func _test_production_surface_world_async_movement() -> void:
    var world := WorldScene.instantiate()
    root.add_child(world)
    await process_frame
    await physics_frame
    var controller: Node = world.get("chunk_controller") as Node
    var director: Node = world.get("director") as Node
    var player: CharacterBody3D = world.get("player") as CharacterBody3D
    _expect(controller != null and director != null and player != null, "production SurfaceWorld initializes its player and streaming stack")
    if controller == null or director == null or player == null:
        world.queue_free()
        await process_frame
        return

    var initial_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
    var rollback_position: Vector3 = player.global_position
    var target_position := Vector3(35.0, 2.0, 35.0)
    var started: bool = bool(world.call("_request_surface_streaming", rollback_position, target_position, Vector3.ZERO))
    _expect(started and bool(world.get("_surface_stream_pending")), "production movement starts a bounded async window request")
    _expect(player.global_position.is_equal_approx(rollback_position), "player is held at the last safe position while chunks stage")
    var request_id: int = int(world.get("_surface_stream_request_id"))
    var success_report: Dictionary = await _wait_for_request(director, request_id)
    await process_frame
    _expect(bool(success_report.get("success", false)), "production surface request completes successfully")
    _expect(player.global_position.is_equal_approx(target_position), "player resumes at the requested position after commit")
    _expect(world.get("_last_grid") == Vector2i(3, 3), "production world advances its last-grid coordinate only after commit")
    _expect(not bool(world.get("_surface_stream_pending")), "production world clears its pending flag after completion")

    var before_failure_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
    var failed_rollback_position: Vector3 = player.global_position
    var failed_target := Vector3(65.0, 2.0, 65.0)
    var original_factory: Callable = director.get("chunk_factory")
    _delegate_factory = original_factory
    _fail_coordinate = Vector2i(7, 7)
    director.set("chunk_factory", Callable(self, "_make_fault_injected_chunk"))
    var failure_started: bool = bool(world.call("_request_surface_streaming", failed_rollback_position, failed_target, Vector3.ZERO))
    _expect(failure_started, "production world accepts the fault-injected request for rollback testing")
    var failure_id: int = int(world.get("_surface_stream_request_id"))
    var failure_report: Dictionary = await _wait_for_request(director, failure_id)
    await process_frame
    _expect(not bool(failure_report.get("success", true)) and bool(failure_report.get("rollback_complete", false)), "production failed request reports a complete rollback")
    _expect(player.global_position.is_equal_approx(failed_rollback_position), "production player remains at the previous safe position after load failure")
    _expect(controller.call("get_loaded_chunk_ids") == before_failure_ids, "production load failure preserves the previous active chunk window")
    _expect(not bool(world.get("_surface_stream_pending")), "production failure clears the pending flag")
    director.set("chunk_factory", original_factory)
    world.queue_free()
    await process_frame

func _wait_for_request(director: Node, request_id: int) -> Dictionary:
    if request_id < 0:
        return {}
    while true:
        var emitted: Array = await director.async_sync_completed
        if int(emitted[0]) == request_id:
            return emitted[1]
    return {}

func _make_fault_injected_chunk(coord: Vector2i) -> Node3D:
    if coord == _fail_coordinate:
        return null
    return _delegate_factory.call(coord) as Node3D

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)
