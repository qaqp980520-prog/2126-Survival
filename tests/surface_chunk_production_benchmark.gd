extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const RADII: Array[int] = [1, 2, 3, 4, 8]
const MAX_REQUEST_FRAMES: int = 7200
const RELEASE_WAIT_FRAMES: int = 2
const SURFACE_PREFIX: String = "surface/"

var failures: Array[String] = []
var _delegate_factory: Callable
var _factory_build_usec: int = 0
var _factory_calls: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := WorldScene.instantiate() as Node3D
	if world == null:
		_expect(false, "production SurfaceWorld scene instantiates")
		await _finish(null)
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var controller := world.get("chunk_controller") as Node
	var director := world.get("director") as Node
	_expect(controller != null and director != null, "production SurfaceWorld exposes its real chunk controller and streaming director")
	if controller == null or director == null:
		await _finish(world)
		return

	var initial_ids: PackedStringArray = _surface_ids(controller)
	_expect(initial_ids.size() == 9, "production SurfaceWorld starts with its real 3x3 surface window")
	var initial_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
	_expect(initial_managed_ids.size() == 9, "production director owns the same initial nine surface chunks")

	_delegate_factory = director.get("chunk_factory")
	_expect(_delegate_factory.is_valid(), "production SurfaceWorld exposes its real SurfaceChunkFactory callable")
	if not _delegate_factory.is_valid():
		await _finish(world)
		return
	director.set("chunk_factory", Callable(self, "_profiled_chunk_factory"))
	var installed_factory: Callable = director.get("chunk_factory")
	_expect(installed_factory.is_valid() and str(installed_factory.get_method()) == "_profiled_chunk_factory", "benchmark wrapper is installed without replacing the production factory")

	var previous_surface_count: int = initial_ids.size()
	for radius in RADII:
		var index: int = RADII.find(radius)
		var target := Vector3(
			10000.0 + float(index) * 10000.0 + 5.0,
			0.0,
			20000.0 + float(index) * 10000.0 + 5.0
		)
		var old_root_refs: Array[WeakRef] = _capture_surface_root_refs(controller)
		director.set("load_radius", radius)
		world.set("_stream_clock_unix", int(Time.get_unix_time_from_system()))
		_reset_factory_metrics()
		var expansion: Dictionary = await _run_async_request(director, target)
		var expansion_diagnostic: Dictionary = expansion.get("diagnostic", {})
		if not bool(expansion.get("ok", false)):
			_expect(false, "radius %d production expansion completes: %s" % [radius, str(expansion.get("error", expansion_diagnostic.get("phase", "unknown")))])
			break

		var expected_count: int = (radius * 2 + 1) * (radius * 2 + 1)
		var active_ids: PackedStringArray = _surface_ids(controller)
		_expect(active_ids.size() == expected_count, "radius %d commits exactly %d production surface chunks" % [radius, expected_count])
		var expansion_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
		_expect(expansion_managed_ids == active_ids, "radius %d keeps Director and production Controller IDs aligned" % radius)
		_expect(int(expansion_diagnostic.get("desired_count", -1)) == expected_count, "radius %d reports the expected desired window size" % radius)
		_expect(int(expansion_diagnostic.get("staged_count", -1)) == expected_count, "radius %d stages every newly required production root" % radius)
		_expect(int(expansion_diagnostic.get("newly_loaded_count", -1)) == expected_count, "radius %d commits every staged production root" % radius)
		_expect(_factory_calls == expected_count, "radius %d invokes the real production factory once per new chunk" % radius)
		_expect(int(expansion_diagnostic.get("unloaded_stale_count", -1)) == previous_surface_count, "radius %d retires the complete previous surface window" % radius)

		await _wait_frames(RELEASE_WAIT_FRAMES)
		_expect(_all_refs_released(old_root_refs), "radius %d expansion releases all departed production roots" % radius)
		_emit_metrics("expand_stage_commit", radius, expected_count, expansion_diagnostic, expansion.get("frame_samples_ms", []), controller)

		var center: Vector2i = director.call("get_grid_coordinate", target)
		var center_id: String = "surface/chunk_%d_%d" % [center.x, center.y]
		var departed_refs: Array[WeakRef] = _capture_surface_root_refs(controller, center_id)
		_expect(departed_refs.size() == expected_count - 1, "radius %d contraction fixture captures every non-center root" % radius)
		director.set("load_radius", 0)
		_reset_factory_metrics()
		var contraction: Dictionary = await _run_async_request(director, target)
		var contraction_diagnostic: Dictionary = contraction.get("diagnostic", {})
		if not bool(contraction.get("ok", false)):
			_expect(false, "radius %d production contraction completes: %s" % [radius, str(contraction.get("error", contraction_diagnostic.get("phase", "unknown")))])
			break

		var contracted_ids: PackedStringArray = _surface_ids(controller)
		_expect(contracted_ids.size() == 1 and contracted_ids.has(center_id), "radius %d contracts to the retained center chunk" % radius)
		var contraction_managed_ids: PackedStringArray = director.call("get_managed_chunk_ids")
		_expect(contraction_managed_ids == contracted_ids, "radius %d keeps ownership maps aligned after contraction" % radius)
		_expect(int(contraction_diagnostic.get("staged_count", -1)) == 0, "radius %d contraction creates no unnecessary roots" % radius)
		_expect(int(contraction_diagnostic.get("newly_loaded_count", -1)) == 0, "radius %d contraction commits no new roots" % radius)
		_expect(_factory_calls == 0, "radius %d contraction does not invoke the production factory" % radius)
		_expect(int(contraction_diagnostic.get("unloaded_stale_count", -1)) == expected_count - 1, "radius %d unloads exactly %d departed roots" % [radius, expected_count - 1])
		await _wait_frames(RELEASE_WAIT_FRAMES)
		_expect(_all_refs_released(departed_refs), "radius %d contraction releases all non-center roots" % radius)
		_expect(controller.call("get_chunk_root", center_id) != null, "radius %d preserves the retained center root" % radius)
		_emit_metrics("contract_unload", radius, 1, contraction_diagnostic, contraction.get("frame_samples_ms", []), controller)
		previous_surface_count = 1

	director.set("chunk_factory", _delegate_factory)
	await _finish(world)

