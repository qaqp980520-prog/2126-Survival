extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime: Node3D = RuntimeScript.new()
	runtime.force_metadata_only = true
	root.add_child(runtime)
	_expect(not bool(runtime.call("is_prepared")), "runtime starts without a prepared destination")
	_expect(not bool(runtime.call("is_active")) and not runtime.visible, "runtime starts hidden and inactive")

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
	runtime.call("set_cell_builder_for_testing", Callable(self, "_fail_cell_builder"))
	var failed_shift: Dictionary = runtime.call("sync_to_world_position", Vector3(16.0, 0.0, 0.0))
	_expect(not bool(failed_shift.get("ok", false)), "injected cell-builder failure rejects the entire window shift")
	_expect(runtime.call("get_loaded_cell_keys") == original_keys, "failed staging preserves the exact committed cell-key set")
	var origin_after_failure: Node3D = runtime.call("get_cell_root", "0,0") as Node3D
	_expect(origin_after_failure != null and origin_after_failure.get_instance_id() == original_origin_id, "failed staging preserves the existing origin root instance")
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
	var restored: Node3D = RuntimeScript.new()
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
	_expect(bool(restored.call("deactivate_destination")), "active runtime can be deactivated")
	_expect(not bool(restored.call("is_prepared")) and int(restored.call("get_loaded_cell_count")) == 0, "deactivation retires all cell roots and clears runtime state")

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

func _fail_cell_builder(_descriptor: Dictionary, _metadata_only: bool) -> Node3D:
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
