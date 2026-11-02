extends SceneTree

const Director = preload("res://systems/MineralGridStreamingDirector.gd")
const Panel = preload("res://systems/MineralGridStreamingDiagnosticsPanel.gd")
const FakeController = preload("res://tests/helpers/FakeMineralChunkController.gd")
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
	var request_id: int = director.call("request_sync_to_world_position_async", Vector3(15.0, 0.0, 0.0), 2001, 1)
	_expect(request_id > 0, "async window shift starts")
	var staged := false
	for _frame in range(120):
		if int(director.call("get_async_staged_root_count", request_id)) >= 1:
			staged = true
			break
		await process_frame
	_expect(staged, "test observes a real staged root")
	var panel: PanelContainer = Panel.new() as PanelContainer
	root.add_child(panel)
	panel.call("bind_director", director)
	panel.call("set_open", true)
	panel.call("refresh_now")
	var live_text: String = str(panel.call("get_rendered_text"))
	_expect(panel.visible, "panel opens")
	_expect(live_text.contains("ACTIVE #%d" % request_id), "panel reports active request ID")
	_expect(live_text.contains("staging"), "panel reports staging phase")
	_expect(live_text.contains("stage 1/9"), "panel reports staged versus desired roots")
	_expect(live_text.contains("rollback=pending"), "panel does not label an active request as already rolled back")
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
	_expect(int(panel.call("get_visible_row_count")) <= 6, "visible history is bounded")
	panel.call("set_open", false)
	_expect(not panel.visible, "panel hides")
	_expect(panel.call("toggle_open"), "panel toggle reopens")
	panel.call("bind_director", null)
	panel.call("refresh_now")
	_expect(str(panel.call("get_rendered_text")).contains("UNAVAILABLE"), "unbound director is handled")
	panel.queue_free()
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
