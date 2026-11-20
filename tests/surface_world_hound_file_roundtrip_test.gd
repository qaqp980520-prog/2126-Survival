extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SAVE_PATH: String = "user://run344_surfaceworld_hound_combined_envelope.json"
const WORLD_SEED: int = 20261118
const CELL_SIZE: float = 8.0
const ENTITY_SAFE_MARGIN: float = 0.65

var failures: Array[String] = []
var source_world: Node3D
var restored_world: Node3D
var watchdog: Timer


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_save_paths()
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 180.0
	root.add_child(watchdog)
	watchdog.timeout.connect(_on_timeout)
	watchdog.start()

	source_world = WorldScene.instantiate() as Node3D
	_expect(source_world != null, "production SurfaceWorld scene instantiates for the combined Hound disk round-trip")
	if source_world == null:
		_finish(1)
		return
	source_world.set("world_seed", WORLD_SEED)
	root.add_child(source_world)
	await process_frame

	var player: CharacterBody3D = source_world.get("player") as CharacterBody3D
	var director: RefCounted = source_world.get("backrooms_portal_director") as RefCounted
	_expect(player != null and director != null, "production player and portal director are available")
	if player == null or director == null:
		_finish(1)
		return
	_expect(int(source_world.get("world_seed")) == WORLD_SEED, "production SurfaceWorld retains the deterministic Level 2 fixture seed")

	director.set("next_spawn_in", 0.01)
	source_world.call("_process", 0.02)
	var portal: Area3D = source_world.get("backrooms_portal_visual") as Area3D
	_expect(portal != null, "production portal director creates a live portal for the Hound persistence fixture")
	if portal == null:
		_finish(1)
		return
	var portal_id: int = int(portal.get("portal_id"))

	# Pin only the portal destination RNG state, not the world or maze seed. This
	# makes the production handoff select Level 2 deterministically for the test.
	var level_two_rng_state: String = _find_rng_state_for_level_two()
	_expect(not level_two_rng_state.is_empty(), "a canonical RNG state is available for a deterministic Level 2 portal preview")
	if level_two_rng_state.is_empty():
		_finish(1)
		return
	var portal_save: Dictionary = director.call("to_save_dict")
	portal_save["rng_state"] = level_two_rng_state
	_expect(bool(director.call("load_save_dict", portal_save)), "production portal director accepts the deterministic Level 2 RNG fixture")
	var preview: Dictionary = director.call("preview_portal_entry", portal_id)
	_expect(bool(preview.get("ok", false)) and str(preview.get("destination_level", "")) == "Level 2", "production portal preview selects Level 2 without consuming the portal")
	if not bool(preview.get("ok", false)) or str(preview.get("destination_level", "")) != "Level 2":
		_finish(1)
		return
	var portal_position_value: Variant = preview.get("position", null)
	_expect(portal_position_value is Vector2, "production portal exposes a valid position for the player handoff")
	if not (portal_position_value is Vector2):
		_finish(1)
		return
	var portal_position: Vector2 = portal_position_value
	var approach_position := Vector3(portal_position.x, 2.0, portal_position.y + 2.0)
	_expect(
		bool(source_world.call("debug_move_player_to", approach_position, int(Time.get_unix_time_from_system()))),
		"production player streams to the active portal's owning surface window"
	)
	await process_frame
	portal = source_world.get("backrooms_portal_visual") as Area3D
	_expect(portal != null and bool(portal.call("interact", player)), "production portal accepts the nearby player")
	if portal == null:
		_finish(1)
		return
	var entry: Dictionary = source_world.call("enter_backrooms_from_portal", portal_id)
	_expect(bool(entry.get("ok", false)) and str(entry.get("destination_level", "")) == "Level 2", "production SurfaceWorld completes a real Level 2 Backrooms handoff")
	if not bool(entry.get("ok", false)):
		_finish(1)
		return

	var runtime: Node3D = source_world.get("backrooms_maze_runtime") as Node3D
	var transition_manager: RefCounted = source_world.get("backrooms_transition_manager") as RefCounted
	_expect(runtime != null and transition_manager != null, "active production Backrooms runtime and transition manager are available")
	if runtime == null or transition_manager == null:
		_finish(1)
		return
	var session: RefCounted = transition_manager.call("get_session") as RefCounted
	_expect(session != null and str(session.call("get_current_level")) == "Level 2", "active production LocationSession records Level 2")

	var candidate: Dictionary = _find_hound_transfer_candidate(runtime)
	_expect(not candidate.is_empty(), "active production Level 2 window contains a Hound with a loaded adjacent ownership hop")
	if candidate.is_empty():
		_finish(1)
		return
	var entity_root: CharacterBody3D = candidate.get("entity_root") as CharacterBody3D
	var source_root: Node3D = candidate.get("source_root") as Node3D
	var source_cell: Vector2i = candidate.get("source_cell", Vector2i.ZERO)
	var target_cell: Vector2i = candidate.get("target_cell", Vector2i.ZERO)
	var direction: Vector2i = candidate.get("direction", Vector2i.ZERO)
	var spawn_cell_key: String = str(candidate.get("spawn_cell_key", ""))
	var entity_id: String = str(candidate.get("entity_id", ""))
	var route: Dictionary = candidate.get("route", {})
	var source_key: String = "%d,%d" % [source_cell.x, source_cell.y]
	var target_key: String = "%d,%d" % [target_cell.x, target_cell.y]
	var target_root: Node3D = runtime.call("get_cell_root", target_key) as Node3D
	_expect(entity_root != null and source_root != null and target_root != null and entity_id == "hound", "selected Hound has live source and target cell roots")
	_expect(spawn_cell_key == source_key, "initial Hound owner cell matches its immutable spawn cell")
	if entity_root == null or source_root == null or target_root == null or entity_id != "hound" or spawn_cell_key != source_key:
		_finish(1)
		return
	var initial_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(
		str(initial_owner.get("owner_cell_key", "")) == source_key
		and int(initial_owner.get("owner_revision", -1)) == 0,
		"initial Hound ownership ledger starts at its spawn cell with revision zero"
	)
	var source_navigation_agent: NavigationAgent3D = entity_root.get_node_or_null("NavigationAnchor/NavigationAgent") as NavigationAgent3D
	_expect(source_navigation_agent != null, "source Hound has a live cell-local NavigationAgent3D")
	if source_navigation_agent == null:
		_finish(1)
		return
	var source_navigation_agent_id: int = source_navigation_agent.get_instance_id()

	# Exercise the same bounded edge transfer used by the runtime integration test.
	var safe_extent: float = CELL_SIZE * 0.5 - ENTITY_SAFE_MARGIN
	var edge_position: Vector3 = entity_root.position
	if direction.x != 0:
		edge_position.x = float(direction.x) * safe_extent
	else:
		edge_position.z = float(direction.y) * safe_extent
	entity_root.position = edge_position
	await physics_frame
	var transfer: Dictionary = runtime.call("transfer_entity_to_next_cell", spawn_cell_key, entity_id, route)
	_expect(bool(transfer.get("ok", false)), "production Hound commits an adjacent A-to-B cell ownership transfer")
	if not bool(transfer.get("ok", false)):
		_finish(1)
		return
	var committed_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(
		str(committed_owner.get("owner_cell_key", "")) == target_key
		and int(committed_owner.get("owner_revision", -1)) == 1,
		"production ownership ledger records the target cell and revision one"
	)
	_expect(entity_root.get_parent() == target_root, "transferred Hound is attached to the target cell before disk save")

	var first_save_ok: bool = bool(source_world.call("save_game", SAVE_PATH))
	if not first_save_ok:
		print("DEBUG: combined Hound save report = ", source_world.call("get_last_world_file_report"), " envelope = ", source_world.call("get_last_world_envelope_restore_report"))
	_expect(first_save_ok, "production SurfaceWorld.save_game writes the combined SurfaceWorld and Hound envelope to disk")
	if not first_save_ok:
		_finish(1)
		return
	var first_payload: Dictionary = _read_dictionary(SAVE_PATH)
	_expect(str(first_payload.get("active_location", "")) == "backrooms", "combined disk envelope records the active Backrooms location")
	var first_runtime: Dictionary = first_payload.get("backrooms_runtime", {})
	var first_owner_record: Dictionary = _find_owner_record(first_runtime, spawn_cell_key, entity_id)
	_expect(
		str(first_owner_record.get("owner_cell_key", "")) == target_key
		and int(first_owner_record.get("owner_revision", -1)) == 1,
		"combined disk envelope contains the migrated Hound owner record"
	)
	_expect(
		_has_runtime_state(first_runtime, spawn_cell_key, entity_id),
		"combined disk envelope contains the same Hound's immutable spawn identity and runtime state"
	)
	var first_session: Dictionary = first_payload.get("backrooms_session", {})
	_expect(bool(first_session.get("active", false)), "combined disk envelope preserves the active Backrooms Session")
	var saved_player_position: Array = first_payload.get("backrooms_player", {}).get("position", [])
	_expect(saved_player_position.size() == 3, "combined disk envelope stores the Backrooms player position")

	# A second production save rotates the known-good combined Hound envelope to
	# .bak. Corrupt only the primary so recovery must rebuild the full SurfaceWorld.
	var second_save_ok: bool = bool(source_world.call("save_game", SAVE_PATH))
	_expect(second_save_ok, "second production save rotates the Hound envelope into the backup")
	if not second_save_ok:
		_finish(1)
		return
	var backup_payload: Dictionary = _read_dictionary(SAVE_PATH + ".bak")
	var backup_owner_record: Dictionary = _find_owner_record(backup_payload.get("backrooms_runtime", {}), spawn_cell_key, entity_id)
	_expect(
		str(backup_owner_record.get("owner_cell_key", "")) == target_key
		and int(backup_owner_record.get("owner_revision", -1)) == 1,
		"rotated .bak contains the same Hound owner cell and revision"
	)
	_expect(_write_text(SAVE_PATH, "{malformed combined Hound primary"), "test corrupts only the combined primary before fresh-world recovery")

	restored_world = WorldScene.instantiate() as Node3D
	_expect(restored_world != null, "a fresh production SurfaceWorld instance is available for combined Hound recovery")
	if restored_world == null:
		_finish(1)
		return
	root.add_child(restored_world)
	await process_frame
	var loaded: bool = bool(restored_world.call("load_game", SAVE_PATH))
	if not loaded:
		print("DEBUG: combined Hound recovery file report = ", restored_world.call("get_last_world_file_report"), " envelope = ", restored_world.call("get_last_world_envelope_restore_report"), " surface = ", restored_world.call("get_last_restore_report"))
	_expect(loaded, "fresh production SurfaceWorld restores the combined Hound envelope from .bak")
	if not loaded:
		_finish(1)
		return

	var file_report: Dictionary = restored_world.call("get_last_world_file_report")
	var file_details: Dictionary = file_report.get("details", {})
	_expect(str(file_report.get("phase", "")) == "backup_restored", "combined Hound recovery reports the backup restore phase")
	_expect(str(file_details.get("source", "")) == SAVE_PATH + ".bak", "combined Hound recovery identifies the exact backup source")
	_expect(bool(file_details.get("primary_repaired", false)), "combined Hound recovery repairs the primary after preserving corruption")
	_expect(FileAccess.file_exists(SAVE_PATH + ".corrupt"), "malformed combined Hound primary is preserved as a diagnostic file")
	var repaired_payload: Dictionary = _read_dictionary(SAVE_PATH)
	_expect(_save_values_equal(repaired_payload, backup_payload), "repaired primary exactly matches the validated combined Hound backup")

	_expect(bool(restored_world.get("_is_in_backrooms")), "fresh-world recovery activates Backrooms only after the combined runtime is reconstructed")
	_expect(int(restored_world.get("world_seed")) == WORLD_SEED, "combined backup recovery restores the original SurfaceWorld seed")
	var restored_player: CharacterBody3D = restored_world.get("player") as CharacterBody3D
	var restored_manager: RefCounted = restored_world.get("backrooms_transition_manager") as RefCounted
	var restored_runtime: Node3D = restored_world.get("backrooms_maze_runtime") as Node3D
	_expect(restored_player != null and restored_manager != null and restored_runtime != null, "recovered world exposes its player, transition manager and maze runtime")
	if restored_player == null or restored_manager == null or restored_runtime == null:
		_finish(1)
		return
	if saved_player_position.size() == 3:
		var expected_player_position := Vector3(float(saved_player_position[0]), float(saved_player_position[1]), float(saved_player_position[2]))
		_expect(restored_player.global_position.is_equal_approx(expected_player_position), "combined backup restores the exact saved Backrooms player position")
	var restored_session: RefCounted = restored_manager.call("get_session") as RefCounted
	_expect(restored_session != null and str(restored_session.call("get_current_level")) == "Level 2", "combined backup restores the Level 2 LocationSession")

	var restored_owner: Dictionary = restored_runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(
		str(restored_owner.get("owner_cell_key", "")) == target_key
		and int(restored_owner.get("owner_revision", -1)) == 1,
		"combined backup restores the Hound immutable spawn identity, mutable owner cell and revision"
	)
	var restored_identity: Dictionary = _find_entity(restored_runtime, spawn_cell_key, entity_id)
	_expect(int(restored_identity.get("count", 0)) == 1, "combined backup reconstructs exactly one Hound for the immutable spawn identity")
	var restored_entity: CharacterBody3D = restored_identity.get("entity_root") as CharacterBody3D
	var restored_owner_root: Node3D = restored_runtime.call("get_cell_root", target_key) as Node3D
	_expect(
		restored_entity != null and restored_owner_root != null and restored_entity.get_parent() == restored_owner_root,
		"combined backup attaches the single restored Hound under the committed owner cell"
	)
	if restored_entity != null:
		_expect(restored_entity.get_meta("spawn_cell", null) == source_cell, "combined backup preserves the immutable Hound spawn-cell identity")
		_expect(str(restored_entity.get_meta("backrooms_owner_cell_key", "")) == target_key, "combined backup restores Hound owner-cell metadata")
		_expect(int(restored_entity.get_meta("backrooms_owner_revision", -1)) == 1, "combined backup restores Hound owner-revision metadata")
		var restored_agent: NavigationAgent3D = restored_entity.get_node_or_null("NavigationAnchor/NavigationAgent") as NavigationAgent3D
		_expect(restored_agent != null, "combined backup creates a fresh NavigationAgent3D through the current cell factory")
		if restored_agent != null:
			_expect(restored_agent.get_instance_id() != source_navigation_agent_id, "restored Hound navigation agent is a new runtime object, not serialized scene state")
			_expect(not restored_agent.avoidance_enabled, "restored NavigationAgent3D preserves the bounded non-avoidance policy")
			_expect(absf(restored_agent.path_desired_distance - 0.2) <= 0.0001, "restored NavigationAgent3D preserves the current waypoint tolerance")

	_finish(0)


