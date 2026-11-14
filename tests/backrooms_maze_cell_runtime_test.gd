extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")
const EntityDirectorScript = preload("res://systems/BackroomsEntityDirector.gd")

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
	_expect(int(saved.get("layout_algorithm_version", -1)) == 1, "runtime save is bound to the explicit maze algorithm version")
	var restored: Variant = RuntimeScript.new()
	restored.force_metadata_only = true
	root.add_child(restored)
	_expect(bool(restored.call("load_save_dict", saved)), "runtime rebuilds a saved stream window from metadata")
	_expect(restored.call("get_loaded_cell_keys") == runtime.call("get_loaded_cell_keys"), "restored runtime reproduces the exact loaded cell-key set")
	var restored_origin: Node3D = restored.call("get_cell_root", "0,0") as Node3D
	_expect(restored_origin != null and restored_origin.get_meta("backrooms_open_edges") == origin_root.get_meta("backrooms_open_edges"), "restored origin reproduces the exact deterministic edge descriptor")
	_expect(not bool(restored.call("is_active")) and not restored.visible, "restored destination remains hidden until explicitly activated")

	var before_bad_restore: Array = restored.call("get_loaded_cell_keys")
	var invalid_save: Dictionary = saved.duplicate(true)
	invalid_save["layout_algorithm_version"] = 999
	_expect(not bool(restored.call("load_save_dict", invalid_save)), "unsupported layout algorithm version is rejected")
	_expect(restored.call("get_loaded_cell_keys") == before_bad_restore, "rejected restore leaves the existing runtime roots unchanged")

	_expect(bool(restored.call("activate_destination")), "prepared runtime can be explicitly activated")
	_expect(bool(restored.call("is_active")) and restored.visible, "activation enables the prepared destination")
	_expect(not bool(restored.call("load_save_dict", saved)), "active runtime rejects an in-place restore")
	_expect(bool(restored.call("is_active")) and restored.call("get_loaded_cell_keys") == before_bad_restore, "rejected active restore preserves the live destination")
	_expect(bool(restored.call("deactivate_destination")), "active runtime can be deactivated")
	_expect(not bool(restored.call("is_prepared")) and int(restored.call("get_loaded_cell_count")) == 0, "deactivation retires all cell roots and clears runtime state")

	_production_entity_spawn_contract_is_valid()

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

