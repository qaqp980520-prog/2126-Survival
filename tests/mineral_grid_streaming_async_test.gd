extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const WorldScene = preload("res://world/SurfaceWorld.tscn")
const DirectorScript = preload("res://systems/MineralGridStreamingDirector.gd")

class FaultInjectingChunkController:
    extends Node3D

    var roots: Dictionary = {}
    var load_attempts: int = 0
    var unload_attempts: int = 0
    var fail_load_at: int = -1
    var fail_unload_at: int = -1
    var detach_on_load_at: int = -1

    func load_chunk(chunk_id: String, chunk_root: Node3D, _now_unix: int = -1) -> bool:
        load_attempts += 1
        if load_attempts == fail_load_at:
            fail_load_at = -1
            return false
        if roots.has(chunk_id) or not is_instance_valid(chunk_root) or chunk_root.get_parent() != null:
            return false
        add_child(chunk_root)
        roots[chunk_id] = chunk_root
        if load_attempts == detach_on_load_at:
            detach_on_load_at = -1
            var current_parent := get_parent()
            if current_parent != null:
                current_parent.remove_child(self)
        return true

    func unload_chunk(chunk_id: String, _now_unix: int = -1) -> bool:
        unload_attempts += 1
        if unload_attempts == fail_unload_at:
            fail_unload_at = -1
            return false
        if not roots.has(chunk_id):
            return false
        var chunk_root: Node3D = roots[chunk_id] as Node3D
        roots.erase(chunk_id)
        remove_child(chunk_root)
        chunk_root.free()
        return true

    func is_chunk_loaded(chunk_id: String) -> bool:
        return roots.has(chunk_id)

    func get_loaded_chunk_ids() -> PackedStringArray:
        var ids := PackedStringArray()
        for chunk_id in roots.keys():
            ids.append(str(chunk_id))
        ids.sort()
        return ids

    func get_chunk_root(chunk_id: String) -> Node3D:
        return roots.get(chunk_id) as Node3D


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
    await _test_async_commit_rollback()
    await _test_controller_teardown_during_staging()
    await _test_controller_detach_during_commit()
    await _test_async_diagnostics_and_stress()
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
    _expect(not bool(director.call("cancel_async_sync_request", first_request)), "stale cancellation cannot cancel the newer active request")
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

    var cancel_request: int = int(director.call("request_sync_to_world_position_async", Vector3(35.0, 0.0, 35.0), _test_time + 3, 1))
    await process_frame
    await process_frame
    await process_frame
    var cancel_refs: Array = director.call("get_async_staged_root_weakrefs", cancel_request)
    _expect(int(director.call("get_async_staged_root_count", cancel_request)) > 0 and not cancel_refs.is_empty(), "explicit cancellation test has detached roots staged")
    _expect(bool(director.call("cancel_async_sync_request", cancel_request)), "explicit async cancellation is accepted")
    for reference in cancel_refs:
        _expect(reference.get_ref() == null, "explicit cancellation immediately frees a staged root")
    var cancel_report: Dictionary = await _wait_for_request(director, cancel_request)
    _expect(str(cancel_report.get("phase", "")) == "cancelled", "explicit cancellation emits a terminal cancellation report")
    _expect(controller.call("get_loaded_chunk_ids") == director.call("get_managed_chunk_ids"), "explicit cancellation leaves the committed window unchanged")

    var teardown_request: int = int(director.call("request_sync_to_world_position_async", Vector3(85.0, 0.0, 85.0), _test_time + 4, 1))
    await process_frame
    await process_frame
    await process_frame
    var teardown_refs: Array = director.call("get_async_staged_root_weakrefs", teardown_request)
    _expect(not teardown_refs.is_empty(), "director teardown test has detached roots staged")
    playground.queue_free()
    await process_frame
    for reference in teardown_refs:
        _expect(reference.get_ref() == null, "director exit frees every detached staged root")

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

    var rollback_position: Vector3 = player.global_position
    var target_position := Vector3(35.0, 2.0, 35.0)
    var target_velocity := Vector3(2.5, 0.0, -1.5)
    var started: bool = bool(world.call("_request_surface_streaming", rollback_position, target_position, target_velocity))
    _expect(started and bool(world.get("_surface_stream_pending")), "production movement starts a bounded async window request")
    _expect(player.global_position.is_equal_approx(rollback_position), "player is held at the last safe position while chunks stage")
    var request_id: int = int(world.get("_surface_stream_request_id"))
    var success_report: Dictionary = await _wait_for_request(director, request_id)
    _expect(bool(success_report.get("success", false)), "production surface request completes successfully")
    # Check the callback's resume position before the next physics tick applies gravity.
    _expect(player.global_position.is_equal_approx(target_position), "player resumes at the requested position after commit")
    _expect(player.velocity.is_equal_approx(target_velocity), "player resumes with the saved movement velocity after commit")
    _expect(world.get("_last_grid") == Vector2i(3, 3), "production world advances its last-grid coordinate only after commit")
    _expect(not bool(world.get("_surface_stream_pending")), "production world clears its pending flag after completion")
    await process_frame

    # A synchronous restore/debug move must cancel an in-flight surface request and clear
    # the pending gate, otherwise the stale async completion can leave the player frozen.
    var supersession_rollback_position: Vector3 = player.global_position
    var superseded_target := Vector3(95.0, 2.0, 95.0)
    world.set("_camera_interaction_target_cache", {"kind": "lift"})
    var supersession_started: bool = bool(world.call(
        "_request_surface_streaming", supersession_rollback_position, superseded_target, Vector3(1.0, 0.0, 0.5)
    ))
    _expect(supersession_started, "production world starts a second async request before synchronous supersession")
    _expect(world.get("_camera_interaction_target_cache").is_empty(), "starting async streaming clears stale interaction targets")
    var superseded_request_id: int = int(world.get("_surface_stream_request_id"))
    world.set("_camera_interaction_target_cache", {"kind": "lift"})
    _expect(world.call("get_camera_interaction_target").is_empty(), "pending streaming suppresses even a stale cached interaction target")
    var staged_ready: bool = await _wait_for_staged_root_count(director, superseded_request_id, 1)
    _expect(staged_ready, "synchronous supersession test observes at least one detached staged root")
    var superseded_refs: Array = director.call("get_async_staged_root_weakrefs", superseded_request_id)
    var synchronous_target := Vector3(45.0, 2.0, 35.0)
    var synchronous_move: bool = bool(world.call("debug_move_player_to", synchronous_target, _test_time + 4))
    _expect(synchronous_move, "synchronous world move succeeds while an async request is staging")
    _expect(not bool(world.get("_surface_stream_pending")), "synchronous world move clears the pending async movement gate")
    _expect(int(world.get("_surface_stream_request_id")) == -1, "synchronous world move invalidates the old SurfaceWorld request ID")
    _expect(int(director.call("get_active_async_request_id")) == -1, "synchronous world move cancels the director request")
    _expect(player.global_position.is_equal_approx(synchronous_target), "synchronous world move retains its requested position")
    player.velocity = Vector3.ZERO
    var superseded_report: Dictionary = await _wait_for_request(director, superseded_request_id)
    _expect(str(superseded_report.get("phase", "")) == "cancelled" and bool(superseded_report.get("rollback_complete", false)), "superseded async movement emits a terminal cancellation report")
    for reference in superseded_refs:
        _expect(reference.get_ref() == null, "synchronous supersession releases every detached staged root")
    _expect(Vector2(player.global_position.x, player.global_position.z).is_equal_approx(Vector2(synchronous_target.x, synchronous_target.z)), "late cancellation cannot overwrite the synchronous destination")
    _expect(not bool(world.get("_surface_stream_pending")), "late cancellation leaves the SurfaceWorld movement gate clear")
    await process_frame

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
    _expect(not bool(failure_report.get("success", true)) and bool(failure_report.get("rollback_complete", false)), "production failed request reports a complete rollback")
    # Assert rollback before the next physics tick can apply gravity to the restored player.
    _expect(player.global_position.is_equal_approx(failed_rollback_position), "production player remains at the previous safe position after load failure")
    _expect(controller.call("get_loaded_chunk_ids") == before_failure_ids, "production load failure preserves the previous active chunk window")
    _expect(not bool(world.get("_surface_stream_pending")), "production failure clears the pending flag")
    await process_frame
    director.set("chunk_factory", original_factory)
    world.queue_free()
    await process_frame