func _find_rng_state_for_level_two() -> String:
	for seed_value in range(1, 4096):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var state_before_draw: int = rng.state
		if rng.randi_range(0, 5) == 2:
			return str(state_before_draw)
	return ""


func _find_hound_transfer_candidate(runtime: Node3D) -> Dictionary:
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0)
	]
	for cell_key_value in runtime.call("get_loaded_cell_keys"):
		var cell_key: String = str(cell_key_value)
		var cell_root: Node3D = runtime.call("get_cell_root", cell_key) as Node3D
		if cell_root == null:
			continue
		var cell_value: Variant = cell_root.get_meta("backrooms_cell", null)
		if not (cell_value is Vector2i):
			continue
		var cell: Vector2i = cell_value
		for child in cell_root.get_children():
			if not (child is CharacterBody3D):
				continue
			var entity_id: String = str(child.get_meta("backrooms_entity_id", ""))
			if entity_id != "hound":
				continue
			var spawn_value: Variant = child.get_meta("spawn_cell", null)
			if not (spawn_value is Vector2i):
				continue
			var spawn_cell: Vector2i = spawn_value
			var spawn_key: String = "%d,%d" % [spawn_cell.x, spawn_cell.y]
			var owner_record: Dictionary = runtime.call("get_entity_owner_record", spawn_key, entity_id)
			if str(owner_record.get("owner_cell_key", "")) != cell_key:
				continue
			for direction in directions:
				var target_cell: Vector2i = cell + direction
				var route: Dictionary = runtime.call("plan_route_between_loaded_cells", cell, target_cell)
				var cell_path_value: Variant = route.get("cell_path", null)
				if (
					bool(route.get("ok", false))
					and cell_path_value is Array
					and cell_path_value.size() == 2
				):
					var target_key: String = "%d,%d" % [target_cell.x, target_cell.y]
					if runtime.call("get_cell_root", target_key) == null:
						continue
					return {
						"entity_root": child,
						"source_root": cell_root,
						"spawn_cell_key": spawn_key,
						"entity_id": entity_id,
						"source_cell": cell,
						"target_cell": target_cell,
						"direction": direction,
						"route": route
					}
	return {}


