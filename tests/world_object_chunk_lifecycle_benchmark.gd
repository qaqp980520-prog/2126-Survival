extends SceneTree

const MineralRegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const ObjectRegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const CHUNK_COUNT: int = 289
const UNRELATED_RECORD_COUNT: int = 289
const TOTAL_REGISTRY_RECORDS: int = CHUNK_COUNT + UNRELATED_RECORD_COUNT
const SNAPSHOT_TRANSACTIONS: int = CHUNK_COUNT * 2 + 1
const WARMUP_SCENARIOS_PER_MODE: int = 1

class InstrumentedObjectRegistry:
	extends "res://systems/WorldObjectStateRegistry.gd"
	var full_snapshot_calls: int = 0
	var full_snapshot_records_copied: int = 0

	func to_save_dict() -> Dictionary:
		var snapshot: Dictionary = super.to_save_dict()
		full_snapshot_calls += 1
		var objects: Variant = snapshot.get("objects", {})
		if objects is Dictionary:
			full_snapshot_records_copied += objects.size()
		return snapshot

class ScopedSnapshotController:
	extends "res://systems/MineralChunkController.gd"
	var snapshot_transactions: int = 0
	var snapshot_records_copied: int = 0

	func _capture_world_object_registry_snapshot(stable_ids: Array[String]) -> Dictionary:
		var snapshot: Dictionary = super._capture_world_object_registry_snapshot(stable_ids)
		snapshot_transactions += 1
		var records: Variant = snapshot.get("records", {})
		if records is Dictionary:
			snapshot_records_copied += records.size()
		return snapshot

class FullSnapshotController:
	extends "res://systems/MineralChunkController.gd"
	var snapshot_transactions: int = 0
	var snapshot_records_copied: int = 0

	## Test-only baseline: reproduce the pre-M0.3.10 whole-registry snapshot policy.
	func _capture_world_object_registry_snapshot(_stable_ids: Array[String]) -> Dictionary:
		var payload: Dictionary = object_state_registry.call("to_save_dict")
		var objects: Variant = payload.get("objects", {})
		snapshot_transactions += 1
		if objects is Dictionary:
			snapshot_records_copied += objects.size()
		return {"mode": "full", "payload": payload}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var warmup_full: Dictionary = await _run_scenario(true, "full-snapshot warmup")
	var warmup_scoped: Dictionary = await _run_scenario(false, "scoped-snapshot warmup")
	if not bool(warmup_full.get("ok", false)) or not bool(warmup_scoped.get("ok", false)):
		await _finish()
		return

	# Reverse the warmup order for the measured pair to reduce simple order bias.
	var scoped_result: Dictionary = await _run_scenario(false, "scoped-snapshot measured")
	var full_result: Dictionary = await _run_scenario(true, "full-snapshot measured")
	if not bool(scoped_result.get("ok", false)) or not bool(full_result.get("ok", false)):
		await _finish()
		return

	var expected_full_records: int = TOTAL_REGISTRY_RECORDS * SNAPSHOT_TRANSACTIONS
	var expected_scoped_records: int = CHUNK_COUNT * 3
	var reduction_ratio: float = float(expected_full_records) / float(expected_scoped_records)
	_expect(int(full_result.get("snapshot_transactions", -1)) == SNAPSHOT_TRANSACTIONS, "full-snapshot baseline executes the expected load/capture/unload transactions")
	_expect(int(scoped_result.get("snapshot_transactions", -1)) == SNAPSHOT_TRANSACTIONS, "production scoped path executes the same number of load/capture/unload transactions")
	_expect(int(full_result.get("snapshot_records_copied", -1)) == expected_full_records, "full-snapshot baseline copies the expected whole-registry record count")
	_expect(int(scoped_result.get("snapshot_records_copied", -1)) == expected_scoped_records, "production scoped path copies only the affected records")
	_expect(int(full_result.get("full_snapshot_calls", -1)) == SNAPSHOT_TRANSACTIONS, "baseline uses one full serializer call per transaction")
	_expect(int(scoped_result.get("full_snapshot_calls", -1)) == 0, "production scoped lifecycle performs no full-registry serialization")
	_expect(reduction_ratio == 386.0, "matched controller lifecycle reduces top-level record copies by exactly 386 times")

	var report: Dictionary = {
		"benchmark": "world_object_chunk_lifecycle_snapshot_cost",
		"loaded_chunks": CHUNK_COUNT,
		"unrelated_unloaded_records": UNRELATED_RECORD_COUNT,
		"registry_records": TOTAL_REGISTRY_RECORDS,
		"snapshot_transactions_per_sample": SNAPSHOT_TRANSACTIONS,
		"full_snapshot_records_copied_per_sample": expected_full_records,
		"scoped_snapshot_records_copied_per_sample": expected_scoped_records,
		"top_level_record_copy_reduction_ratio": reduction_ratio,
		"full_snapshot_total_usec": int(full_result.get("total_usec", 0)),
		"scoped_snapshot_total_usec": int(scoped_result.get("total_usec", 0)),
		"full_snapshot_load_usec": int(full_result.get("load_usec", 0)),
		"scoped_snapshot_load_usec": int(scoped_result.get("load_usec", 0)),
		"full_snapshot_capture_usec": int(full_result.get("capture_usec", 0)),
		"scoped_snapshot_capture_usec": int(scoped_result.get("capture_usec", 0)),
		"full_snapshot_unload_usec": int(full_result.get("unload_usec", 0)),
		"scoped_snapshot_unload_usec": int(scoped_result.get("unload_usec", 0)),
		"measures_production_controller_load_capture_unload": true,
		"baseline_is_test_only_full_snapshot_override": true,
		"timing_is_informational_single_sample": true,
		"measures_gpu_or_fps": false
	}
	print("WORLD_OBJECT_CHUNK_LIFECYCLE_BENCHMARK_JSON:" + JSON.stringify(report))
	await _finish()

