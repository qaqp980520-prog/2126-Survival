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
var shared_root: Node3D
var factory_calls: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller := FixtureController.new()
	var director: Node = DirectorScript.new()
	root.add_child(controller)
	root.add_child(director)
	_expect(bool(director.call("bind_controller", controller)), "fixture controller binds before the async request")
	shared_root = Node3D.new()
	shared_root.name = "reused_factory_root"
	var shared_reference: WeakRef = weakref(shared_root)
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_reused_root"))), "reusing factory binds before streaming")
	director.connect("async_sync_completed", Callable(self, "_on_async_completed"))

	var request_id: int = int(director.call(
		"request_sync_to_world_position_async", Vector3.ZERO, int(Time.get_unix_time_from_system()) + 10, 1
	))
	_expect(request_id > 0, "async request accepts a valid empty 3x3 window")
	var report: Dictionary = await _wait_for_request(request_id)
	_expect(not report.is_empty(), "duplicate-root request reaches a terminal report")
	_expect(not bool(report.get("success", true)), "factory instance reuse aborts the async request")
	_expect(str(report.get("phase", "")) == "load_factory", "duplicate-root reuse is reported as a factory failure")
	var details: Dictionary = report.get("details", {})
	_expect(bool(details.get("duplicate_staged_root_rejected", false)), "report identifies duplicate staged-root rejection")
	_expect(bool(report.get("rollback_complete", false)), "duplicate staged-root rejection reports complete rollback")
	_expect(factory_calls == 2, "the reused instance is detected on the second factory result")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "no staged root reaches the controller before duplicate rejection")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "director managed map remains empty after rejection")
	_expect(int(director.call("get_async_staged_root_count", request_id)) == 0, "staged-root tracking is cleared after rejection")
	_expect(shared_reference.get_ref() == null, "the single shared staged root is released exactly once")
	_expect(int(director.call("get_active_async_request_id")) == -1, "failed request releases the active request lock")
	var diagnostics: Dictionary = director.call("get_async_request_diagnostics", request_id)
	_expect(str(diagnostics.get("cancellation_reason", "")) == "factory_reused_staged_root", "diagnostics distinguish factory instance reuse from generic invalid roots")

	director.queue_free()
	controller.queue_free()
	await process_frame
	if failures.is_empty():
		print("Mineral grid duplicate staged-root regression passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_reused_root(_coord: Vector2i) -> Node3D:
	factory_calls += 1
	return shared_root

func _on_async_completed(request_id: int, report: Dictionary) -> void:
	completed_reports[request_id] = report.duplicate(true)

func _wait_for_request(request_id: int) -> Dictionary:
	for _frame in range(120):
		if completed_reports.has(request_id):
			return completed_reports[request_id].duplicate(true)
		await process_frame
	return {}

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
