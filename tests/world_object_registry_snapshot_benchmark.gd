extends SceneTree

const RegistryScript = preload("res://systems/WorldObjectStateRegistry.gd")
const REGISTRY_RECORD_COUNT: int = 289
const TRANSACTION_COUNT: int = 577
const SAMPLE_COUNT: int = 5
const WARMUP_COUNT: int = 10

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry: Node = RegistryScript.new()
	root.add_child(registry)
	await process_frame

	var target_ids: Array[String] = []
	for record_index in range(REGISTRY_RECORD_COUNT):
		var chunk_id: String = "benchmark/chunk_%03d" % record_index
		var stable_id: String = chunk_id + "/object/SalvageCrate"
		var state: Dictionary = {
			"opened": record_index % 2 == 0,
			"loot_remaining": record_index % 4,
			"loot_seed": record_index * 7919,
			"respawn_at": record_index * 60,
			"label": "crate_%03d" % record_index,
			"variant": record_index % 7,
			"is_locked": record_index % 5 == 0,
			"durability": float(record_index % 100) + 0.5
		}
		_expect(bool(registry.call("set_object_state", stable_id, chunk_id, state)), "production registry accepts benchmark record %d" % record_index)
		target_ids.append(stable_id)

	_expect(registry.call("get_saved_ids").size() == REGISTRY_RECORD_COUNT, "benchmark registry contains exactly %d records" % REGISTRY_RECORD_COUNT)
	if not failures.is_empty():
		_finish(registry)
		return

	var original_record: Dictionary = registry.call("get_object_state", target_ids[0])
	var detached_record: Dictionary = registry.call("get_object_state", target_ids[0])
	detached_record["state"]["opened"] = not bool(detached_record["state"]["opened"])
	_expect(registry.call("get_object_state", target_ids[0]) == original_record, "scoped record snapshots are deep copies and cannot mutate registry state")

	for warmup_index in range(WARMUP_COUNT):
		var full_warmup: Dictionary = registry.call("to_save_dict")
		var scoped_warmup: Dictionary = registry.call("get_object_state", target_ids[warmup_index % target_ids.size()])
		_expect(full_warmup.get("objects", {}).size() == REGISTRY_RECORD_COUNT, "full-snapshot warmup retains every record")
		_expect(not scoped_warmup.is_empty(), "scoped-snapshot warmup finds its target record")

	var full_samples: Array[int] = []
	var scoped_samples: Array[int] = []
	var expected_full_records: int = REGISTRY_RECORD_COUNT * TRANSACTION_COUNT
	var expected_scoped_records: int = TRANSACTION_COUNT

	for sample_index in range(SAMPLE_COUNT):
		var full_result: Dictionary
		var scoped_result: Dictionary
		if sample_index % 2 == 0:
			full_result = _measure_full_snapshots(registry)
			scoped_result = _measure_scoped_snapshots(registry, target_ids)
		else:
			scoped_result = _measure_scoped_snapshots(registry, target_ids)
			full_result = _measure_full_snapshots(registry)

		full_samples.append(int(full_result.get("elapsed_usec", 0)))
		scoped_samples.append(int(scoped_result.get("elapsed_usec", 0)))
		_expect(int(full_result.get("copied_records", -1)) == expected_full_records, "full snapshot sample %d copies the expected number of records" % sample_index)
		_expect(int(scoped_result.get("copied_records", -1)) == expected_scoped_records, "scoped snapshot sample %d copies one target record per transaction" % sample_index)

	var median_full_usec: int = _median_usec(full_samples)
	var median_scoped_usec: int = _median_usec(scoped_samples)
	var reduction_ratio: float = float(expected_full_records) / float(expected_scoped_records)
	var report: Dictionary = {
		"benchmark": "world_object_registry_snapshot_cost",
		"registry_records": REGISTRY_RECORD_COUNT,
		"transactions_per_sample": TRANSACTION_COUNT,
		"state_properties_per_record": 8,
		"samples": SAMPLE_COUNT,
		"full_snapshot_records_copied_per_sample": expected_full_records,
		"scoped_snapshot_records_copied_per_sample": expected_scoped_records,
		"record_copy_reduction_ratio": reduction_ratio,
		"full_snapshot_median_usec": median_full_usec,
		"scoped_snapshot_median_usec": median_scoped_usec,
		"timing_is_informational": true,
		"measures_controller_or_frame_time": false
	}
	print("WORLD_OBJECT_REGISTRY_BENCHMARK_JSON:" + JSON.stringify(report))
	_expect(expected_full_records == 166753, "steady-state full-snapshot copy count is deterministic")
	_expect(expected_scoped_records == 577, "steady-state scoped copy count is deterministic")
	_expect(reduction_ratio == 289.0, "steady-state scoped path copies 289 times fewer top-level records")

	_finish(registry)

func _measure_full_snapshots(registry: Node) -> Dictionary:
	var copied_records: int = 0
	var started_at: int = Time.get_ticks_usec()
	for iteration in range(TRANSACTION_COUNT):
		var snapshot: Dictionary = registry.call("to_save_dict")
		var objects: Dictionary = snapshot.get("objects", {})
		copied_records += objects.size()
	var elapsed_usec: int = Time.get_ticks_usec() - started_at
	return {"elapsed_usec": elapsed_usec, "copied_records": copied_records}

func _measure_scoped_snapshots(registry: Node, target_ids: Array[String]) -> Dictionary:
	var copied_records: int = 0
	var checksum: int = 0
	var started_at: int = Time.get_ticks_usec()
	for iteration in range(TRANSACTION_COUNT):
		var stable_id: String = target_ids[iteration % target_ids.size()]
		var snapshot: Dictionary = registry.call("get_object_state", stable_id)
		if not snapshot.is_empty():
			copied_records += 1
			checksum += int(snapshot.get("state", {}).get("loot_remaining", 0))
	var elapsed_usec: int = Time.get_ticks_usec() - started_at
	return {"elapsed_usec": elapsed_usec, "copied_records": copied_records, "checksum": checksum}

func _median_usec(samples: Array[int]) -> int:
	var ordered: Array[int] = samples.duplicate()
	ordered.sort()
	return ordered[ordered.size() / 2] if not ordered.is_empty() else 0

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)

func _finish(registry: Node) -> void:
	registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("World object registry snapshot cost benchmark passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