func _find_owner_record(runtime_payload: Dictionary, spawn_cell_key: String, entity_id: String) -> Dictionary:
	var ledger_value: Variant = runtime_payload.get("entity_ownership_ledger", {})
	if not (ledger_value is Dictionary):
		return {}
	for record_value in ledger_value.get("records", []):
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if str(record.get("spawn_cell_key", "")) == spawn_cell_key and str(record.get("entity_id", "")) == entity_id:
			return record.duplicate(true)
	return {}


func _has_runtime_state(runtime_payload: Dictionary, spawn_cell_key: String, entity_id: String) -> bool:
	for record_value in runtime_payload.get("entity_runtime_states", []):
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if str(record.get("spawn_cell_key", "")) == spawn_cell_key and str(record.get("entity_id", "")) == entity_id:
			return true
	return false


func _find_entity(runtime: Node3D, spawn_cell_key: String, entity_id: String) -> Dictionary:
	var matches: Array[CharacterBody3D] = []
	for cell_key_value in runtime.call("get_loaded_cell_keys"):
		var cell_root: Node3D = runtime.call("get_cell_root", str(cell_key_value)) as Node3D
		if cell_root == null:
			continue
		for child in cell_root.get_children():
			if not (child is CharacterBody3D) or str(child.get_meta("backrooms_entity_id", "")) != entity_id:
				continue
			var spawn_value: Variant = child.get_meta("spawn_cell", null)
			if not (spawn_value is Vector2i):
				continue
			var spawn_cell: Vector2i = spawn_value
			if ("%d,%d" % [spawn_cell.x, spawn_cell.y]) == spawn_cell_key:
				matches.append(child as CharacterBody3D)
	return {
		"count": matches.size(),
		"entity_root": matches[0] if matches.size() == 1 else null
	}


static func _save_values_equal(left: Variant, right: Variant) -> bool:
	if left is Dictionary:
		if not (right is Dictionary) or left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _save_values_equal(left[key], right[key]):
				return false
		return true
	if left is Array:
		if not (right is Array) or left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _save_values_equal(left[index], right[index]):
				return false
		return true
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	return left == right


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not (parser.data is Dictionary):
		return {}
	return parser.data


func _write_text(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK


func _cleanup_save_paths() -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		var path: String = SAVE_PATH + suffix
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
			DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAIL: " + message)


func _on_timeout() -> void:
	push_error("SurfaceWorld Hound durable envelope round-trip timed out.")
	_finish(2)


func _finish(exit_code: int) -> void:
	if is_instance_valid(watchdog):
		watchdog.stop()
		watchdog.queue_free()
	if is_instance_valid(restored_world):
		restored_world.queue_free()
	if is_instance_valid(source_world):
		source_world.queue_free()
	await process_frame
	_cleanup_save_paths()
	if exit_code == 0 and failures.is_empty():
		print("SurfaceWorld Hound durable envelope round-trip tests passed.")
		quit(0)
	else:
		push_error("SurfaceWorld Hound durable envelope round-trip failures: %d" % failures.size())
		quit(1)
