extends SceneTree

const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Director = preload("res://systems/UndergroundMineDirector.gd")
const Factory = preload("res://systems/UndergroundMineFactory.gd")

var failures: Array[String] = []
var fail_coordinate: Vector2i = Vector2i(999, 999)
var registry: Node
var controller: Node3D
var director: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	registry = Registry.new()
	controller = Controller.new()
	director = Director.new()
	root.add_child(registry)
	root.add_child(controller)
	root.add_child(director)
	await process_frame
	_expect(bool(controller.call("bind_registry", registry)), "mineral chunk controller binds the registry")
	_expect(bool(director.call("bind_controller", controller)), "underground director binds the shared chunk controller")
	_expect(bool(director.call("bind_chunk_factory", Callable(self, "_make_chunk"))), "underground director accepts a deterministic factory")
	_expect(bool(director.call("sync_to_world_position", Vector3(1.5, -8.25, 7.5), 1000)), "initial underground window loads")
	_expect(director.call("get_managed_chunk_ids").size() == 9, "initial mine window contains nine chunks")
	_expect(controller.call("is_chunk_loaded", "underground/mine_0_0"), "origin mine chunk is loaded")
	_expect(controller.call("is_chunk_loaded", "underground/mine_-1_-1"), "negative-coordinate mine chunk is loaded")
	var center: Node3D = controller.call("get_chunk_root", "underground/mine_0_0")
	var east: Node3D = controller.call("get_chunk_root", "underground/mine_1_0")
	var vein: Node3D = center.get_node_or_null("Vein_0") if center != null else null
	var east_vein: Node3D = east.get_node_or_null("Vein_0") if east != null else null
	_expect(vein != null, "origin chunk contains a stable mineral node")
	_expect(east_vein != null and vein != null and str(east_vein.get("mineral_id")) != str(vein.get("mineral_id")), "mineral identity varies deterministically by room coordinate")
	if center != null and east != null:
		var east_wall_a: Node3D = center.get_node_or_null("MineWallEast_A")
		var east_wall_b: Node3D = center.get_node_or_null("MineWallEast_B")
		var west_wall_a: Node3D = east.get_node_or_null("MineWallWest_A")
		_expect(east_wall_a != null and east_wall_b != null and west_wall_a != null, "adjacent rooms create aligned split wall segments")
		if east_wall_a != null and east_wall_b != null and west_wall_a != null:
			_expect(is_equal_approx(east_wall_a.position.z, west_wall_a.position.z) and is_equal_approx(east_wall_a.position.z, 2.0) and is_equal_approx(east_wall_b.position.z, 8.0), "doorway gaps align across adjacent room boundaries")
	if vein != null:
		vein.set("remaining_units", 5)
	_expect(bool(director.call("sync_to_world_position", Vector3(21.5, -8.25, 7.5), 1001)), "moving two chunks east shifts the mine window")
	_expect(director.call("get_managed_chunk_ids").size() == 9, "shifted mine window remains bounded to nine chunks")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_0_0")), "stale origin chunk unloads outside the radius")
	_expect(bool(controller.call("is_chunk_loaded", "underground/mine_2_0")), "new east mine chunk loads")
	_expect(bool(director.call("sync_to_world_position", Vector3(1.5, -8.25, 7.5), 1002)), "returning to the origin reloads its stable chunk")
	var restored: Node3D = controller.call("get_chunk_root", "underground/mine_0_0")
	var restored_vein: Node3D = restored.get_node_or_null("Vein_0") if restored != null else null
	_expect(restored_vein != null and int(restored_vein.get("remaining_units")) == 5, "mineral stock survives a real director unload/reload")
	var previous_ids: PackedStringArray = director.call("get_managed_chunk_ids")
	var previous_saved_ids: PackedStringArray = registry.call("get_saved_ids")
	_expect(not bool(director.call("sync_to_world_position", Vector3(INF, -8.25, 7.5), 1002)), "non-finite underground positions are rejected")
	_expect(director.call("get_managed_chunk_ids") == previous_ids, "invalid position leaves the active mine window unchanged")
	fail_coordinate = Vector2i(3, -1)
	_expect(not bool(director.call("sync_to_world_position", Vector3(21.5, -8.25, 7.5), 1003)), "factory failure rejects the shifted window")
	_expect(director.call("get_managed_chunk_ids") == previous_ids, "failed sync restores the previous managed ID set")
	_expect(bool(controller.call("is_chunk_loaded", "underground/mine_0_0")), "failed sync preserves the old origin chunk")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_2_-1")), "failed sync rolls back a partial new load")
	_expect(not bool(controller.call("is_chunk_loaded", "underground/mine_3_-1")), "failed factory chunk is never registered")
	_expect(registry.call("get_saved_ids") == previous_saved_ids, "failed window generation leaves no orphan mineral records")
	var report: Dictionary = director.call("get_last_sync_report")
	_expect(bool(report.get("rollback_complete", false)), "failed sync reports a complete rollback")
	_finish(0 if failures.is_empty() else 1)

func _make_chunk(coord: Vector2i, now_unix: int) -> Node3D:
	if coord == fail_coordinate:
		return null
	return Factory.make_chunk(now_unix, coord)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(director):
		director.queue_free()
	if is_instance_valid(controller):
		controller.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Underground mine director tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
