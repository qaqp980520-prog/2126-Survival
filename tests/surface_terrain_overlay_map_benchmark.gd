extends SceneTree

const OverlayMapScript = preload("res://systems/SurfaceTerrainOverlayMap.gd")
const FIXTURE_SIZES: Array[int] = [225, 576, 2048, 8192]
const SAMPLE_COUNT: int = 7
const UPDATE_COUNT: int = 8
const REMOVE_COUNT: int = 4
const ADD_COUNT: int = 4
const LOOKUP_COUNT: int = 32

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for fixture_size in FIXTURE_SIZES:
		_benchmark_fixture(fixture_size)
	if failures.is_empty():
		print("Surface terrain overlay map benchmark completed.")
		quit(0)
	else:
		push_error("Surface terrain overlay map benchmark failed: %d" % failures.size())
		quit(1)


func _benchmark_fixture(fixture_size: int) -> void:
	var base: Dictionary = {}
	for index in range(fixture_size):
		var key: String = "patch/%05d" % index
		base[key] = {
			"revision": index,
			"payload": PackedInt32Array([index % 13, index % 17, index % 23])
		}
	var overlay_root: RefCounted = OverlayMapScript.new(base)
	var update_keys: Array[String] = []
	var remove_keys: Array[String] = []
	var addition_keys: Array[String] = []
	for index in range(UPDATE_COUNT):
		update_keys.append("patch/%05d" % (index * max(1, int(fixture_size / UPDATE_COUNT))))
	for index in range(REMOVE_COUNT):
		remove_keys.append("patch/%05d" % (fixture_size - 1 - index))
	for index in range(ADD_COUNT):
		addition_keys.append("new/%02d" % index)

	var full_samples: Array[int] = []
	var overlay_samples: Array[int] = []
	var materialize_samples: Array[int] = []
	var parity_passes: int = 0
	for sample_index in range(SAMPLE_COUNT):
		var update_values: Dictionary = {}
		for update_index in range(UPDATE_COUNT):
			update_values[update_keys[update_index]] = {
				"revision": 100000 + sample_index * 100 + update_index,
				"payload": PackedInt32Array([fixture_size, sample_index, update_index])
			}
		var addition_values: Dictionary = {}
		for addition_index in range(ADD_COUNT):
			addition_values[addition_keys[addition_index]] = {
				"revision": 200000 + sample_index * 100 + addition_index,
				"payload": PackedInt32Array([fixture_size, sample_index, addition_index])
			}

		var full_started_usec: int = Time.get_ticks_usec()
		var full_candidate: Dictionary = base.duplicate(false)
		for key in update_values:
			full_candidate[key] = update_values[key]
		for key in remove_keys:
			full_candidate.erase(key)
		for key in addition_values:
			full_candidate[key] = addition_values[key]
		var full_checksum: int = _lookup_checksum(full_candidate, fixture_size, sample_index)
		var full_elapsed_usec: int = Time.get_ticks_usec() - full_started_usec
		full_samples.append(full_elapsed_usec)

		var overlay_started_usec: int = Time.get_ticks_usec()
		var candidate: RefCounted = overlay_root.call("fork")
		for key in update_values:
			candidate.call("set_value", key, update_values[key])
		for key in remove_keys:
			candidate.call("erase_key", key)
		for key in addition_values:
			candidate.call("set_value", key, addition_values[key])
		var overlay_checksum: int = _lookup_overlay_checksum(candidate, fixture_size, sample_index)
		var overlay_elapsed_usec: int = Time.get_ticks_usec() - overlay_started_usec
		overlay_samples.append(overlay_elapsed_usec)

		var materialize_started_usec: int = Time.get_ticks_usec()
		var materialized: Dictionary = candidate.call("materialize")
		var materialize_elapsed_usec: int = Time.get_ticks_usec() - materialize_started_usec
		materialize_samples.append(materialize_elapsed_usec)
		_expect(materialized == full_candidate, "fixture %d sample %d overlay materialization matches Dictionary oracle" % [fixture_size, sample_index + 1])
		_expect(overlay_checksum == full_checksum, "fixture %d sample %d overlay lookup checksum matches Dictionary oracle" % [fixture_size, sample_index + 1])
		_expect(int(candidate.call("size")) == full_candidate.size(), "fixture %d sample %d cached size matches Dictionary oracle" % [fixture_size, sample_index + 1])
		if materialized == full_candidate and overlay_checksum == full_checksum:
			parity_passes += 1

	var record: Dictionary = {
		"fixture_entries": fixture_size,
		"sample_count": SAMPLE_COUNT,
		"delta_operations": UPDATE_COUNT + REMOVE_COUNT + ADD_COUNT,
		"lookup_count": LOOKUP_COUNT,
		"dictionary_copy_edit_lookup_p50_usec": _median(full_samples),
		"overlay_fork_edit_lookup_p50_usec": _median(overlay_samples),
		"overlay_materialize_p50_usec": _median(materialize_samples),
		"parity_passes": parity_passes,
		"expected_parity_passes": SAMPLE_COUNT,
		"overlay_max_depth": 1
	}
	print("SURFACE_TERRAIN_OVERLAY_MAP_BENCHMARK_JSON:" + JSON.stringify(record))
	_expect(parity_passes == SAMPLE_COUNT, "fixture %d passes all matched samples" % fixture_size)


func _lookup_checksum(source: Dictionary, fixture_size: int, sample_index: int) -> int:
	var checksum: int = 0
	for index in range(LOOKUP_COUNT):
		var key: String = "patch/%05d" % ((index * 7919 + sample_index * 13) % fixture_size)
		var value: Variant = source.get(key, null)
		if value is Dictionary:
			checksum += int(value.get("revision", 0))
	return checksum


func _lookup_overlay_checksum(source: RefCounted, fixture_size: int, sample_index: int) -> int:
	var checksum: int = 0
	for index in range(LOOKUP_COUNT):
		var key: String = "patch/%05d" % ((index * 7919 + sample_index * 13) % fixture_size)
		if bool(source.call("has_key", key)):
			var value: Variant = source.call("get_value", key)
			if value is Dictionary:
				checksum += int(value.get("revision", 0))
	return checksum


func _median(values: Array[int]) -> int:
	var sorted_values: Array[int] = values.duplicate()
	sorted_values.sort()
	return sorted_values[int(sorted_values.size() / 2)]


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
