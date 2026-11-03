extends SceneTree

const DirectorScript = preload("res://systems/MineralGridStreamingDirector.gd")

class FixtureController:
	extends Node3D

	var roots: Dictionary = {}

	func load_chunk(chunk_id: String, chunk_root: Node3D, _now_unix: int = -1) -> bool:
		if roots.has(chunk_id) or not is_instance_valid(chunk_root) or chunk_root.get_parent() != null:
			return false
		add_child(chunk_root)
		roots[chunk_id] = chunk_root
		return true

	func unload_chunk(chunk_id: String, _now_unix: int = -1) -> bool:
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
		var result := PackedStringArray()
		for chunk_id in roots.keys():
			result.append(str(chunk_id))
		result.sort()
		return result

var failures: Array[String] = []
var completed_reports: Dictionary = {}
var primary_factory_calls: int = 0
var alternate_factory_calls: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller := FixtureController.new()
	var replacement := FixtureController.new()
	var director: Node = DirectorScript.new()
	root.add_child(controller)
	root.add_child(replacement)
	root.add_child(director)
	_expect(bool(director.call("bind_controller", controller)), "initial empty controller binds before streaming")
	var primary_factory := Callable(self, "_make_primary_chunk")
	var alternate_factory := Callable(self, "_make_alternate_chunk")
	_expect(bool(director.call("bind_chunk_factory", primary_factory)), "initial chunk factory binds before streaming")
	director.connect("async_sync_completed", Callable(self, "_on_async_completed"))

	var request_id: int = int(director.call(
		"request_sync_to_world_position_async", Vector3.ZERO, int(Time.get_unix_time_from_system()) + 10, 1
	))
	_expect(request_id > 0, "first async window request is accepted with no previously managed chunks")
	var staged_ready: bool = await _wait_for_staged_root_count(director, request_id, 1)
	_expect(staged_ready, "binding guard test observes a detached staged root before commit")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "binding guard scenario begins with an empty managed window")
	var staged_refs: Array = director.call("get_async_staged_root_weakrefs", request_id)
	_expect(not staged_refs.is_empty(), "binding guard test captures staged-root weak references")

	_expect(not bool(director.call("bind_controller", replacement)), "controller replacement is rejected while an async request is active")
	_expect(director.get("chunk_controller") == controller, "active request retains its original controller dependency")
	_expect(not bool(director.call("bind_chunk_factory", alternate_factory)), "factory replacement is rejected while an async request is active")
	_expect(int(director.call("get_active_async_request_id")) == request_id, "rejected rebinding does not cancel or replace the active request")

	var report: Dictionary = await _wait_for_request(request_id)
	_expect(bool(report.get("success", false)) and str(report.get("phase", "")) == "complete", "original request commits successfully after rejected rebinding")
	_expect(primary_factory_calls == 9 and alternate_factory_calls == 0, "all nine staged roots come from the original factory")
	_expect(controller.get_loaded_chunk_ids().size() == 9, "original controller receives the complete 3x3 window")
	_expect(replacement.get_loaded_chunk_ids().is_empty(), "replacement controller receives no roots")
	_expect(controller.get_loaded_chunk_ids() == director.call("get_managed_chunk_ids"), "controller and director ownership maps remain synchronized")
	for reference in staged_refs:
		_expect(reference.get_ref() != null, "staged roots remain alive after being committed to the original controller")

	_expect(bool(director.call("bind_chunk_factory", alternate_factory)), "factory can be rebound after the async request reaches a terminal state")

	director.queue_free()
	controller.queue_free()
	replacement.queue_free()
	await process_frame
	if failures.is_empty():
		print("Mineral grid streaming binding guard tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_primary_chunk(coord: Vector2i) -> Node3D:
	primary_factory_calls += 1
	var chunk := Node3D.new()
	chunk.name = "primary_%d_%d" % [coord.x, coord.y]
	return chunk

func _make_alternate_chunk(coord: Vector2i) -> Node3D:
	alternate_factory_calls += 1
	var chunk := Node3D.new()
	chunk.name = "alternate_%d_%d" % [coord.x, coord.y]
	return chunk

func _on_async_completed(request_id: int, report: Dictionary) -> void:
	completed_reports[request_id] = report.duplicate(true)

func _wait_for_staged_root_count(director: Node, request_id: int, minimum: int) -> bool:
	for _frame in range(120):
		if int(director.call("get_async_staged_root_count", request_id)) >= minimum:
			return true
		await process_frame
	return false

func _wait_for_request(request_id: int) -> Dictionary:
	for _frame in range(180):
		if completed_reports.has(request_id):
			return completed_reports[request_id].duplicate(true)
		await process_frame
	return {}
