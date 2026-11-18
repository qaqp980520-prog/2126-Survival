extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")
const BrainScript = preload("res://systems/BackroomsEntityBrain.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime: Variant = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	_expect(not bool(runtime.call("is_prepared")), "runtime starts without a prepared destination")
	_expect(not bool(runtime.call("is_active")) and not runtime.visible, "runtime starts hidden and inactive")
	var invalid_prepare: Dictionary = runtime.call("prepare_destination", "Level 1", 20261113, Vector3(0.0, NAN, 0.0), 8.0, 1)
	_expect(not bool(invalid_prepare.get("ok", false)), "runtime rejects a non-finite entry position before staging")

	var prepared: Dictionary = runtime.call("prepare_destination", "Level 1", 20261113, Vector3.ZERO, 8.0, 1)
	_expect(bool(prepared.get("ok", false)), "runtime prepares a deterministic Level 1 destination")
	_expect(int(runtime.call("get_loaded_cell_count")) == 9, "initial radius-one window builds nine cell roots")
	_expect(not bool(runtime.call("is_active")) and not runtime.visible, "prepared destination remains hidden and collision-inactive")
	var origin_root: Node3D = runtime.call("get_cell_root", "0,0") as Node3D
	_expect(origin_root != null, "initial window owns the origin cell root")
	if origin_root != null:
		_expect(origin_root.has_meta("backrooms_cell_key"), "cell root exposes its stable key as metadata")
		_expect(origin_root.get_meta("backrooms_level_id") == "Level 1", "cell root preserves its level identity")
		_expect(origin_root.get_meta("backrooms_layout_algorithm_version") == 1, "cell root records the topology algorithm version")
		_expect(origin_root.get_node_or_null("WorldCollision") == null, "headless metadata-only builder creates no physics or renderer nodes")

	var original_keys: Array = runtime.call("get_loaded_cell_keys")
	var original_origin_id: int = origin_root.get_instance_id() if origin_root != null else 0
	var invalid_shift: Dictionary = runtime.call("sync_to_world_position", Vector3(0.0, NAN, 0.0))
	_expect(not bool(invalid_shift.get("ok", false)), "runtime rejects non-finite movement positions")
	_expect(runtime.call("get_loaded_cell_keys") == original_keys, "invalid movement leaves the committed window unchanged")
	runtime.call("set_cell_builder_for_testing", Callable(self, "_fail_cell_builder"))
	var failed_shift: Dictionary = runtime.call("sync_to_world_position", Vector3(16.0, 0.0, 0.0))
	_expect(not bool(failed_shift.get("ok", false)), "injected cell-builder failure rejects the entire window shift")
	_expect(runtime.call("get_loaded_cell_keys") == original_keys, "failed staging preserves the exact committed cell-key set")
	var origin_after_failure: Node3D = runtime.call("get_cell_root", "0,0") as Node3D
	_expect(origin_after_failure != null and origin_after_failure.get_instance_id() == original_origin_id, "failed staging preserves the existing origin root instance")
	var failed_prepare: Dictionary = runtime.call("prepare_destination", "Level 2", 20261114, Vector3.ZERO, 8.0, 1)
	_expect(not bool(failed_prepare.get("ok", false)), "failed candidate destination staging is rejected")
	_expect(runtime.call("get_loaded_cell_keys") == original_keys, "failed destination preparation preserves the previous prepared window")
	_expect(runtime.call("get_cell_root", "0,0").get_instance_id() == original_origin_id, "failed destination preparation preserves existing cell root instances")
	runtime.call("clear_cell_builder_for_testing")

	var shifted: Dictionary = runtime.call("sync_to_world_position", Vector3(8.0, 0.0, 0.0))
	_expect(bool(shifted.get("ok", false)), "successful movement commits the next stream window")
	_expect(int(shifted.get("load_count", -1)) == 3 and int(shifted.get("keep_count", -1)) == 6 and int(shifted.get("unload_count", -1)) == 3, "one-cell movement stages three roots, keeps six and retires three")
	_expect(int(runtime.call("get_loaded_cell_count")) == 9, "committed stream window remains exactly nine cells")
	_expect(runtime.call("get_cell_root", "0,0") == origin_root, "overlapping cells retain their existing root instances")
	_expect(runtime.call("get_cell_root", "-1,0") == null, "cells outside the new window are retired")
	_expect(runtime.call("get_cell_root", "2,0") != null, "newly required edge cells are attached after commit")

	var saved: Dictionary = runtime.call("to_save_dict")
	_expect(int(saved.get("schema_version", -1)) == 3, "runtime writes the entity-runtime persistence schema")
	_expect(int(saved.get("entity_runtime_state_version", -1)) == 1, "runtime save declares the entity-state codec version")
	_expect(saved.get("entity_runtime_states", null) is Array, "runtime save includes a validated entity-state array")
	_expect(int(saved.get("layout_algorithm_version", -1)) == 1, "runtime save is bound to the explicit maze algorithm version")
	_expect(int(saved.get("entity_spawn_algorithm_version", -1)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "runtime save persists the entity-spawn algorithm version")
	var restored: Variant = RuntimeScript.new()
	restored.force_metadata_only = true
	root.add_child(restored)
	_expect(bool(restored.call("load_save_dict", saved)), "runtime rebuilds a saved stream window from metadata")
	_expect(restored.call("get_loaded_cell_keys") == runtime.call("get_loaded_cell_keys"), "restored runtime reproduces the exact loaded cell-key set")
	var restored_origin: Node3D = restored.call("get_cell_root", "0,0") as Node3D
	_expect(restored_origin != null and restored_origin.get_meta("backrooms_open_edges") == origin_root.get_meta("backrooms_open_edges"), "restored origin reproduces the exact deterministic edge descriptor")
	_expect(not bool(restored.call("is_active")) and not restored.visible, "restored destination remains hidden until explicitly activated")
	_expect(int(restored_origin.get_meta("backrooms_entity_spawn_algorithm_version", 0)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "restored cell root preserves the spawn algorithm version")

	var legacy_payload: Dictionary = saved.duplicate(true)
	legacy_payload["schema_version"] = 1
	legacy_payload.erase("entity_spawn_algorithm_version")
	legacy_payload.erase("entity_runtime_state_version")
	legacy_payload.erase("entity_runtime_states")
	var legacy_restored: Variant = RuntimeScript.new()
	legacy_restored.force_metadata_only = true
	root.add_child(legacy_restored)
	_expect(bool(legacy_restored.call("load_save_dict", legacy_payload)), "legacy schema-one maze saves migrate using spawn algorithm version one")
	var migrated_save: Dictionary = legacy_restored.call("to_save_dict")
	_expect(int(migrated_save.get("schema_version", -1)) == 3 and int(migrated_save.get("entity_spawn_algorithm_version", -1)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "legacy restore writes the current schema-three spawn/runtime versions on the next save")
	legacy_restored.queue_free()
	var legacy_v2_payload: Dictionary = saved.duplicate(true)
	legacy_v2_payload["schema_version"] = 2
	legacy_v2_payload.erase("entity_runtime_state_version")
	legacy_v2_payload.erase("entity_runtime_states")
	var legacy_v2_restored: Variant = RuntimeScript.new()
	legacy_v2_restored.force_metadata_only = true
	root.add_child(legacy_v2_restored)
	_expect(bool(legacy_v2_restored.call("load_save_dict", legacy_v2_payload)), "legacy schema-two saves migrate without losing deterministic spawn compatibility")
	_expect(int(legacy_v2_restored.call("to_save_dict").get("schema_version", -1)) == 3, "legacy schema-two restore writes the new runtime-state schema")
	legacy_v2_restored.queue_free()

	var before_bad_restore: Array = restored.call("get_loaded_cell_keys")
	var invalid_save: Dictionary = saved.duplicate(true)
	invalid_save["layout_algorithm_version"] = 999
	_expect(not bool(restored.call("load_save_dict", invalid_save)), "unsupported layout algorithm version is rejected")
	_expect(restored.call("get_loaded_cell_keys") == before_bad_restore, "rejected restore leaves the existing runtime roots unchanged")
	var unsupported_spawn_save: Dictionary = saved.duplicate(true)
	unsupported_spawn_save["entity_spawn_algorithm_version"] = EntityDirectorScript.SPAWN_ALGORITHM_VERSION + 1
	_expect(not bool(restored.call("load_save_dict", unsupported_spawn_save)), "unsupported entity-spawn algorithm versions are rejected")
	_expect(restored.call("get_loaded_cell_keys") == before_bad_restore, "unsupported spawn version leaves the existing runtime roots unchanged")

	_expect(bool(restored.call("activate_destination")), "prepared runtime can be explicitly activated")
	_expect(bool(restored.call("is_active")) and restored.visible, "activation enables the prepared destination")
	_expect(not bool(restored.call("load_save_dict", saved)), "active runtime rejects an in-place restore")
	_expect(bool(restored.call("is_active")) and restored.call("get_loaded_cell_keys") == before_bad_restore, "rejected active restore preserves the live destination")
	_expect(bool(restored.call("deactivate_destination")), "active runtime can be deactivated")
	_expect(not bool(restored.call("is_prepared")) and int(restored.call("get_loaded_cell_count")) == 0, "deactivation retires all cell roots and clears runtime state")

	_production_entity_spawn_contract_is_valid()
	await _assert_entity_runtime_state_round_trip()

	restored.queue_free()
	runtime.queue_free()
	await process_frame
	if failures.is_empty():
		print("Backrooms maze cell runtime tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _assert_entity_runtime_state_round_trip() -> void:
	var runtime: Variant = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	var prepared: Dictionary = runtime.call("prepare_destination", "Level 2", 20261118, Vector3.ZERO, 8.0, 3)
	_expect(bool(prepared.get("ok", false)), "entity-state fixture prepares a deterministic Level 2 window")
	if not bool(prepared.get("ok", false)):
		runtime.queue_free()
		await process_frame
		return
	var selected_cell_key: String = ""
	var selected_entity_id: String = ""
	var selected_cell: Vector2i = Vector2i.ZERO
	var selected_root: CharacterBody3D = null
	var selected_cell_root: Node3D = null
	for cell_key_value in runtime.call("get_loaded_cell_keys"):
		var cell_key: String = str(cell_key_value)
		var cell_root: Node3D = runtime.call("get_cell_root", cell_key) as Node3D
		if cell_root == null:
			continue
		for child in cell_root.get_children():
			if child is CharacterBody3D:
				var entity_id: String = str(child.get_meta("backrooms_entity_id", ""))
				if entity_id in ["hound", "skin_stealer"]:
					selected_cell_key = cell_key
					selected_entity_id = entity_id
					selected_cell = cell_root.get_meta("backrooms_cell", Vector2i.ZERO)
					selected_root = child as CharacterBody3D
					selected_cell_root = cell_root
					break
		if selected_root != null:
			break
	_expect(selected_root != null and selected_cell_root != null, "Level 2 fixture contains at least one mobile hunter in its 7x7 loaded window")
	if selected_root == null or selected_cell_root == null:
		runtime.queue_free()
		await process_frame
		return
	var saved_local_position := Vector3(1.25, selected_root.position.y, -0.75)
	selected_root.position = saved_local_position
	var brain: Node = selected_root.get_node_or_null("AI")
	_expect(brain != null and brain.has_method("to_save_dict"), "mobile entity exposes its versioned behavior save contract")
	if brain == null:
		runtime.queue_free()
		await process_frame
		return
	var player_target: Vector3 = selected_cell_root.to_global(Vector3(2.0, selected_root.position.y, 2.0))
	var perception := {
		"distance_to_player": 3.0,
		"has_line_of_sight": true,
		"player_looking_at_entity": false,
		"noise_strength": 0.0,
		"player_position": player_target
	}
	brain.call("evaluate_perception", perception, 0.1)
	brain.call("evaluate_perception", perception, 0.75)
	selected_root.set_meta("backrooms_patrol_index", 3)
	var saved: Dictionary = runtime.call("to_save_dict")
	_expect(int(saved.get("schema_version", -1)) == 3, "entity runtime save uses schema three")
	var target_record: Dictionary = {}
	for record_value in saved.get("entity_runtime_states", []):
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("cell_key", "")) == selected_cell_key and str(record.get("entity_id", "")) == selected_entity_id:
				target_record = record
				break
	_expect(not target_record.is_empty(), "runtime save contains the moved hunter's stable cell/entity identity")
	_expect(target_record.get("position", []) == [saved_local_position.x, saved_local_position.y, saved_local_position.z], "runtime save captures the moved local position")
	_expect(int(target_record.get("patrol_index", -1)) == 3, "runtime save captures the patrol waypoint index")
	_expect(str(target_record.get("brain_state", {}).get("state", "")) == str(brain.call("get_behavior_snapshot").get("state", "")), "runtime save captures the current AI decision state")
	var shifted_position := Vector3(float(selected_cell.x + 4) * 8.0, 0.0, float(selected_cell.y) * 8.0)
	var shifted: Dictionary = runtime.call("sync_to_world_position", shifted_position)
	_expect(bool(shifted.get("ok", false)), "streaming away stages and commits while archiving the mobile entity")
	_expect(runtime.call("get_cell_root", selected_cell_key) == null, "the original entity cell is genuinely unloaded")
	var returned: Dictionary = runtime.call(
		"sync_to_world_position",
		Vector3(float(selected_cell.x) * 8.0, 0.0, float(selected_cell.y) * 8.0)
	)
	_expect(bool(returned.get("ok", false)), "returning to the original cell rebuilds it from the deterministic layout")
	var rebuilt_cell_root: Node3D = runtime.call("get_cell_root", selected_cell_key) as Node3D
	var rebuilt_entity: CharacterBody3D = null
	if rebuilt_cell_root != null:
		for child in rebuilt_cell_root.get_children():
			if child is CharacterBody3D and str(child.get_meta("backrooms_entity_id", "")) == selected_entity_id:
				rebuilt_entity = child as CharacterBody3D
				break
	_expect(rebuilt_entity != null, "the original mobile entity is recreated in its owning cell")
	if rebuilt_entity != null:
		_expect(rebuilt_entity.position.is_equal_approx(saved_local_position), "unloaded/reloaded cell restores the entity's moved position")
		_expect(int(rebuilt_entity.get_meta("backrooms_patrol_index", -1)) == 3, "unloaded/reloaded cell restores the patrol waypoint index")
		var rebuilt_brain: Node = rebuilt_entity.get_node_or_null("AI")
		var rebuilt_snapshot: Dictionary = rebuilt_brain.call("get_behavior_snapshot") if rebuilt_brain != null else {}
		_expect(
			str(rebuilt_snapshot.get("state", "")) == str(target_record.get("brain_state", {}).get("state", ""))
			and is_equal_approx(float(rebuilt_snapshot.get("state_elapsed_seconds", -1.0)), float(target_record.get("brain_state", {}).get("state_elapsed_seconds", -2.0))),
			"unloaded/reloaded cell restores the AI state and elapsed decision time"
		)
	var restored: Variant = RuntimeScript.new()
	restored.force_metadata_only = true
	root.add_child(restored)
	_expect(bool(restored.call("load_save_dict", saved)), "fresh runtime restores the saved entity-state cache")
	var restored_cell_root: Node3D = restored.call("get_cell_root", selected_cell_key) as Node3D
	var restored_entity: CharacterBody3D = null
	if restored_cell_root != null:
		for child in restored_cell_root.get_children():
			if child is CharacterBody3D and str(child.get_meta("backrooms_entity_id", "")) == selected_entity_id:
				restored_entity = child as CharacterBody3D
				break
	_expect(restored_entity != null, "fresh save restore rebuilds the same deterministic entity root")
	if restored_entity != null:
		_expect(restored_entity.position.is_equal_approx(saved_local_position), "fresh save restore preserves the moved entity position")
		_expect(int(restored_entity.get_meta("backrooms_patrol_index", -1)) == 3, "fresh save restore preserves patrol progress")
	var before_invalid_restore: Dictionary = restored.call("to_save_dict")
	var invalid_payload: Dictionary = saved.duplicate(true)
	var invalid_records: Array = invalid_payload.get("entity_runtime_states", []).duplicate(true)
	for index in range(invalid_records.size()):
		var record: Dictionary = invalid_records[index]
		if str(record.get("cell_key", "")) == selected_cell_key and str(record.get("entity_id", "")) == selected_entity_id:
			var invalid_position: Array = record.get("position", []).duplicate()
			invalid_position[0] = 999.0
			record["position"] = invalid_position
			invalid_records[index] = record
			break
	invalid_payload["entity_runtime_states"] = invalid_records
	_expect(not bool(restored.call("load_save_dict", invalid_payload)), "out-of-cell entity positions are rejected during transactional restore")
	_expect(restored.call("to_save_dict") == before_invalid_restore, "rejected entity-state restore leaves the existing runtime snapshot unchanged")
	restored.queue_free()
	runtime.queue_free()
	await process_frame


func _production_entity_spawn_contract_is_valid() -> void:
	var spawn_runtime: Variant = RuntimeScript.new()
	spawn_runtime.force_metadata_only = true
	root.add_child(spawn_runtime)
	var world_seed: int = 20261115
	var levels: Array[String] = ["Level 0", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]
	for level_id in levels:
		var allowed: Array[String] = EntityDirectorScript.get_allowed_entities(level_id)
		if allowed.is_empty():
			var empty_result: Dictionary = spawn_runtime.call("prepare_destination", level_id, world_seed, Vector3.ZERO, 8.0, 0)
			var empty_root: Node3D = spawn_runtime.call("get_cell_root", "0,0") as Node3D
			_expect(bool(empty_result.get("ok", false)), "Level 0 production runtime prepares without entity candidates")
			_expect(empty_root != null and empty_root.get_children().is_empty(), "Level 0 production cells remain entity-free")
			if empty_root != null:
				_expect(empty_root.get_meta("backrooms_entity_spawn_ids", []).is_empty(), "Level 0 records an empty spawn descriptor list")
			continue
		for entity_id in allowed:
			var candidate: Dictionary = _find_runtime_spawn_candidate(spawn_runtime, level_id, entity_id, world_seed)
			var found_cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
			var found_root: Node3D = candidate.get("entity_root", null) as Node3D
			var found_cell_root: Node3D = candidate.get("cell_root", null) as Node3D
			_expect(found_root != null, "%s production runtime creates a deterministic %s root" % [level_id, entity_id])
			if found_root == null or found_cell_root == null:
				continue
			_expect(found_root.get_meta("backrooms_entity_id") == entity_id, "%s root preserves its entity identity" % entity_id)
			_expect(found_root.get_meta("spawn_cell") == found_cell, "%s root preserves its owning cell" % entity_id)
			_expect(found_root.get_meta("spawn_world_seed") == world_seed, "%s root records its world seed" % entity_id)
			_expect(found_root.get_meta("spawn_level_id") == level_id, "%s root records its level" % entity_id)
			_expect(int(found_root.get_meta("spawn_algorithm_version", 0)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "%s root records its spawn algorithm version" % entity_id)
			_expect(int(found_cell_root.get_meta("backrooms_entity_spawn_algorithm_version", 0)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "%s cell root records the spawn algorithm version" % entity_id)
			_expect(found_root.position.x >= -4.0 and found_root.position.x <= 4.0 and found_root.position.z >= -4.0 and found_root.position.z <= 4.0, "%s root stays inside its owning cell" % entity_id)
			var brain: Node = found_root.get_node_or_null("AI")
			var collision_shape: CollisionShape3D = found_root.get_node_or_null("EntityCollision") as CollisionShape3D
			var mobile_entity_ids: Array[String] = ["smiler", "hound", "skin_stealer", "faceling", "duller", "deathmoth"]
			var expects_mobile_collision: bool = mobile_entity_ids.has(entity_id)
			_expect(found_root is CharacterBody3D, "%s production root is a CharacterBody3D" % entity_id)
			_expect(brain != null, "%s metadata-only production root owns a logic controller" % entity_id)
			_expect(found_root.get_node_or_null("Visuals") == null, "%s metadata-only production root remains renderer-independent" % entity_id)
			if expects_mobile_collision:
				_expect(collision_shape != null and collision_shape.shape != null, "%s metadata-only root retains its physics collision proxy" % entity_id)
				_expect(collision_shape != null and collision_shape.disabled, "%s prepared destination keeps entity collision disabled" % entity_id)
				_expect(found_root.get_children().size() == 2, "%s metadata-only root contains AI and collision nodes only" % entity_id)
			else:
				_expect(collision_shape == null, "%s anchored root has no mobile collision shape" % entity_id)
				_expect(found_root.get_children().size() == 1, "%s anchored metadata-only root contains only its AI controller" % entity_id)
			_expect(
				int(found_root.get_meta("backrooms_entity_behavior_version", 0)) == BrainScript.BEHAVIOR_VERSION,
				"%s root records its explicit behavior version" % entity_id
			)
			if entity_id == "window":
				var wall_direction: Vector2i = found_root.get_meta("backrooms_wall_direction", Vector2i.ZERO)
				var open_edges: Dictionary = found_cell_root.get_meta("backrooms_open_edges", {})
				_expect(wall_direction == Vector2i(0, -1) or wall_direction == Vector2i(-1, 0), "Window root uses only its owning north or west wall")
				if wall_direction == Vector2i(0, -1):
					_expect(not bool(open_edges.get("north", true)), "Window north wall is actually closed")
				elif wall_direction == Vector2i(-1, 0):
					_expect(not bool(open_edges.get("west", true)), "Window west wall is actually closed")
			_assert_cell_spawn_descriptors_match(level_id, found_cell, found_cell_root)
			_assert_spawn_save_restore(spawn_runtime, level_id, entity_id, found_cell, world_seed, found_root.position)
			_assert_spawn_repeat_staging(spawn_runtime, level_id, entity_id, found_cell, world_seed, found_root.position)
	var activation_candidate: Dictionary = _find_runtime_spawn_candidate(
		spawn_runtime, "Level 5", "deathmoth", world_seed
	)
	var activation_root: CharacterBody3D = activation_candidate.get("entity_root", null) as CharacterBody3D
	_expect(activation_root != null, "a mobile entity is available for activation collision lifecycle verification")
	if activation_root != null:
		var activation_shape: CollisionShape3D = activation_root.get_node_or_null("EntityCollision") as CollisionShape3D
		_expect(activation_shape != null and activation_shape.disabled, "prepared mobile entity collision shape remains disabled")
		_expect(activation_root.collision_layer == 0 and activation_root.collision_mask == 0, "prepared mobile entity remains outside the physics collision world")
		_expect(bool(spawn_runtime.call("activate_destination")), "metadata-only runtime activates for collision lifecycle verification")
		_expect(activation_shape != null and not activation_shape.disabled, "runtime activation enables the entity collision shape")
		_expect(activation_root.collision_layer == 4 and activation_root.collision_mask == 1, "runtime activation restores the entity collision layer and mask")
		_expect(bool(spawn_runtime.call("deactivate_destination")), "metadata-only runtime deactivates after collision lifecycle verification")
	spawn_runtime.queue_free()

func _find_runtime_spawn_candidate(runtime: Variant, level_id: String, entity_id: String, world_seed: int) -> Dictionary:
	for z in range(-40, 41):
		for x in range(-40, 41):
			var cell := Vector2i(x, z)
			if not EntityDirectorScript.get_cell_spawns(level_id, cell).has(entity_id):
				continue
			var entry_position := Vector3(float(cell.x) * 8.0, 0.0, float(cell.y) * 8.0)
			var prepare_result: Dictionary = runtime.call("prepare_destination", level_id, world_seed, entry_position, 8.0, 0)
			if not bool(prepare_result.get("ok", false)):
				continue
			var cell_key: String = "%d,%d" % [cell.x, cell.y]
			var cell_root: Node3D = runtime.call("get_cell_root", cell_key) as Node3D
			var entity_root: Node3D = _find_entity_root(cell_root, entity_id)
			if entity_root != null:
				return {"cell": cell, "cell_root": cell_root, "entity_root": entity_root}
	return {}

func _assert_cell_spawn_descriptors_match(level_id: String, cell: Vector2i, cell_root: Node3D) -> void:
	var expected_ids: Array[String] = []
	var descriptors: Array[Dictionary] = EntityDirectorScript.get_cell_spawn_descriptors(
		level_id,
		cell,
		8.0,
		cell_root.get_meta("backrooms_open_edges")
	)
	for descriptor in descriptors:
		expected_ids.append(str(descriptor.get("entity_id", "")))
	var actual_ids: Array[String] = []
	for child in cell_root.get_children():
		if child is Node3D and child.has_meta("backrooms_entity_id"):
			actual_ids.append(str(child.get_meta("backrooms_entity_id")))
	actual_ids.sort()
	expected_ids.sort()
	_expect(actual_ids == expected_ids, "%s cell roots exactly match the Director's filtered spawn descriptors" % level_id)
	var metadata_ids: Array = cell_root.get_meta("backrooms_entity_spawn_ids", []).duplicate()
	metadata_ids.sort()
	_expect(metadata_ids == expected_ids, "%s cell metadata matches its attached spawn roots" % level_id)

func _assert_spawn_save_restore(
	runtime: Variant,
	level_id: String,
	entity_id: String,
	cell: Vector2i,
	world_seed: int,
	original_position: Vector3
) -> void:
	var saved: Dictionary = runtime.call("to_save_dict")
	var restored_runtime: Variant = RuntimeScript.new()
	restored_runtime.force_metadata_only = true
	root.add_child(restored_runtime)
	var restored_ok: bool = bool(restored_runtime.call("load_save_dict", saved))
	_expect(restored_ok, "%s spawn roots rebuild from the existing maze save payload" % entity_id)
	if restored_ok:
		var cell_key: String = "%d,%d" % [cell.x, cell.y]
		var restored_cell_root: Node3D = restored_runtime.call("get_cell_root", cell_key) as Node3D
		var restored_entity_root: Node3D = _find_entity_root(restored_cell_root, entity_id)
		_expect(restored_entity_root != null, "%s root is reconstructed after save restore" % entity_id)
		if restored_entity_root != null:
			_expect(restored_entity_root.position.is_equal_approx(original_position), "%s position is deterministic across save restore" % entity_id)
			_expect(restored_entity_root.get_meta("spawn_world_seed") == world_seed, "%s restored root keeps the same world seed" % entity_id)
			_expect(int(restored_entity_root.get_meta("spawn_algorithm_version", 0)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "%s restored root keeps the saved spawn algorithm version" % entity_id)
	restored_runtime.queue_free()

func _assert_spawn_repeat_staging(
	runtime: Variant,
	level_id: String,
	entity_id: String,
	cell: Vector2i,
	world_seed: int,
	original_position: Vector3
) -> void:
	var repeated: Dictionary = runtime.call(
		"prepare_destination",
		level_id,
		world_seed,
		Vector3(float(cell.x) * 8.0, 0.0, float(cell.y) * 8.0),
		8.0,
		0
	)
	var repeated_cell_root: Node3D = runtime.call("get_cell_root", "%d,%d" % [cell.x, cell.y]) as Node3D
	var repeated_entity_root: Node3D = _find_entity_root(repeated_cell_root, entity_id)
	_expect(bool(repeated.get("ok", false)) and repeated_entity_root != null, "%s can be rebuilt from the same deterministic cell descriptor" % entity_id)
	if repeated_entity_root != null:
		_expect(repeated_entity_root.position.is_equal_approx(original_position), "%s placement is stable across repeated staging" % entity_id)

func _find_entity_root(cell_root: Node3D, entity_id: String) -> Node3D:
	if cell_root == null:
		return null
	for child in cell_root.get_children():
		if child is Node3D and child.get_meta("backrooms_entity_id", "") == entity_id:
			return child as Node3D
	return null

func _fail_cell_builder(_descriptor: Dictionary, _metadata_only: bool) -> Node3D:
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
