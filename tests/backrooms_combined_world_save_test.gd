extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")

class FailAlwaysStamina extends RefCounted:
	var current_stamina: float = 100.0
	var _payload: Dictionary = {}

	func _init(initial_payload: Dictionary) -> void:
		_payload = initial_payload.duplicate(true)
		current_stamina = float(_payload.get("current", 100.0))

	func to_save_dict() -> Dictionary:
		return _payload.duplicate(true)

	func load_save_dict(data: Dictionary) -> bool:
		_payload = data.duplicate(true)
		current_stamina = float(_payload.get("current", 100.0))
		return false

	func can_jump() -> bool:
		return current_stamina >= 10.0

	func can_sprint() -> bool:
		return current_stamina >= 5.0

	func get_movement_speed_multiplier(_sprinting: bool = false) -> float:
		return 1.0 if current_stamina > 0.0 else 0.65

	func get_max_stamina() -> float:
		return 100.0

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
	var source_environment: WorldEnvironment = source_world.get("surface_world_environment") as WorldEnvironment
	var original_source_environment: Environment = source_environment.environment
	var source_sun: DirectionalLight3D = source_world.get("surface_sun") as DirectionalLight3D
	var source_lighting_controller: RefCounted = source_world.get("backrooms_lighting_controller") as RefCounted
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
	_expect(bool(source_lighting_controller.call("is_active")), "portal entry activates the level-specific Backrooms lighting controller")
	_expect(source_environment.environment != original_source_environment, "portal entry swaps in a dedicated Backrooms Environment clone")
	_expect(is_zero_approx(source_sun.light_energy), "portal entry disables the SurfaceWorld directional sun energy")
	var source_manager: RefCounted = source_world.get("backrooms_transition_manager") as RefCounted
	var source_runtime: Node3D = source_world.get("backrooms_maze_runtime") as Node3D
	var source_session: RefCounted = source_manager.call("get_session") as RefCounted
	var shifted_position: Vector3 = source_player.global_position + Vector3(8.0, 0.0, 0.0)
	source_player.global_position = shifted_position
	var envelope: Dictionary = source_world.call("serialize_world_envelope")
	_expect(envelope.get("backrooms_session", {}).get("backrooms_position", []) == [shifted_position.x, shifted_position.y, shifted_position.z], "save finalizes the latest player transform into the runtime and Session before snapshotting")
	_expect(not envelope.is_empty(), "active Backrooms state serializes through the combined world envelope")
	_expect(str(envelope.get("active_location", "")) == "backrooms", "combined envelope records Backrooms as the active location")
	_expect(envelope.get("backrooms_session", {}) == source_session.call("to_save_dict"), "combined envelope stores the complete active LocationSession")
	_expect(envelope.get("backrooms_runtime", {}) == source_runtime.call("to_save_dict"), "combined envelope stores the exact live maze runtime state")
	_expect(int(envelope.get("backrooms_runtime", {}).get("schema_version", -1)) == 4, "combined envelope preserves the entity ownership maze stream schema")
	_expect(int(envelope.get("backrooms_runtime", {}).get("entity_runtime_state_version", -1)) == 2, "combined envelope preserves the entity-state codec v2 version")
	_expect(envelope.get("backrooms_runtime", {}).get("entity_runtime_states", null) is Array, "combined envelope stores the bounded mobile-entity state cache")
	_expect(int(envelope.get("backrooms_runtime", {}).get("entity_ownership_ledger_version", -1)) == 1, "combined envelope declares ownership ledger schema version one")
	_expect(envelope.get("backrooms_runtime", {}).get("entity_ownership_ledger", null) is Dictionary, "combined envelope stores the committed entity ownership ledger")
	_expect(int(envelope.get("backrooms_runtime", {}).get("entity_spawn_algorithm_version", -1)) == 1, "combined envelope preserves the entity-spawn algorithm version")
	_expect(int(envelope.get("backrooms_session", {}).get("maze_stream_state", {}).get("schema_version", -1)) == 4, "combined envelope Session carries the same entity-ownership maze stream")
	_expect(envelope.get("surface_world", {}).get("player_position", []) == source_session.call("to_save_dict").get("surface_return_position", []), "surface payload is anchored to the exact return position")
	_expect(envelope.get("backrooms_player", {}).get("position", []) == [shifted_position.x, shifted_position.y, shifted_position.z], "Backrooms player transform is stored independently from the surface return transform")
	_expect(envelope.get("surface_chunk_ids", []).size() == 9, "combined envelope records the exact loaded 3x3 surface window")
	_expect(envelope.get("surface_chunk_visibility", {}).size() == 9, "combined envelope records every loaded surface chunk's original visibility")
	_expect(source_world.call("serialize_stream_state") == {}, "legacy surface-only serialization remains fail-closed while Backrooms is active")
	if envelope.is_empty():
		_finish(1)
		return

	# Force the nested SurfaceWorld restore to fail after applying its base payload,
	# then fail again while restoring the prior stamina snapshot. The combined
	# envelope boundary must mark the world fail-closed rather than permit play
	# with an incomplete cross-system rollback.
	var fail_closed_world: Node3D = WorldScene.instantiate() as Node3D
	_expect(fail_closed_world != null, "fail-closed restore target instantiates")
	if fail_closed_world == null:
		_finish(1)
		return
	root.add_child(fail_closed_world)
	await process_frame
	var original_fail_closed_stamina: RefCounted = fail_closed_world.get("stamina") as RefCounted
	fail_closed_world.set("stamina", FailAlwaysStamina.new(original_fail_closed_stamina.call("to_save_dict")))
	var incomplete_surface_restore: bool = bool(fail_closed_world.call("restore_world_envelope", envelope, now + 1))
	var incomplete_surface_report: Dictionary = fail_closed_world.call("get_last_world_envelope_restore_report")
	_expect(not incomplete_surface_restore and str(incomplete_surface_report.get("phase", "")) == "surface_restore", "combined restore rejects a surface payload whose auxiliary apply fails")
	_expect(not bool(incomplete_surface_report.get("rollback_complete", true)), "combined restore exposes the incomplete nested SurfaceWorld rollback")
	_expect(bool(fail_closed_world.get("_surface_stream_pending")), "incomplete nested SurfaceWorld rollback locks streaming fail-closed")
	_expect(not bool(fail_closed_world.get("_is_in_backrooms")), "failed surface restore never activates the Backrooms world")
	var fail_closed_manager: RefCounted = fail_closed_world.get("backrooms_transition_manager") as RefCounted
	var fail_closed_runtime: Node3D = fail_closed_world.get("backrooms_maze_runtime") as Node3D
	_expect(not bool(fail_closed_manager.call("get_session_save_dict").get("active", false)), "failed surface restore leaves the Backrooms Session inactive")
	_expect(not bool(fail_closed_runtime.call("is_prepared")) and not bool(fail_closed_runtime.call("is_active")), "failed surface restore leaves the maze runtime unprepared and inactive")
	fail_closed_world.queue_free()
	await process_frame

	restored_world = WorldScene.instantiate() as Node3D
	_expect(restored_world != null, "fresh SurfaceWorld restore target instantiates")
	if restored_world == null:
		_finish(1)
		return
	root.add_child(restored_world)
	await process_frame
	var restored_environment: WorldEnvironment = restored_world.get("surface_world_environment") as WorldEnvironment
	var original_restored_environment: Environment = restored_environment.environment
	var restored_sun: DirectionalLight3D = restored_world.get("surface_sun") as DirectionalLight3D
	var restored_lighting_controller: RefCounted = restored_world.get("backrooms_lighting_controller") as RefCounted
	var restored_player: CharacterBody3D = restored_world.get("player") as CharacterBody3D
	var restored_manager: RefCounted = restored_world.get("backrooms_transition_manager") as RefCounted
	var restored_runtime: Node3D = restored_world.get("backrooms_maze_runtime") as Node3D
	var restored_session: RefCounted = restored_manager.call("get_session") as RefCounted
	var restored_controller: Node = restored_world.get("chunk_controller") as Node
	var surface_envelope: Dictionary = restored_world.call("serialize_world_envelope")
	_expect(str(surface_envelope.get("active_location", "")) == "surface", "combined envelope also serializes the ordinary surface location")
	_expect(bool(restored_world.call("restore_world_envelope", surface_envelope, now + 1)), "ordinary surface envelope round-trips through the combined restore API")
	var baseline_surface: Dictionary = restored_world.call("serialize_stream_state")
	var baseline_position: Vector3 = restored_player.global_position
	var baseline_surface_return: Vector3 = restored_world.get("_surface_return_position")
	var baseline_surface_ids: Array = _loaded_surface_ids(restored_world)
	var baseline_session: Dictionary = restored_session.call("to_save_dict")
	_expect(not baseline_surface.is_empty() and baseline_surface_ids.size() == 9, "fresh restore target captures a complete baseline surface snapshot after surface round-trip")
	# The combined envelope also supports an active underground mine visit. Exercise
	# that location independently from the Backrooms branch so its layer/depth and
	# return anchor survive the same envelope boundary.
	var mine_director: Node = restored_world.get("mine_director") as Node
	_expect(mine_director != null, "combined envelope target exposes its production underground mine director")
	if mine_director != null:
		var underground_layer: int = 2
		var underground_floor_y: float = float(mine_director.call("get_layer_floor_y", underground_layer))
		_expect(is_finite(underground_floor_y), "combined envelope underground fixture resolves a supported mine floor")
		if is_finite(underground_floor_y):
			var underground_position := Vector3(73.0, underground_floor_y, 73.0)
			var underground_loaded: bool = bool(mine_director.call("sync_to_world_position", underground_position, now + 2))
			_expect(underground_loaded, "combined envelope fixture loads underground layer 2 outside the surface window")
			if underground_loaded:
				var saved_underground_chunk_ids: Array = Array(mine_director.call("get_managed_chunk_ids"))
				saved_underground_chunk_ids.sort()
				_expect(not saved_underground_chunk_ids.is_empty(), "combined envelope fixture captures the managed underground chunk window")
				restored_world.set("_surface_return_position", baseline_position)
				restored_world.set("_is_underground", true)
				restored_world.set("_mine_layer_index", underground_layer)
				restored_world.set("_last_mine_grid", mine_director.call("get_grid_coordinate", underground_position))
				restored_world.set("_last_mine_layer_index", underground_layer)
				restored_world.set("_mine_chunk_ready", restored_controller.call("is_chunk_loaded", "underground/mine_0_0"))
				restored_player.global_position = underground_position
				restored_player.velocity = Vector3(0.25, 0.0, 0.0)
				var underground_envelope: Dictionary = restored_world.call("serialize_world_envelope")
				_expect(str(underground_envelope.get("active_location", "")) == "underground", "combined envelope records an active underground location")
				_expect(str(underground_envelope.get("surface_world", {}).get("location_layer", "")) == "underground", "underground envelope preserves the SurfaceWorld layer contract")
				_expect(int(underground_envelope.get("surface_world", {}).get("mine_depth", -1)) == underground_layer, "underground envelope records the exact mine depth")
				_expect(underground_envelope.get("backrooms_session", {}).get("active", false) == false and underground_envelope.get("backrooms_runtime", {}).is_empty(), "underground envelope contains no active Backrooms Session or maze Runtime")
				_expect(not underground_envelope.is_empty(), "active underground state serializes through the combined envelope")
				if not underground_envelope.is_empty():
					var other_underground_position := Vector3(121.0, underground_floor_y, 121.0)
					var moved_to_other_underground_window: bool = bool(mine_director.call("sync_to_world_position", other_underground_position, now + 3))
					_expect(moved_to_other_underground_window, "underground envelope restore fixture moves to a different mine window")
					if moved_to_other_underground_window:
						restored_world.set("_last_mine_grid", mine_director.call("get_grid_coordinate", other_underground_position))
						restored_world.set("_last_mine_layer_index", underground_layer)
						restored_world.set("_mine_chunk_ready", restored_controller.call("is_chunk_loaded", "underground/mine_0_0"))
						restored_player.global_position = other_underground_position
						restored_player.velocity = Vector3.ZERO
						var underground_restored: bool = bool(restored_world.call("restore_world_envelope", underground_envelope, now + 4))
						_expect(underground_restored, "combined envelope restores an underground visit after the mine window moved")
						if underground_restored:
							_expect(bool(restored_world.get("_is_underground")) and not bool(restored_world.get("_is_in_backrooms")), "underground restore selects the correct active world mode")
							_expect(restored_player.global_position.is_equal_approx(underground_position), "underground restore returns the player to the exact saved coordinates")
							_expect(int(restored_world.get("_mine_layer_index")) == underground_layer and mine_director.call("get_layer_index", restored_player.global_position) == underground_layer, "underground restore preserves the exact mine layer")
							var restored_surface_return: Vector3 = restored_world.get("_surface_return_position")
							_expect(restored_surface_return.is_equal_approx(baseline_position), "underground restore preserves the exact surface return anchor")
							_expect(_loaded_surface_ids(restored_world) == baseline_surface_ids, "underground restore leaves the exact surface chunk window intact")
							var restored_underground_chunk_ids: Array = Array(mine_director.call("get_managed_chunk_ids"))
							restored_underground_chunk_ids.sort()
							_expect(restored_underground_chunk_ids == saved_underground_chunk_ids, "underground restore reconstructs the exact saved mine chunk window")
					var surface_after_underground: bool = bool(restored_world.call("restore_world_envelope", surface_envelope, now + 5))
					_expect(surface_after_underground, "combined envelope returns the same world from underground to its saved surface state")
					if surface_after_underground:
						_expect(not bool(restored_world.get("_is_underground")), "surface envelope restore clears the underground mode")
						_expect(restored_player.global_position.is_equal_approx(baseline_position), "surface envelope restore returns to the exact saved surface position")
						_expect(_loaded_surface_ids(restored_world) == baseline_surface_ids, "surface envelope restore retains the original surface chunk window")
						_expect(int(restored_world.get("_mine_layer_index")) == 0, "surface envelope restore resets the mine layer index")
						var restored_surface_return: Vector3 = restored_world.get("_surface_return_position")
						_expect(restored_surface_return.is_equal_approx(baseline_surface_return), "surface envelope restore preserves the original pre-underground return anchor")
						var returned_surface_envelope: Dictionary = restored_world.call("serialize_world_envelope")
						_expect(str(returned_surface_envelope.get("active_location", "")) == "surface", "combined envelope reports the restored surface as the active location")
						_expect(not bool(restored_session.call("is_active")) and not bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")), "surface envelope restore leaves no active Backrooms Session or maze Runtime")
						# The successful restore legitimately advances full-vein regeneration clocks; use the
						# post-round-trip state as the baseline for the following atomic rollback probes.
						baseline_surface = restored_world.call("serialize_stream_state")
	var window_target: Dictionary = restored_world.call("_resolve_camera_interaction_target", root)
	_expect(window_target.is_empty(), "non-3D Window candidates are ignored before typed Node3D membership checks")
	var invalid_envelope: Dictionary = envelope.duplicate(true)
	invalid_envelope["backrooms_session"]["surface_world_seed"] = int(invalid_envelope["backrooms_session"].get("surface_world_seed", 0)) + 1
	_expect(not bool(restored_world.call("restore_world_envelope", invalid_envelope, now + 6)), "combined restore rejects a Session bound to a different surface seed")
	_expect(restored_world.call("serialize_stream_state") == baseline_surface, "preflight rejection leaves the complete fresh SurfaceWorld payload unchanged")
	_expect(restored_session.call("to_save_dict") == baseline_session and not bool(restored_session.call("is_active")), "preflight rejection leaves the Session inactive and unchanged")
	_expect(not bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")), "preflight rejection leaves the maze runtime empty")

	restored_runtime.call("set_cell_builder_for_testing", Callable(self, "_reject_maze_cell_builder"))
	var failed_restore: bool = bool(restored_world.call("restore_world_envelope", envelope, now + 7))
	var failed_report: Dictionary = restored_world.call("get_last_world_envelope_restore_report")
	_expect(not failed_restore and str(failed_report.get("phase", "")) == "runtime_restore", "injected maze-cell staging failure rejects the combined restore at the runtime phase")
	_expect(bool(failed_report.get("rollback_complete", false)), "runtime staging failure reports a complete combined-world rollback")
	restored_runtime.call("clear_cell_builder_for_testing")
	_expect(not bool(restored_world.get("_is_in_backrooms")), "failed combined restore leaves the target in SurfaceWorld mode")
	var after_failed_surface: Dictionary = restored_world.call("serialize_stream_state")
	if after_failed_surface != baseline_surface:
		_log_dictionary_differences(baseline_surface, after_failed_surface)
	_expect(after_failed_surface == baseline_surface, "failed combined restore restores the exact pre-attempt SurfaceWorld save payload")
	_expect(_loaded_surface_ids(restored_world) == baseline_surface_ids, "failed combined restore restores the exact pre-attempt surface chunk window")
	_expect(restored_player.global_position.is_equal_approx(baseline_position), "failed combined restore restores the original player position")
	_expect(restored_session.call("to_save_dict") == baseline_session and not bool(restored_session.call("is_active")), "failed combined restore returns LocationSession to its exact inactive snapshot")
	_expect(not bool(restored_runtime.call("is_prepared")) and not bool(restored_runtime.call("is_active")) and int(restored_runtime.call("get_loaded_cell_count")) == 0, "failed combined restore leaves no staged maze cells")
	_expect(str(restored_manager.call("get_state_name")) == "IDLE", "failed combined restore returns the transition manager to IDLE")

	var restored: bool = bool(restored_world.call("restore_world_envelope", envelope, now + 8))
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
		_expect(bool(restored_lighting_controller.call("is_active")), "combined world restore reapplies the saved Session's Backrooms lighting profile")
		_expect(str(restored_lighting_controller.call("get_current_level")) == str(saved_session.get("level_id", "")), "restored lighting level matches the saved LocationSession")
		_expect(restored_environment.environment != original_restored_environment and is_zero_approx(restored_sun.light_energy), "combined restore restores the dark Backrooms Environment and disables the surface sun")
		_expect(restored_player.global_position.is_equal_approx(saved_backrooms_position), "restored player returns to the exact saved Backrooms position")
		_expect(restored_session.call("to_save_dict") == saved_session, "restored LocationSession exactly matches the saved Session")
		_expect(restored_runtime.call("to_save_dict") == envelope.get("backrooms_runtime", {}), "restored maze runtime exactly matches the saved stream state")
		_expect(int(restored_runtime.call("to_save_dict").get("schema_version", -1)) == 4, "restored runtime keeps the entity ownership maze stream schema")
		_expect(int(restored_runtime.call("to_save_dict").get("entity_runtime_state_version", -1)) == 2, "restored runtime keeps the entity-state codec v2 version")
		_expect(int(restored_runtime.call("to_save_dict").get("entity_spawn_algorithm_version", -1)) == 1, "restored runtime keeps the saved entity-spawn algorithm version")
		_expect(bool(restored_runtime.call("is_prepared")) and bool(restored_runtime.call("is_active")) and restored_runtime.visible, "restored maze runtime is prepared, active and visible")
		_expect(_loaded_surface_ids(restored_world) == envelope.get("surface_chunk_ids", []), "restored world retains the exact saved surface chunk window")
		for chunk_id_value in envelope.get("surface_chunk_ids", []):
			var chunk_id: String = str(chunk_id_value)
			var surface_root: Node3D = restored_controller.call("get_chunk_root", chunk_id) as Node3D
			_expect(surface_root != null and not surface_root.visible, "surface chunk %s remains hidden while Backrooms is active" % chunk_id)
		var returned: Dictionary = restored_world.call("return_from_backrooms")
		_expect(bool(returned.get("ok", false)), "restored Backrooms Session can return to SurfaceWorld normally")
		_expect(not bool(restored_lighting_controller.call("is_active")), "successful return clears the Backrooms lighting transaction")
		_expect(restored_environment.environment == original_restored_environment and is_equal_approx(restored_sun.light_energy, 1.4), "successful return restores the exact SurfaceWorld Environment and sun energy")
		_expect(not bool(restored_world.get("_is_in_backrooms")), "successful restored return clears Backrooms world mode")
		var saved_return: Array = saved_session.get("surface_return_position", [])
		var expected_return := Vector3(float(saved_return[0]), float(saved_return[1]), float(saved_return[2]))
		_expect(restored_player.global_position.is_equal_approx(expected_return), "restored return reaches the exact saved surface return position")
		_expect(not bool(restored_session.call("is_active")) and not bool(restored_runtime.call("is_prepared")), "successful return clears Session and retires the restored maze runtime")
		for chunk_id_value in envelope.get("surface_chunk_ids", []):
			var chunk_id: String = str(chunk_id_value)
			var surface_root: Node3D = restored_controller.call("get_chunk_root", chunk_id) as Node3D
			var expected_visible: bool = bool(envelope.get("surface_chunk_visibility", {}).get(chunk_id, true))
			_expect(surface_root != null and surface_root.visible == expected_visible, "return restores original visibility for surface chunk %s" % chunk_id)

	var source_return: Dictionary = source_world.call("return_from_backrooms")
	_expect(bool(source_return.get("ok", false)), "source world remains independently returnable after the combined save round-trip")
	_expect(not bool(source_lighting_controller.call("is_active")), "source return clears its Backrooms lighting transaction")
	_expect(source_environment.environment == original_source_environment and is_equal_approx(source_sun.light_energy, 1.4), "source return restores the exact original SurfaceWorld Environment and sun energy")
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


func _log_dictionary_differences(expected: Dictionary, actual: Dictionary) -> void:
	for key_value in expected.keys():
		var key: Variant = key_value
		if expected.get(key) != actual.get(key):
			print("ROLLBACK DIFF %s expected=%s actual=%s" % [str(key), str(expected.get(key)).substr(0, 500), str(actual.get(key)).substr(0, 500)])
	for key_value in actual.keys():
		if not expected.has(key_value):
			print("ROLLBACK EXTRA %s actual=%s" % [str(key_value), str(actual.get(key_value)).substr(0, 500)])


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
