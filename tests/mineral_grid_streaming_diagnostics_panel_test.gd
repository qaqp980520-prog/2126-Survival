extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const DiagnosticsPanelScript = preload("res://systems/MineralGridStreamingDiagnosticsPanel.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")

class FakeCornerProvider extends Node:
	var reports: Array[Dictionary] = []

	func get_blocked_terrain_corner_reports() -> Array[Dictionary]:
		return reports.duplicate(true)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = FakeController.new()
	var director: Node = Director.new()
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	director.chunk_size_x = 10.0
	director.chunk_size_z = 10.0
	director.load_radius = 1
	_expect(bool(director.call("bind_controller", controller)), "fixture binds controller")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "fixture binds factory")
	_expect(bool(director.call("sync_to_world_position", Vector3.ZERO, 2000)), "fixture creates initial window")
	var request_id: int = int(director.call("request_sync_to_world_position_async", Vector3(15.0, 0.0, 0.0), 2001, 1))
	_expect(request_id > 0, "async window shift starts")
	var staged := false
	for _frame in range(120):
		if int(director.call("get_async_staged_root_count", request_id)) >= 1:
			staged = true
			break
		await process_frame
	_expect(staged, "test observes a real staged root")
	var panel: PanelContainer = DiagnosticsPanelScript.new() as PanelContainer
	root.add_child(panel)
	var corner_provider := FakeCornerProvider.new()
	corner_provider.reports = [{
		"stable_id": "surface/patch_4_4",
		"corner": "north_east",
		"edge_keys": ["edge_east", "edge_north"],
		"policy": "step_fallback"
	}]
	root.add_child(corner_provider)
	panel.call("bind_director", director)
	panel.call("bind_corner_provider", corner_provider)
	panel.call("set_open", true)
	panel.call("refresh_now")
	var live_text: String = str(panel.call("get_rendered_text"))
	_expect(panel.visible, "panel opens")
	_expect(live_text.contains("ACTIVE #%d" % request_id), "panel reports active request ID")
	_expect(live_text.contains("staging"), "panel reports staging phase")
	_expect(live_text.contains("stage 1/9"), "panel reports staged versus desired roots")
	_expect(live_text.contains("rollback=pending"), "panel does not label an active request as already rolled back")
	_expect(live_text.contains("north_east"), "panel displays the blocked terrain corner orientation")
	_expect(live_text.contains("surface/patch_4_4"), "panel displays the affected patch Stable ID")
	_expect(live_text.contains("step_fallback"), "panel displays the active safe corner policy")
	_expect(bool(director.call("cancel_async_sync_request", request_id)), "explicit cancellation is accepted")
	var terminal: Dictionary = {}
	for _frame in range(120):
		terminal = director.call("get_async_request_diagnostics", request_id)
		if bool(terminal.get("terminal", false)):
			break
		await process_frame
	_expect(bool(terminal.get("terminal", false)), "cancelled request reaches terminal state")
	panel.call("refresh_now")
	var cancelled_text: String = str(panel.call("get_rendered_text"))
	_expect(cancelled_text.contains("cancelled"), "panel displays terminal cancellation")
	_expect(cancelled_text.contains("explicit_cancel"), "panel displays cancellation reason")
	_expect(cancelled_text.contains("rollback=ok"), "panel reports successful cancellation cleanup")

	var completed_request_id: int = int(director.call("request_sync_to_world_position_async", Vector3(25.0, 0.0, 0.0), 2002, 2))
	_expect(completed_request_id > 0, "second async window shift starts after cancellation")
	var completed_request: Dictionary = {}
	for _frame in range(240):
		completed_request = director.call("get_async_request_diagnostics", completed_request_id)
		if bool(completed_request.get("terminal", false)):
			break
		await process_frame
	_expect(bool(completed_request.get("terminal", false)) and bool(completed_request.get("success", false)), "second async request completes successfully")
	var completed_center: Variant = completed_request.get("center")
	_expect(completed_center is Vector2i and completed_center == Vector2i(2, 0), "completed request records its real Vector2i chunk center")
	panel.call("refresh_now")
	_expect(int(panel.call("get_visible_row_count")) <= 6, "visible history is bounded")
	_expect(panel.call("get_export_button_count") == 1, "panel exposes an export snapshot button")
	var safe_vector: Dictionary = panel.call("_json_safe", {"center": Vector2i(3, 4), "path": [Vector2(1.5, 2.5)]})
	_expect(safe_vector.get("center", {}).get("x", -1) == 3 and safe_vector.get("center", {}).get("y", -1) == 4, "snapshot converts Vector2i diagnostics into JSON-safe coordinates")
	_expect(safe_vector.get("path", [])[0].get("x", -1.0) == 1.5, "snapshot recursively converts nested Vector2 values")
	var snapshot: Dictionary = panel.call("build_export_snapshot")
	_expect(int(snapshot.get("schema_version", 0)) == 1, "export snapshot declares schema version 1")
	var successful_export_record: Dictionary = {}
	for record in snapshot.get("history", []):
		if int(record.get("request_id", -1)) == completed_request_id:
			successful_export_record = record
	var exported_center: Dictionary = successful_export_record.get("center", {})
	_expect(exported_center.get("x", -1) == 2 and exported_center.get("y", -1) == 0, "JSON-safe snapshot preserves the completed request center")
	_expect(int(snapshot.get("active_request_id", -2)) == -1, "terminal request is no longer active")
	_expect((snapshot.get("history", []) as Array).size() <= 32, "export history respects the 32-record cap")
	var exported_corners: Array = snapshot.get("blocked_corners", [])
	_expect(exported_corners.size() == 1, "export includes blocked terrain corner reports")
	if not exported_corners.is_empty():
		var exported_edges: Array = exported_corners[0].get("edge_keys", [])
		exported_edges.append("tampered")
		_expect((corner_provider.reports[0].get("edge_keys", []) as Array).size() == 2, "export snapshot deep-copies nested corner arrays")
	var parsed_json: Variant = JSON.parse_string(str(panel.call("export_snapshot_json")))
	_expect(parsed_json is Dictionary and int(parsed_json.get("schema_version", 0)) == 1, "export JSON parses into the versioned snapshot")
	var snapshot_path: String = "user://run88_streaming_diagnostics_snapshot_test.json"
	_expect(bool(panel.call("save_snapshot_to_file", snapshot_path)), "snapshot writes to user data storage")
	var saved_text: String = FileAccess.get_file_as_string(snapshot_path)
	_expect(not saved_text.is_empty() and JSON.parse_string(saved_text) is Dictionary, "saved snapshot is valid JSON")
	_expect(not bool(panel.call("save_snapshot_to_file", "res://forbidden_snapshot.json")), "snapshot export refuses project-resource paths")
	_expect(not bool(panel.call("is_safe_export_path", "user://folder/../escape.json")), "snapshot path validator rejects parent traversal")
	_expect(not bool(panel.call("save_snapshot_to_file", "user://folder/../escape.json")), "snapshot writer refuses parent traversal")
	_expect(not bool(panel.call("is_safe_export_path", "user://folder\\\\..\\\\escape.json")), "snapshot path validator rejects backslash traversal")
	var export_button := panel.find_child("ExportSnapshot", true, false) as Button
	_expect(export_button != null, "snapshot export button is discoverable through the UI tree")
	if export_button != null:
		export_button.emit_signal("pressed")
		var export_status := panel.find_child("ExportStatus", true, false) as Label
		_expect(export_status != null and export_status.text.begins_with("SAVED"), "pressing the export button writes the default snapshot and updates status")
		_expect(FileAccess.file_exists("user://streaming_diagnostics_snapshot.json"), "default snapshot file exists after button activation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(snapshot_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://streaming_diagnostics_snapshot.json"))
	corner_provider.reports.clear()
	panel.call("refresh_now")
	_expect(str(panel.call("get_rendered_text")).contains("NONE BLOCKED"), "panel reports when no terrain corners are blocked")
	panel.call("set_open", false)
	_expect(not panel.visible, "panel hides")
	_expect(bool(panel.call("toggle_open")), "panel toggle reopens")
	panel.call("bind_director", null)
	panel.call("bind_corner_provider", null)
	panel.call("refresh_now")
	_expect(str(panel.call("get_rendered_text")).contains("UNAVAILABLE"), "unbound director is handled")
	_expect(str(panel.call("get_rendered_text")).contains("TERRAIN CORNERS · PROVIDER UNAVAILABLE"), "unbound corner provider is handled")
	panel.queue_free()
	corner_provider.queue_free()
	director.queue_free()
	controller.queue_free()
	await process_frame
	if failures.is_empty():
		print("Mineral grid streaming diagnostics panel tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _make_chunk(coord: Vector2i) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "panel_test_chunk_%d_%d" % [coord.x, coord.y]
	return chunk

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