func _test_controller_teardown_during_staging() -> void:
    var controller := FaultInjectingChunkController.new()
    root.add_child(controller)
    var director: Node = DirectorScript.new()
    root.add_child(director)
    _expect(bool(director.call("bind_controller", controller)), "controller-teardown fixture binds its initial controller")
    _expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_transaction_chunk"))), "controller-teardown fixture binds a deterministic chunk factory")
    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 20)), "controller-teardown fixture creates its initial active window")
    _expect(controller.get_loaded_chunk_ids().size() == 9, "controller-teardown fixture begins with nine committed roots")

    var request_id: int = int(director.call(
        "request_sync_to_world_position_async", Vector3(65.0, 0.0, 0.0), _test_time + 21, 1
    ))
    _expect(request_id > 0, "async request is accepted before controller teardown")
    var staged_ready: bool = await _wait_for_staged_root_count(director, request_id, 1)
    _expect(staged_ready, "controller-teardown test observes a detached staged root")
    var staged_refs: Array = director.call("get_async_staged_root_weakrefs", request_id)
    _expect(not staged_refs.is_empty(), "controller-teardown test captures staged-root weak references")

    controller.queue_free()
    var report: Dictionary = await _wait_for_request(director, request_id)
    _expect(str(report.get("phase", "")) == "dependency_unavailable", "controller destruction produces a terminal dependency-unavailable report")
    _expect(not bool(report.get("success", true)), "controller destruction never reports a successful window commit")
    _expect(not bool(report.get("rollback_complete", true)), "destroyed controller reports that its committed window cannot be restored")
    _expect(bool(report.get("details", {}).get("controller_destroyed", false)), "report identifies the destroyed controller dependency")
    _expect(int(report.get("details", {}).get("staged_roots_released", 0)) > 0, "report counts detached roots released during controller teardown")
    _expect(director.call("get_managed_chunk_ids").is_empty(), "destroyed controller clears stale managed IDs")
    for reference in staged_refs:
        _expect(reference.get_ref() == null, "controller teardown releases every detached staged root")
    _expect(int(director.call("get_active_async_request_id")) == -1, "controller teardown closes the active async request")

    var replacement := FaultInjectingChunkController.new()
    root.add_child(replacement)
    _expect(bool(director.call("bind_controller", replacement)), "director can bind a replacement after controller destruction")
    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 22)), "replacement controller can synchronously rebuild the active window")
    _expect(replacement.get_loaded_chunk_ids().size() == 9, "replacement controller receives a complete nine-root window")
    _expect(replacement.get_loaded_chunk_ids() == director.call("get_managed_chunk_ids"), "replacement controller and director ownership maps agree")

    director.queue_free()
    replacement.queue_free()
    await process_frame


