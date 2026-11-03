extends SceneTree

const DirectorScript = preload("res://systems/MineralGridStreamingDirector.gd")

class FixtureController:
	extends Node3D

	var roots: Dictionary = {}

	func load_chunk(chunk_id: String, chunk_root: Node3D, _now_unix: int = -1) -> bool:
		if roots.has(chunk_id) or not is_instance_valid(chunk_root) or chunk_root.is_queued_for_deletion() or chunk_root.get_parent() != null:
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
var factory_calls: int = 0
var first_root: Node3D
var second_root: Node3D
var first_root_ref: WeakRef
var second_root_ref: WeakRef

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller := FixtureController.new()
	var director: Node = DirectorScript.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame

	_expect(bool(director.call("bind_controller", controller)), "fixture controller binds before async staging")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_root"))), "factory binds before async staging")
	director.connect("async_sync_completed", Callable(self, "_on_async_completed"))

	var request_id: int = int(director.call(
		"request_sync_to_world_position_async",
		Vector3.ZERO,
		int(Time.get_unix_time_from_system()) + 10,
		1
	))
	_expect(request_id > 0, "valid async request starts with one staged root per frame")
	var report: Dictionary = await _wait_for_request(request_id)
	_expect(not report.is_empty(), "queued staged-root request reaches a terminal report")
	_expect(not bool(report.get("success", true)), "a staged root queued during a yield aborts before commit")
	_expect(str(report.get("phase", "")) == "staged_root_validation", "lifecycle drift has a dedicated failure phase")

	var details: Dictionary = report.get("details", {})
	_expect(str(details.get("failure_reason", "")) == "staged_root_queued_for_deletion", "diagnostics identify the queued staged root")
	_expect(bool(report.get("rollback_complete", false)), "staged-root rejection reports complete rollback")
	_expect(factory_calls == 2, "the factory's second result triggers revalidation of the first staged root")
	_expect(controller.get_loaded_chunk_ids().is_empty(), "no root reaches the controller after staged-root lifecycle drift")
	_expect(director.call("get_managed_chunk_ids").is_empty(), "director managed map remains unchanged")
	_expect(int(director.call("get_async_staged_root_count", request_id)) == 0, "all staged-root tracking is cleared")
	_expect(int(director.call("get_active_async_request_id")) == -1, "failed request releases the active request lock")

	var diagnostics: Dictionary = director.call("get_async_request_diagnostics", request_id)
	_expect(str(diagnostics.get("cancellation_reason", "")) == "staged_root_queued_for_deletion", "terminal diagnostics preserve the precise lifecycle reason")

	await process_frame
	_expect(first_root_ref != null and first_root_ref.get_ref() == null, "externally queued staged root is released after the frame")
	_expect(second_root_ref != null and second_root_ref.get_ref() == null, "uncommitted factory candidate is freed on rejection")

	director.queue_free()
	controller.queue_free()
	await process_frame
	if failures.is_empty():
		print("Mineral grid staged-root lifecycle regression passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_root(_coord: Vector2i) -> Node3D:
	factory_calls += 1
	if factory_calls == 1:
		first_root = Node3D.new()
		first_root.name = "first_staged_root"
		first_root_ref = weakref(first_root)
		return first_root
	if is_instance_valid(first_root) and not first_root.is_queued_for_deletion():
		first_root.queue_free()
	second_root = Node3D.new()
	second_root.name = "second_uncommitted_root"
	second_root_ref = weakref(second_root)
	return second_root

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