func _run_scenario(use_full_snapshot: bool, label: String) -> Dictionary:
	var failures_before: int = failures.size()
	var mineral_registry: Node = MineralRegistryScript.new()
	var object_registry: Node = InstrumentedObjectRegistry.new()
	var controller: Node3D
	if use_full_snapshot:
		controller = FullSnapshotController.new()
	else:
		controller = ScopedSnapshotController.new()

	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame

	var setup_ok: bool = bool(controller.call("bind_registry", mineral_registry))
	setup_ok = setup_ok and bool(controller.call("bind_object_state_registry", object_registry))
	_expect(setup_ok, "%s binds the production mineral and object registries" % label)
	if not setup_ok:
		await _cleanup_scenario(controller, object_registry, mineral_registry)
		return {"ok": false}

	var saved_state: Dictionary = {"opened": true, "loot_remaining": 1, "loot_item_id": "iron_ore"}
	var seed_ok: bool = true
	for index in range(UNRELATED_RECORD_COUNT):
		var unrelated_chunk_id: String = _unrelated_chunk_id(index)
		var unrelated_id: String = _stable_id(unrelated_chunk_id)
		if not bool(object_registry.call("set_object_state", unrelated_id, unrelated_chunk_id, saved_state)):
			seed_ok = false
			break
	for index in range(CHUNK_COUNT):
		var chunk_id: String = _target_chunk_id(index)
		var stable_id: String = _stable_id(chunk_id)
		if not bool(object_registry.call("set_object_state", stable_id, chunk_id, saved_state)):
			seed_ok = false
			break
	_expect(seed_ok and object_registry.call("get_saved_ids").size() == TOTAL_REGISTRY_RECORDS, "%s seeds %d saved records including unrelated unloaded chunks" % [label, TOTAL_REGISTRY_RECORDS])
	if not seed_ok:
		await _cleanup_scenario(controller, object_registry, mineral_registry)
		return {"ok": false}

	var load_started: int = Time.get_ticks_usec()
	var load_batch_open: bool = bool(controller.call("begin_terrain_adjacency_batch"))
	var load_ok: bool = load_batch_open
	for index in range(CHUNK_COUNT):
		if not load_ok:
			break
		var chunk_root := Node3D.new()
		chunk_root.name = "ChunkRoot"
		var prop: Node3D = StatefulPropScript.new()
		prop.name = "SalvageCrate"
		chunk_root.add_child(prop)
		var chunk_id: String = _target_chunk_id(index)
		if not bool(controller.call("load_chunk", chunk_id, chunk_root, 1000)):
			load_ok = false
			if is_instance_valid(chunk_root) and chunk_root.get_parent() == null:
				chunk_root.free()
	if load_batch_open:
		var load_batch_result: Dictionary = controller.call("end_terrain_adjacency_batch")
		load_ok = load_ok and bool(load_batch_result.get("ok", false))
	var load_usec: int = Time.get_ticks_usec() - load_started
	_expect(load_ok and controller.call("get_loaded_chunk_ids").size() == CHUNK_COUNT, "%s loads all %d stateful production chunks" % [label, CHUNK_COUNT])
	if not load_ok:
		await _cleanup_scenario(controller, object_registry, mineral_registry)
		return {"ok": false}

	var capture_started: int = Time.get_ticks_usec()
	var capture_ok: bool = bool(controller.call("capture_loaded_world_object_states"))
	var capture_usec: int = Time.get_ticks_usec() - capture_started
	_expect(capture_ok, "%s captures all loaded world-object states" % label)
	if not capture_ok:
		await _cleanup_scenario(controller, object_registry, mineral_registry)
		return {"ok": false}

	var unload_started: int = Time.get_ticks_usec()
	var unload_batch_open: bool = bool(controller.call("begin_terrain_adjacency_batch"))
	var unload_ok: bool = unload_batch_open
	for index in range(CHUNK_COUNT):
		if not unload_ok:
			break
		if not bool(controller.call("unload_chunk", _target_chunk_id(index), 1000)):
			unload_ok = false
	if unload_batch_open:
		var unload_batch_result: Dictionary = controller.call("end_terrain_adjacency_batch")
		unload_ok = unload_ok and bool(unload_batch_result.get("ok", false))
	var unload_usec: int = Time.get_ticks_usec() - unload_started
	_expect(unload_ok and controller.call("get_loaded_chunk_ids").is_empty(), "%s unloads all chunks without losing saved records" % label)
	if not unload_ok:
		await _cleanup_scenario(controller, object_registry, mineral_registry)
		return {"ok": false}

	var integrity_ok: bool = object_registry.call("get_saved_ids").size() == TOTAL_REGISTRY_RECORDS
	for index in range(CHUNK_COUNT):
		var chunk_id: String = _target_chunk_id(index)
		var record: Dictionary = object_registry.call("get_object_state", _stable_id(chunk_id))
		var state: Dictionary = record.get("state", {})
		if str(record.get("chunk_id", "")) != chunk_id or not bool(state.get("opened", false)) or int(state.get("loot_remaining", -1)) != 1 or str(state.get("loot_item_id", "")) != "iron_ore":
			integrity_ok = false
			break
	if integrity_ok:
		for index in range(UNRELATED_RECORD_COUNT):
			var chunk_id: String = _unrelated_chunk_id(index)
			var record: Dictionary = object_registry.call("get_object_state", _stable_id(chunk_id))
			if str(record.get("chunk_id", "")) != chunk_id or record.get("state", {}) != saved_state:
				integrity_ok = false
				break
	_expect(integrity_ok, "%s preserves all loaded and unrelated unloaded object records" % label)

	var snapshot_transactions: int = int(controller.get("snapshot_transactions"))
	var snapshot_records_copied: int = int(controller.get("snapshot_records_copied"))
	var full_snapshot_calls: int = int(object_registry.get("full_snapshot_calls"))
	var full_snapshot_records_copied: int = int(object_registry.get("full_snapshot_records_copied"))
	_expect(full_snapshot_records_copied == full_snapshot_calls * TOTAL_REGISTRY_RECORDS, "%s full serializer accounting matches the fixed registry size" % label)
	var accounting_ok: bool = full_snapshot_records_copied == snapshot_records_copied
	if not use_full_snapshot:
		accounting_ok = full_snapshot_records_copied == 0
	_expect(accounting_ok, "%s registry and controller snapshot accounting agree" % label)

	await _cleanup_scenario(controller, object_registry, mineral_registry)
	return {
		"ok": failures.size() == failures_before,
		"snapshot_transactions": snapshot_transactions,
		"snapshot_records_copied": snapshot_records_copied,
		"full_snapshot_calls": full_snapshot_calls,
		"full_snapshot_records_copied": full_snapshot_records_copied,
		"load_usec": load_usec,
		"capture_usec": capture_usec,
		"unload_usec": unload_usec,
		"total_usec": load_usec + capture_usec + unload_usec
	}

func _cleanup_scenario(controller: Node, object_registry: Node, mineral_registry: Node) -> void:
	controller.queue_free()
	object_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _target_chunk_id(index: int) -> String:
	return "surface/benchmark/chunk_%03d" % index

func _unrelated_chunk_id(index: int) -> String:
	return "unloaded/benchmark/chunk_%03d" % index

func _stable_id(chunk_id: String) -> String:
	return chunk_id + "/object/ChunkRoot/SalvageCrate"

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func _finish() -> void:
	if failures.is_empty():
		print("World object chunk lifecycle snapshot benchmark passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