func _test_controller_detach_during_commit() -> void:
    var controller := FaultInjectingChunkController.new()
    root.add_child(controller)
    var director: Node = DirectorScript.new()
    root.add_child(director)
    _expect(bool(director.call("bind_controller", controller)), "controller-detach fixture binds its initial controller")
    _expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_transaction_chunk"))), "controller-detach fixture binds a deterministic factory")
    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 30)), "controller-detach fixture creates its original window")
    var original_ids: PackedStringArray = controller.get_loaded_chunk_ids()
    controller.detach_on_load_at = controller.load_attempts + 1

    var request_id: int = int(director.call(
        "request_sync_to_world_position_async", Vector3(65.0, 0.0, 0.0), _test_time + 31, 1
    ))
    _expect(request_id > 0, "controller-detach async request is accepted")
    var report: Dictionary = await _wait_for_request(director, request_id)
    _expect(str(report.get("phase", "")) == "dependency_unavailable", "controller detachment during commit aborts the request")
    _expect(not bool(report.get("success", true)), "detached controller cannot report a successful commit")
    _expect(bool(report.get("rollback_complete", false)), "detached controller rolls back partially registered chunks")
    _expect(bool(report.get("details", {}).get("controller_detached", false)), "report identifies a detached but live controller")
    _expect(not bool(report.get("details", {}).get("controller_destroyed", true)), "detached controller is distinguished from destroyed controller")
    _expect(controller.get_parent() == null, "fault-injected controller is outside the scene tree")
    _expect(controller.get_loaded_chunk_ids() == original_ids, "rollback restores the controller's original active roots")
    _expect(controller.get_loaded_chunk_ids() == director.call("get_managed_chunk_ids"), "rollback restores director/controller ownership agreement")

    root.add_child(controller)
    _expect(bool(director.call("bind_controller", controller)), "detached controller can be reattached and rebound")
    _expect(bool(director.call("sync_to_world_position", Vector3(65.0, 0.0, 0.0), _test_time + 32)), "reattached controller can retry the target window")
    _expect(controller.get_loaded_chunk_ids().size() == 9, "reattached controller completes a nine-root window")

    director.queue_free()
    controller.queue_free()
    await process_frame

