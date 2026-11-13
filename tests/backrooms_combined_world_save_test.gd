extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")

var failures: Array[String] = []
var source_world: Node3D
var restored_world: Node3D

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	source_world = WorldScene.instantiate() as Node3D
	_expect(source_world != null, "source SurfaceWorld scene instantiates")
	if source_world == null:
		_finish(1)
		return
	root.add_child(source_world)
	await process_frame
	var source_player: CharacterBody3D = source_world.get("player") as CharacterBody3D
	var director: RefCounted = source_world.get("backrooms_portal_director") as RefCounted
	_expect(source_player != null and director != null, "source SurfaceWorld creates its production player and portal director")
	if source_player == null or director == null:
		_finish(1)
		return
	var now: int = int(Time.get_unix_time_from_system())
	director.set("next_spawn_in", 0.01)
	source_world.call("_process", 0.02)
	var portal: Area3D = source_world.get("backrooms_portal_visual") as Area3D
	_expect(portal != null, "production portal director creates a live portal visual")
	if portal == null:
		_finish(1)
		return
	var active_portal: Dictionary = director.get("active_portal")
	var portal_position_value: Variant = active_portal.get("position", null)
	_expect(portal_position_value is Vector2, "active portal exposes a valid world position")
	if not (portal_position_value is Vector2):
		_finish(1)
		return
	var portal_position: Vector2 = portal_position_value
	var approach_position := Vector3(portal_position.x, 2.0, portal_position.y + 2.0)
	_expect(bool(source_world.call("debug_move_player_to", approach_position, now)), "source player streams to the active portal's owning surface window")
	await process_frame
	portal = source_world.get("backrooms_portal_visual") as Area3D
	_expect(portal != null, "portal visual remains available after approaching its owning chunk")
	if portal == null:
		_finish(1)
		return
	var portal_id: int = int(portal.get("portal_id"))
	_expect(bool(portal.call("interact", source_player)), "production portal accepts the nearby player")
	var entry: Dictionary = source_world.call("enter_backrooms_from_portal", portal_id)
	_expect(bool(entry.get("ok", false)), "production SurfaceWorld completes the real Backrooms handoff")
	if not bool(entry.get("ok", false)):
		_finish(1)
		return
	_expect(bool(source_world.get("_is_in_backrooms")), "source SurfaceWorld enters Backrooms mode")
	var source_manager: RefCounted = source_world.get("backrooms_transition_manager") as RefCounted
	var source_runtime: Node3D = source_world.get("backrooms_maze_runtime") as Node3D
	var source_session: RefCounted = source_manager.call("get_session") as RefCounted
	var shifted_position: Vector3 = source_player.global_position + Vector3(8.0, 0.0, 0.0)
	var shifted: Dictionary = source_manager.call("sync_backrooms_runtime", source_runtime, shifted_position)
	_expect(bool(shifted.get("ok", false)), "source Backrooms runtime and Session synchronize one streamed cell shift")
	if not bool(shifted.get("ok", false)):
		_finish(1)
		return
	source_player.global_position = shifted_position
	source_world.set("_last_backrooms_sync_position", shifted_position)
	var envelope: Dictionary = source_world.call("serialize_world_envelope")
	_expect(not envelope.is_empty(), "active Backrooms state serializes through the combined world envelope")
	_expect(str(envelope.get("active_location", "")) == "backrooms", "combined envelope records Backrooms as the active location")
	_expect(envelope.get("backrooms_session", {}) == source_session.call("to_save_dict"), "combined envelope stores the complete active LocationSession")
	_expect(envelope.get("backrooms_runtime", {}) == source_runtime.call("to_save_dict"), "combined envelope stores the exact live maze runtime state")
	_expect(envelope.get("surface_world", {}).get("player_position", []) == source_session.call("to_save_dict").get("surface_return_position", []), "surface payload is anchored to the exact return position")
	_expect(envelope.get("backrooms_player", {}).get("position", []) == [shifted_position.x, shifted_position.y, shifted_position.z], "Backrooms player transform is stored independently from the surface return transform")
	_expect(envelope.get("surface_chunk_ids", []).size() == 9, "combined envelope records the exact loaded 3x3 surface window")
	_expect(envelope.get("surface_chunk_visibility", {}).size() == 9, "combined envelope records every loaded surface chunk's original visibility")
	_expect(source_world.call("serialize_stream_state") == {}, "legacy surface-only serialization remains fail-closed while Backrooms is active")
	if envelope.is_empty():
		_finish(1)
		return

	restored_world = WorldScene.instantiate() as Node3D
	_expect(restored_world != null, "fresh SurfaceWorld restore target instantiates")
	if restored_world == null:
		_finish(1)
		return
	root.add_child(restored_world)
	await process_frame
	var restored_player: CharacterBody3D = restored_world.get("player") as CharacterBody3D
	var restored_manager: RefCounted = restored_world.get("backrooms_transition_manager") as RefCounted
	var restored_runtime: Node3D = restored_world.get("backrooms_maze_runtime") as Node3D
	var restored_session: RefCounted = restored_manager.call("get_session") as RefCounted
	var baseline_surface: Dictionary = restored_world.call("serialize_stream_state")
	var baseline_position: Vector3 = restored_player.global_position
	var baseline_surface_ids: Array = _loaded_surface_ids(restored_world)
	var baseline_session: Dictionary = restored_session.call("to_save_dict")
	var restored_controller: Node = restored_world.get("chunk_controller") as Node
	_expect(not baseline_surface.is_empty() and baseline_surface_ids.size() == 9, "fresh restore target captures a complete baseline surface snapshot")
	var invalid_envelope: Dictionary = envelope.duplicate(true)
	invalid_envelope["backrooms_session"]["surface_world_seed"] = int(invalid_envelope["backrooms_session"].get("surface_world_seed", 0)) + 1
	_expect(not bool(restored_world.call("restore_world_envelope", invalid_envelope, now + 1)), "combined restore rejects a Session bound to a different surface seed")
	_expect(restored_world.call("serialize_stream_state") == baseline_surface, "preflight rejection leaves the complete fresh SurfaceWorld payload unchanged")
	_expect(restored_session.call("to_save_dict") == baseline_session and not bool(restored_session.call("is_active")), "preflight rejection leaves the Session inactive and unchanged")
	_expect(not bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")), "preflight rejection leaves the maze runtime empty")

	restored_runtime.call("set_cell_builder_for_testing", Callable(self, "_reject_maze_cell_builder"))
	var failed_restore: bool = bool(restored_world.call("restore_world_envelope", envelope, now + 2))
	var failed_report: Dictionary = restored_world.call("get_last_world_envelope_restore_report")
	_expect(not failed_restore and str(failed_report.get("phase", "")) == "runtime_restore", "injected maze-cell staging failure rejects the combined restore at the runtime phase")
	_expect(bool(failed_report.get("rollback_complete", false)), "runtime staging failure reports a complete combined-world rollback")
	restored_runtime.call("clear_cell_builder_for_testing")
	_expect(not bool(restored_world.get("_is_in_backrooms")), "failed combined restore leaves the target in SurfaceWorld mode")
	_expect(restored_world.call("serialize_stream_state") == baseline_surface, "failed combined restore restores the exact pre-attempt SurfaceWorld save payload")
	_expect(_loaded_surface_ids(restored_world) == baseline_surface_ids, "failed combined restore restores the exact pre-attempt surface chunk window")
	_expect(restored_player.global_position.is_equal_approx(baseline_position), "failed combined restore restores the original player position")
	_expect(restored_session.call("to_save_dict") == baseline_session and not bool(restored_session.call("is_active")), "failed combined restore returns LocationSession to its exact inactive snapshot")
	_expect(not bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")) and int(restored_runtime.call("get_loaded_cell_count")) == 0, "failed combined restore leaves no staged maze cells")
	_expect(str(restored_manager.call("get_state_name")) == "IDLE", "failed combined restore returns the transition manager to IDLE")

	var restored: bool = bool(restored_world.call("restore_world_envelope", envelope, now + 3))
	_expect(restored, "combined envelope restores SurfaceWorld, LocationSession, maze runtime and player as one operation")
	if restored:
		var saved_session: Dictionary = envelope.get("backrooms_session", {})
		var saved_backrooms_position_value: Array = envelope.get("backrooms_player", {}).get("position", [])
		var saved_backrooms_position := Vector3(
			float(saved_backrooms_position_value[0]),
			float(saved_backrooms_position_value[1]),
			float(saved_backrooms_position_value[2])
		)
		_expect(bool(restored_world.get("_is_in_backrooms")), "restored world switches into Backrooms mode only after runtime activation")
		_expect(restored_player.global_position.is_equal_approx(saved_backrooms_position), "restored player returns to the exact saved Backrooms position")
		_expect(restored_session.call("to_save_dict") == saved_session, "restored LocationSession exactly matches the saved Session")
		_expect(restored_runtime.call("to_save_dict") == envelope.get("backrooms_runtime", {}), "restored maze runtime exactly matches the saved stream state")
		_expect(bool(restored_runtime.call("is_prepared")) and bool(restored_runtime.call("is_active")) and restored_runtime.visible, "restored maze runtime is prepared, active and visible")
		_expect(_loaded_surface_ids(restored_world) == envelope.get("surface_chunk_ids", []), "restored world retains the exact saved surface chunk window")
		for chunk_id_value in envelope.get("surface_chunk_ids", []):
			var chunk_id: String = str(chunk_id_value)
			var surface_root: Node3D = restored_controller.call("get_chunk_root", chunk_id) as Node3D
			_expect(surface_root != null and not surface_root.visible, "surface chunk %s remains hidden while Backrooms is active" % chunk_id)
		var returned: Dictionary = restored_world.call("return_from_backrooms")
		_expect(bool(returned.get("ok", false)), "restored Backrooms Session can return to SurfaceWorld normally")
		_expect(not bool(restored_world.get("_is_in_backrooms")), "successful restored return clears Backrooms world mode")
		var saved_return: Array = saved_session.get("surface_return_position", [])
		var expected_return := Vector3(float(saved_return[0]), float(saved_return[1]), float(saved_return[2]))
		_expect(restored_player.global_position.is_equal_approx(expected_return), "restored return reaches the exact saved surface return position")
		_expect(not bool(restored_session.call("is_active")) and not bool(restored_runtime.call("is_prepared")), "successful return clears Session and retires the restored maze runtime")
		for chunk_id_value in envelope.get("surface_chunk_ids", []):
			var chunk_id: String = str(chunk_id_value)
			var surface_root: Node3D = restored_world.chunk_controller.call("get_chunk_root", chunk_id) as Node3D
			var expected_visible: bool = bool(envelope.get("surface_chunk_visibility", {}).get(chunk_id, true))
			_expect(surface_root != null and surface_root.visible == expected_visible, "return restores original visibility for surface chunk %s" % chunk_id)

	var source_return: Dictionary = source_world.call("return_from_backrooms")
	_expect(bool(source_return.get("ok", false)), "source world remains independently returnable after the combined save round-trip")
	_finish(0 if failures.is_empty() else 1)


func _reject_maze_cell_builder(_descriptor: Dictionary, _metadata_only: bool) -> Node3D:
	return null


func _loaded_surface_ids(candidate: Node3D) -> Array:
	var ids: Array = []
	var controller: Node = candidate.get("chunk_controller") as Node
	if controller == null:
		return ids
	for id_value in controller.call("get_loaded_chunk_ids"):
		var chunk_id: String = str(id_value)
		if chunk_id.begins_with("surface/"):
			ids.append(chunk_id)
	ids.sort()
	return ids


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish(exit_code: int) -> void:
	if is_instance_valid(restored_world):
		restored_world.queue_free()
	if is_instance_valid(source_world):
		source_world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Backrooms combined world save envelope tests passed.")
		quit(0)
	else:
		push_error("Backrooms combined world save envelope tests failed: %d" % failures.size())
		quit(1)