func _production_entity_spawn_contract_is_valid() -> void:
	var spawn_runtime: Variant = RuntimeScript.new()
	spawn_runtime.force_metadata_only = true
	root.add_child(spawn_runtime)
	var world_seed: int = 20261115
	var levels: Array[String] = ["Level 0", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]
	for level_id in levels:
		var allowed: Array[String] = EntityDirectorScript.get_allowed_entities(level_id)
		if allowed.is_empty():
			var empty_result: Dictionary = spawn_runtime.call(
				"prepare_destination",
				level_id,
				world_seed,
				Vector3.ZERO,
				8.0,
				0
			)
			var empty_root: Node3D = spawn_runtime.call("get_cell_root", "0,0") as Node3D
			_expect(bool(empty_result.get("ok", false)), "Level 0 production runtime prepares without entity candidates")
			_expect(empty_root != null and empty_root.get_children().is_empty(), "Level 0 production cells remain entity-free")
			if empty_root != null:
				_expect(empty_root.get_meta("backrooms_entity_spawn_ids", []).is_empty(), "Level 0 records an empty spawn descriptor list")
			continue

		for entity_id in allowed:
			var found_cell := Vector2i.ZERO
			var found_root: Node3D
			var found_cell_root: Node3D
			for z in range(-40, 41):
				if found_root != null:
					break
				for x in range(-40, 41):
					var cell := Vector2i(x, z)
					if not EntityDirectorScript.get_cell_spawns(level_id, cell).has(entity_id):
						continue
					var entry_position := Vector3(float(cell.x) * 8.0, 0.0, float(cell.y) * 8.0)
					var prepare_result: Dictionary = spawn_runtime.call(
						"prepare_destination",
						level_id,
						world_seed,
						entry_position,
						8.0,
						0
					)
					if not bool(prepare_result.get("ok", false)):
						continue
					var cell_key: String = "%d,%d" % [cell.x, cell.y]
					var candidate_cell_root: Node3D = spawn_runtime.call("get_cell_root", cell_key) as Node3D
					var candidate_root: Node3D = _find_entity_root(candidate_cell_root, entity_id)
					if candidate_root != null:
						found_cell = cell
						found_root = candidate_root
						found_cell_root = candidate_cell_root
						break
			_expect(found_root != null, "%s production runtime creates a deterministic %s root" % [level_id, entity_id])
			if found_root == null or found_cell_root == null:
				continue
			_expect(found_root.get_meta("backrooms_entity_id") == entity_id, "%s root preserves its entity identity" % entity_id)
			_expect(found_root.get_meta("spawn_cell") == found_cell, "%s root preserves its owning cell" % entity_id)
			_expect(found_root.get_meta("spawn_world_seed") == world_seed, "%s root records its world seed" % entity_id)
			_expect(found_root.get_meta("spawn_level_id") == level_id, "%s root records its level" % entity_id)
			_expect(int(found_root.get_meta("spawn_algorithm_version", 0)) == EntityDirectorScript.SPAWN_ALGORITHM_VERSION, "%s root records its spawn algorithm version" % entity_id)
			_expect(found_root.position.x >= -4.0 and found_root.position.x <= 4.0 and found_root.position.z >= -4.0 and found_root.position.z <= 4.0, "%s root stays inside its owning cell" % entity_id)
			_expect(found_root.get_children().is_empty(), "%s production root remains renderer-independent until visual factory integration" % entity_id)
			if entity_id == "window":
				_expect(found_root.get_meta("backrooms_wall_direction") != Vector2i.ZERO, "Window root is anchored to a closed north or west wall owned by its cell")
			var expected_ids: Array[String] = []
			for descriptor in EntityDirectorScript.get_cell_spawn_descriptors(
				level_id,
				found_cell,
				8.0,
				found_cell_root.get_meta("backrooms_open_edges")
			):
				expected_ids.append(str(descriptor.get("entity_id", "")))
		var actual_ids: Array[String] = []
		for child in found_cell_root.get_children():
			if child is Node3D and child.has_meta("backrooms_entity_id"):
				actual_ids.append(str(child.get_meta("backrooms_entity_id")))
		actual_ids.sort()
		expected_ids.sort()
		_expect(actual_ids == expected_ids, "%s cell roots exactly match the Director's filtered spawn descriptors" % level_id)

		var original_position: Vector3 = found_root.position
		var saved: Dictionary = spawn_runtime.call("to_save_dict")
		var restored_runtime: Variant = RuntimeScript.new()
		restored_runtime.force_metadata_only = true
		root.add_child(restored_runtime)
		_expect(bool(restored_runtime.call("load_save_dict", saved)), "%s spawn roots rebuild from the existing maze save payload" % entity_id)
		var restored_cell_key: String = "%d,%d" % [found_cell.x, found_cell.y]
		var restored_cell_root: Node3D = restored_runtime.call("get_cell_root", restored_cell_key) as Node3D
		var restored_entity_root: Node3D = _find_entity_root(restored_cell_root, entity_id)
		_expect(restored_entity_root != null, "%s root is reconstructed after save restore" % entity_id)
		if restored_entity_root != null:
			_expect(restored_entity_root.position.is_equal_approx(original_position), "%s position is deterministic across save restore" % entity_id)
			_expect(restored_entity_root.get_meta("spawn_world_seed") == world_seed, "%s restored root keeps the same world seed" % entity_id)
		restored_runtime.queue_free()

		var repeated: Dictionary = spawn_runtime.call(
			"prepare_destination",
			level_id,
			world_seed,
			Vector3(float(found_cell.x) * 8.0, 0.0, float(found_cell.y) * 8.0),
			8.0,
			0
		)
		var repeated_cell_root: Node3D = spawn_runtime.call("get_cell_root", "%d,%d" % [found_cell.x, found_cell.y]) as Node3D
		var repeated_entity_root: Node3D = _find_entity_root(repeated_cell_root, entity_id)
		_expect(bool(repeated.get("ok", false)) and repeated_entity_root != null, "%s can be rebuilt from the same deterministic cell descriptor" % entity_id)
		if repeated_entity_root != null:
			_expect(repeated_entity_root.position.is_equal_approx(original_position), "%s placement is stable across repeated staging" % entity_id)
	spawn_runtime.queue_free()

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