func _test_async_diagnostics_and_stress() -> void:
    var controller := FaultInjectingChunkController.new()
    root.add_child(controller)
    var director: Node = DirectorScript.new()
    root.add_child(director)
    _expect(bool(director.call("bind_controller", controller)), "diagnostics fixture binds its chunk controller")
    _expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_transaction_chunk"))), "diagnostics fixture binds its deterministic factory")
    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 50)), "diagnostics fixture creates its initial window")

    var last_request_id: int = -1
    for index in range(34):
        var target := Vector3(float(index + 1) * 65.0, 0.0, 0.0)
        last_request_id = int(director.call("request_sync_to_world_position_async", target, _test_time + 51 + index, 8))
        var report: Dictionary = await _wait_for_request(director, last_request_id)
        var diagnostic: Dictionary = director.call("get_async_request_diagnostics", last_request_id)
        _expect(bool(report.get("success", false)), "bounded stress shift %d completes successfully" % index)
        _expect(str(diagnostic.get("phase", "")) == "complete" and bool(diagnostic.get("terminal", false)), "bounded stress shift %d records a terminal completion phase" % index)
        _expect(int(diagnostic.get("desired_count", 0)) == 9 and int(diagnostic.get("staged_count", 0)) == 3, "bounded stress shift %d records desired and staged counts" % index)
        _expect(int(diagnostic.get("duration_usec", -1)) >= 0 and int(diagnostic.get("started_usec", 0)) > 0, "bounded stress shift %d records a monotonic duration" % index)
        _expect(bool(diagnostic.get("rollback_complete", false)), "bounded stress shift %d records rollback-safe completion" % index)
        _expect(controller.get_loaded_chunk_ids().size() == 9 and controller.get_loaded_chunk_ids() == director.call("get_managed_chunk_ids"), "bounded stress shift %d keeps both ownership maps aligned" % index)

    var retained_history: Array = director.call("get_recent_async_request_diagnostics")
    _expect(retained_history.size() == 32, "async diagnostic history is capped at thirty-two requests")
    if retained_history.size() == 32:
        _expect(int(retained_history[0].get("request_id", 0)) == 3, "diagnostic pruning retains the newest thirty-two requests")
        _expect(int(retained_history[-1].get("request_id", 0)) == last_request_id, "diagnostic history keeps the latest request at the end")

    var superseded_id: int = int(director.call("request_sync_to_world_position_async", Vector3(10000.0, 0.0, 0.0), _test_time + 90, 1))
    var staged_before_supersession: bool = await _wait_for_staged_root_count(director, superseded_id, 1)
    _expect(staged_before_supersession, "overlap stress observes a staged root before supersession")
    var replacement_id: int = int(director.call("request_sync_to_world_position_async", Vector3(12000.0, 0.0, 0.0), _test_time + 91, 2))
    var superseded_report: Dictionary = await _wait_for_request(director, superseded_id)
    var replacement_report: Dictionary = await _wait_for_request(director, replacement_id)
    var superseded_diagnostic: Dictionary = director.call("get_async_request_diagnostics", superseded_id)
    _expect(str(superseded_report.get("phase", "")) == "cancelled", "overlapped old request receives a terminal cancellation")
    _expect(str(superseded_diagnostic.get("cancellation_reason", "")) == "superseded_by_request:%d" % replacement_id, "diagnostics identify the exact request that superseded the old request")
    _expect(bool(replacement_report.get("success", false)), "latest overlapping request commits its destination")
    var replacement_diagnostic: Dictionary = director.call("get_async_request_diagnostics", replacement_id)
    _expect(str(replacement_diagnostic.get("phase", "")) == "complete", "replacement request diagnostics end in complete")

    var explicit_cancel_id: int = int(director.call("request_sync_to_world_position_async", Vector3(14000.0, 0.0, 0.0), _test_time + 92, 1))
    var staged_before_cancel: bool = await _wait_for_staged_root_count(director, explicit_cancel_id, 1)
    _expect(staged_before_cancel, "explicit cancellation test reaches staging before cancellation")
    _expect(bool(director.call("cancel_async_sync_request", explicit_cancel_id)), "explicit cancellation is accepted during staging")
    var explicit_cancel_report: Dictionary = await _wait_for_request(director, explicit_cancel_id)
    var explicit_cancel_diagnostic: Dictionary = director.call("get_async_request_diagnostics", explicit_cancel_id)
    _expect(str(explicit_cancel_report.get("phase", "")) == "cancelled", "explicit cancellation emits a terminal report")
    _expect(str(explicit_cancel_diagnostic.get("cancellation_reason", "")) == "explicit_cancel", "diagnostics preserve the explicit cancellation reason")
    _expect(bool(explicit_cancel_diagnostic.get("terminal", false)), "cancelled request diagnostics are terminal")

    var final_ids: PackedStringArray = controller.get_loaded_chunk_ids()
    _expect(final_ids.size() == 9 and final_ids == director.call("get_managed_chunk_ids"), "stress run ends with exactly nine consistent active chunks")
    director.queue_free()
    controller.queue_free()
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