func _profiled_chunk_factory(coord: Vector2i) -> Node3D:
	var started_usec: int = Time.get_ticks_usec()
	var candidate: Variant = _delegate_factory.call(coord)
	_factory_build_usec += Time.get_ticks_usec() - started_usec
	_factory_calls += 1
	return candidate as Node3D

func _reset_factory_metrics() -> void:
	_factory_build_usec = 0
	_factory_calls = 0

func _run_async_request(director: Node, target: Vector3) -> Dictionary:
	var request_id: int = int(director.call(
		"request_sync_to_world_position_async",
		target,
		int(Time.get_unix_time_from_system()),
		1
	))
	if request_id < 0:
		return {"ok": false, "error": "production async request was rejected", "diagnostic": {}, "frame_samples_ms": []}

	var frame_samples_ms: Array[float] = []
	var previous_usec: int = Time.get_ticks_usec()
	for frame_index in range(MAX_REQUEST_FRAMES):
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		frame_samples_ms.append(float(now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		var diagnostic: Dictionary = director.call("get_async_request_diagnostics", request_id)
		if bool(diagnostic.get("terminal", false)):
			return {
				"ok": bool(diagnostic.get("success", false)),
				"diagnostic": diagnostic,
				"frame_samples_ms": frame_samples_ms
			}
	director.call("cancel_async_sync_request", request_id)
	return {
		"ok": false,
		"error": "request exceeded %d process frames" % MAX_REQUEST_FRAMES,
		"diagnostic": director.call("get_async_request_diagnostics", request_id),
		"frame_samples_ms": frame_samples_ms
	}

func _surface_ids(controller: Node) -> PackedStringArray:
	var result := PackedStringArray()
	var loaded_ids: PackedStringArray = controller.call("get_loaded_chunk_ids")
	for chunk_id in loaded_ids:
		if str(chunk_id).begins_with(SURFACE_PREFIX):
			result.append(str(chunk_id))
	result.sort()
	return result

func _capture_surface_root_refs(controller: Node, excluded_id: String = "") -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	for chunk_id in _surface_ids(controller):
		if str(chunk_id) == excluded_id:
			continue
		var chunk_root := controller.call("get_chunk_root", str(chunk_id)) as Node3D
		if is_instance_valid(chunk_root):
			refs.append(weakref(chunk_root))
	return refs

func _all_refs_released(refs: Array[WeakRef]) -> bool:
	for root_ref in refs:
		var candidate: Object = root_ref.get_ref()
		if candidate != null and is_instance_valid(candidate):
			return false
	return true

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child as Node)
	return count

func _count_surface_nodes(controller: Node) -> int:
	var count: int = 0
	for chunk_id in _surface_ids(controller):
		var chunk_root := controller.call("get_chunk_root", str(chunk_id)) as Node3D
		if is_instance_valid(chunk_root):
			count += _count_nodes(chunk_root)
	return count

func _emit_metrics(
	phase: String,
	radius: int,
	desired_count: int,
	diagnostic: Dictionary,
	frame_samples_ms: Array,
	controller: Node
) -> void:
	var total_frame_ms: float = 0.0
	var sorted_samples: Array = frame_samples_ms.duplicate()
	for sample in sorted_samples:
		total_frame_ms += float(sample)
	sorted_samples.sort()
	var average_frame_ms: float = total_frame_ms / float(sorted_samples.size()) if not sorted_samples.is_empty() else 0.0
	var p95_frame_ms: float = 0.0
	if not sorted_samples.is_empty():
		var p95_index: int = clampi(int(ceil(float(sorted_samples.size() - 1) * 0.95)), 0, sorted_samples.size() - 1)
		p95_frame_ms = float(sorted_samples[p95_index])
	var max_frame_ms: float = float(sorted_samples[sorted_samples.size() - 1]) if not sorted_samples.is_empty() else 0.0
	var active_ids: PackedStringArray = _surface_ids(controller)
	var surface_node_count: int = _count_surface_nodes(controller)
	var display_server: String = DisplayServer.get_name()
	var render_objects: int = -1
	var render_primitives: int = -1
	var render_draw_calls: int = -1
	if display_server != "headless":
		render_objects = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		render_primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		render_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var async_total_ms: float = float(diagnostic.get("duration_usec", 0)) / 1000.0
	var factory_build_ms: float = float(_factory_build_usec) / 1000.0
	var record := {
		"phase": phase,
		"radius": radius,
		"desired_surface_chunks": desired_count,
		"active_surface_chunks": active_ids.size(),
		"surface_node_count": surface_node_count,
		"average_nodes_per_surface_chunk": float(surface_node_count) / float(maxi(1, active_ids.size())),
		"factory_calls": _factory_calls,
		"factory_build_ms": factory_build_ms,
		"async_total_ms": async_total_ms,
		"async_non_factory_ms": maxf(0.0, async_total_ms - factory_build_ms),
		"staged_count": int(diagnostic.get("staged_count", 0)),
		"newly_loaded_count": int(diagnostic.get("newly_loaded_count", 0)),
		"unloaded_stale_count": int(diagnostic.get("unloaded_stale_count", 0)),
		"frame_sample_count": sorted_samples.size(),
		"average_frame_interval_ms": average_frame_ms,
		"p95_frame_interval_ms": p95_frame_ms,
		"max_frame_interval_ms": max_frame_ms,
		"process_static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"process_node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"render_objects_last_frame": render_objects,
		"render_primitives_last_frame": render_primitives,
		"render_draw_calls_last_frame": render_draw_calls,
		"display_server": display_server,
		"os": OS.get_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count()
	}
	print("SURFACE_CHUNK_BENCHMARK_JSON:" + JSON.stringify(record))

func _wait_frames(frame_count: int) -> void:
	for frame_index in range(frame_count):
		await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish(world: Node) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	if failures.is_empty():
		print("Surface chunk production benchmark completed.")
		quit(0)
	else:
		for failure in failures:
			push_error("BENCHMARK FAILURE: " + failure)
		quit(1)