func _test_async_commit_rollback() -> void:
    var controller := FaultInjectingChunkController.new()
    root.add_child(controller)
    var director: Node = DirectorScript.new()
    root.add_child(director)
    _expect(bool(director.call("bind_controller", controller)), "transaction fixture binds its fault-injecting chunk controller")
    _expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_transaction_chunk"))), "transaction fixture binds a deterministic chunk factory")
    _expect(bool(director.call("sync_to_world_position", Vector3.ZERO, _test_time + 10)), "transaction fixture creates its initial nine-chunk window")
    var original_ids: PackedStringArray = controller.get_loaded_chunk_ids()
    _expect(original_ids.size() == 9, "transaction fixture starts with nine committed chunks")

    controller.fail_load_at = controller.load_attempts + 2
    var registration_request: int = int(director.call(
        "request_sync_to_world_position_async", Vector3(65.0, 0.0, 0.0), _test_time + 11, 1
    ))
    _expect(registration_request > 0, "async registration-failure request is accepted")
    var staged_ready: bool = await _wait_for_staged_root_count(director, registration_request, 2)
    _expect(staged_ready, "registration-failure test observes detached roots before commit")
    var staged_refs: Array = director.call("get_async_staged_root_weakrefs", registration_request)
    var registration_report: Dictionary = await _wait_for_request(director, registration_request)
    _expect(str(registration_report.get("phase", "")) == "load_registration", "controller rejection is reported during the async commit phase")
    _expect(not bool(registration_report.get("success", true)) and bool(registration_report.get("rollback_complete", false)), "registration rejection rolls back every newly registered chunk")
    _expect(controller.get_loaded_chunk_ids() == original_ids, "registration rejection preserves the exact previous controller window")
    _expect(director.call("get_managed_chunk_ids") == original_ids, "registration rejection preserves the director's managed ID map")
    _expect(int(director.call("get_async_staged_root_count", registration_request)) == 0, "registration rejection releases all remaining staged roots")
    for reference in staged_refs:
        _expect(reference.get_ref() == null, "registration rejection frees every observed detached staging root")

    var shift_request: int = int(director.call(
        "request_sync_to_world_position_async", Vector3(65.0, 0.0, 0.0), _test_time + 12, 8
    ))
    var shift_report: Dictionary = await _wait_for_request(director, shift_request)
    _expect(bool(shift_report.get("success", false)), "transaction fixture can commit a valid neighboring window after rollback")
    var shifted_ids: PackedStringArray = controller.get_loaded_chunk_ids()
    _expect(shifted_ids.size() == 9 and shifted_ids != original_ids, "successful async shift replaces only the departing edge of the active window")

    var stale_root: Node3D = controller.get_chunk_root("surface/chunk_2_-1")
    var stale_root_ref: WeakRef = weakref(stale_root) if stale_root != null else null
    controller.fail_unload_at = controller.unload_attempts + 2
    var stale_request: int = int(director.call(
        "request_sync_to_world_position_async", Vector3.ZERO, _test_time + 13, 8
    ))
    var stale_report: Dictionary = await _wait_for_request(director, stale_request)
    _expect(str(stale_report.get("phase", "")) == "stale_unload", "second stale-unload rejection is reported during async commit")
    _expect(not bool(stale_report.get("success", true)) and bool(stale_report.get("rollback_complete", false)), "partial stale-unload failure restores the previous window")
    _expect(controller.get_loaded_chunk_ids() == shifted_ids, "partial stale-unload failure restores the exact prior controller IDs")
    _expect(director.call("get_managed_chunk_ids") == shifted_ids, "partial stale-unload failure restores the director's managed IDs")
    _expect(controller.get_loaded_chunk_ids().size() == 9, "partial stale-unload rollback leaves exactly nine active chunks")
    _expect(stale_root_ref != null and stale_root_ref.get_ref() == null, "the previously unloaded stale root is actually released before restoration")
    _expect(controller.get_chunk_root("surface/chunk_2_-1") != null, "rollback creates a fresh root for the restored stale chunk")

    director.queue_free()
    controller.queue_free()
    await process_frame

func _wait_for_staged_root_count(director: Node, request_id: int, minimum: int) -> bool:
    for _frame in range(120):
        if int(director.call("get_async_staged_root_count", request_id)) >= minimum:
            return true
        await process_frame
    return false

func _make_transaction_chunk(coord: Vector2i) -> Node3D:
    var chunk := Node3D.new()
    chunk.name = "transaction_chunk_%d_%d" % [coord.x, coord.y]
    return chunk
