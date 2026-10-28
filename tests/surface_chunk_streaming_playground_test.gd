extends SceneTree

const PlaygroundScene = preload("res://prototypes/SurfaceChunkStreamingPlayground.tscn")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")
var _failed: bool = false
var _finished: bool = false
var _watchdog_timer: Timer
var _fail_factory_coordinate: Vector2i = Vector2i(999999, 999999)

func _initialize() -> void:
	_watchdog_timer = Timer.new()
	_watchdog_timer.one_shot = true
	_watchdog_timer.wait_time = 25.0
	root.add_child(_watchdog_timer)
	_watchdog_timer.timeout.connect(_on_watchdog_timeout)
	call_deferred("_start_watchdog")
	call_deferred("_run_tests")

func _start_watchdog() -> void:
	if not _finished and is_instance_valid(_watchdog_timer) and _watchdog_timer.is_inside_tree():
		_watchdog_timer.start()

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_finished = true
	push_error("Surface chunk streaming playground integration test timed out.")
	if is_instance_valid(_watchdog_timer):
		_watchdog_timer.queue_free()
	quit(1)

func _run_tests() -> void:
	var playground: Variant = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	if playground == null or playground.chunk_controller == null or playground.director == null or playground.registry == null or playground.crop_registry == null or playground.crop_controller == null:
		push_error("Surface playground did not initialize its streaming stack.")
		_failed = true
		_finish()
		return

	var now: int = int(Time.get_unix_time_from_system())
	_check(playground.chunk_controller.get_loaded_chunk_ids().size() == 9, "Initial player window should load 3x3 chunks")
	_check(playground.director.get_managed_chunk_ids() == playground.chunk_controller.get_loaded_chunk_ids(), "Director and controller active IDs must match")
	_check(playground.director.get_grid_coordinate(Vector3(-0.1, 0.0, -0.1)) == Vector2i(-1, -1), "Negative positions must use floor-based grid coordinates")
	_check(playground.director.get_grid_coordinate(Vector3(10.0, 0.0, 10.0)) == Vector2i(1, 1), "Exact positive chunk boundaries must map to the next chunk")
	_check(playground.chunk_controller.get_loaded_crop_plots().size() == 18, "Two crop plots are attached to each of the nine active chunks")

	var original_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	if original_root == null:
		push_error("Initial chunk surface/chunk_0_0 was not created.")
		_failed = true
		_finish()
		return
	var original_position: Vector3 = playground.player.global_position
	var original_ore: Node = original_root.get_node_or_null("Ore_0_0")
	if original_ore == null:
		push_error("Expected mineral node Ore_0_0 was not created.")
		_failed = true
		_finish()
		return
	original_ore.set("remaining_units", 2)
	var original_crop: Node = original_root.get_node_or_null("CropPlot_0")
	if original_crop == null:
		push_error("Expected crop plot CropPlot_0 was not created.")
		_failed = true
		_finish()
		return
	var crop_stable_id: String = str(original_crop.get("stable_id"))
	_check(not crop_stable_id.is_empty(), "Streamed crop plot receives a stable chunk-scoped ID")
	playground.player.global_position = original_crop.global_position + Vector3(0.0, 1.0, 0.0)
	var planted: Dictionary = playground.call("_interact_nearest_crop_plot", now)
	_check(bool(planted.get("ok", false)) and str(planted.get("action", "")) == "planted", "E interaction plants the nearest streamed crop plot")
	_check(bool(playground.crop_controller.advance_crop(crop_stable_id, 120.0, now + 120)), "Crop can advance before its chunk unloads")
	_check(int(playground.crop_registry.get_crop(crop_stable_id).get("growth_stage", -1)) == 1, "Crop growth is stored in the shared registry")
	playground.player.global_position = Vector3(200.0, 2.0, 200.0)
	var out_of_reach: Dictionary = playground.call("_interact_nearest_crop_plot", now + 121)
	_check(str(out_of_reach.get("action", "")) == "out_of_reach", "Nearby interaction rejects crop plots outside the reach radius")
	playground.player.global_position = original_position
	var stable_id: String = Adapter.make_stable_id("surface/chunk_0_0", "Chunk_0_0/Ore_0_0")
	var save_payload: Dictionary = playground.serialize_stream_state()
	var mineral_payload: Dictionary = save_payload.get("minerals", {})
	var saved_veins: Dictionary = mineral_payload.get("veins", {})
	_check(saved_veins.has(stable_id), "Save must include the loaded vein")
	_check(saved_veins.size() == 9, "Initial save should contain all nine active veins")
	var crop_payload: Dictionary = save_payload.get("crops", {})
	var saved_crops: Dictionary = crop_payload.get("crops", {})
	_check(saved_crops.has(crop_stable_id), "Stream save must include the crop registry record")

	if not bool(playground.debug_move_player_to(Vector3(21.0, 2.0, 1.0), now)):
		push_error("Moving across chunks should shift the stream window.")
		_failed = true
		_finish()
		return
	_check(playground.chunk_controller.get_loaded_chunk_ids().size() == 9, "Active window should remain 3x3 after movement")
	_check(not playground.chunk_controller.is_chunk_loaded("surface/chunk_0_0"), "Stale origin chunk should be unloaded")
	_check(playground.registry.get_saved_ids().size() == 15, "Registry should retain six unloaded veins plus nine active-window veins")
	_check(int(playground.crop_registry.get_crop(crop_stable_id).get("growth_stage", -1)) == 1, "Crop record survives scene unload")

	if not bool(playground.restore_stream_state(save_payload, now)):
		push_error("Valid save should restore position and mineral state.")
		_failed = true
		_finish()
		return
	_check(playground.director.get_managed_chunk_ids().size() == 9, "Restored stream should have nine managed chunks")
	_check(playground.chunk_controller.is_chunk_loaded("surface/chunk_0_0"), "Restore should return to the saved origin chunk")
	var restored_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	var restored_ore: Node = restored_root.get_node_or_null("Ore_0_0") if restored_root != null else null
	if restored_ore == null:
		push_error("Restored origin chunk is missing Ore_0_0.")
		_failed = true
		_finish()
		return
	_check(int(restored_ore.get("remaining_units")) == 2, "Stable ID must restore saved vein stock after streaming away and back")
	_check(playground.player.global_position.is_equal_approx(original_position), "Restore must return the player to the exact saved position")
	_check(int(playground.crop_registry.get_crop(crop_stable_id).get("growth_stage", -1)) == 1, "Crop registry restores the saved growth stage")
	var restored_crop: Node = restored_root.get_node_or_null("CropPlot_0") if restored_root != null else null
	_check(restored_crop != null and str(restored_crop.get("stable_id")) == crop_stable_id, "Reloaded chunk reconstructs the same stable crop ID")
	_check(restored_crop != null and str(restored_crop.get("status_text")).contains("1/4"), "Reloaded crop visual reflects saved growth stage")

	var bad_save: Dictionary = save_payload.duplicate(true)
	bad_save["schema_version"] = 99
	var before_position: Vector3 = playground.player.global_position
	var before_ids: PackedStringArray = playground.chunk_controller.get_loaded_chunk_ids()
	var before_saved_ids: PackedStringArray = playground.registry.get_saved_ids()
	var before_units: int = int(restored_ore.get("remaining_units"))
	_check(not bool(playground.restore_stream_state(bad_save, now)), "Invalid schema must be rejected")
	_check(playground.player.global_position.is_equal_approx(before_position), "Rejected save must not change player position")
	_check(playground.chunk_controller.get_loaded_chunk_ids() == before_ids, "Rejected save must not change active chunks")
	_check(playground.registry.get_saved_ids() == before_saved_ids, "Rejected save must not change registry IDs")
	_check(int(restored_ore.get("remaining_units")) == before_units, "Rejected save must not change live mineral stock")
	var before_crop_record: Dictionary = playground.crop_registry.get_crop(crop_stable_id)
	var bad_crop_save: Dictionary = save_payload.duplicate(true)
	var bad_crop_payload: Dictionary = bad_crop_save.get("crops", {}).duplicate(true)
	var bad_crop_records: Dictionary = bad_crop_payload.get("crops", {}).duplicate(true)
	var invalid_crop_record: Dictionary = bad_crop_records[crop_stable_id].duplicate(true)
	invalid_crop_record["crop_id"] = "unknown_crop"
	bad_crop_records[crop_stable_id] = invalid_crop_record
	bad_crop_payload["crops"] = bad_crop_records
	bad_crop_save["crops"] = bad_crop_payload
	_check(not bool(playground.restore_stream_state(bad_crop_save, now)), "Invalid crop payload must be rejected before streaming mutation")
	_check(playground.player.global_position.is_equal_approx(before_position), "Rejected crop payload must preserve player position")
	_check(playground.chunk_controller.get_loaded_chunk_ids() == before_ids, "Rejected crop payload must preserve active chunk IDs")
	_check(playground.registry.get_saved_ids() == before_saved_ids, "Rejected crop payload must preserve mineral registry IDs")
	_check(int(restored_ore.get("remaining_units")) == before_units, "Rejected crop payload must preserve live mineral stock")
	_check(playground.crop_registry.get_crop(crop_stable_id) == before_crop_record, "Rejected crop payload must preserve existing crop state")

	# A structurally valid restore can still fail when the requested chunk cannot be
	# generated. The live mineral stock and previous active window must survive that failure.
	restored_ore.set("remaining_units", 5)
	restored_ore.set("last_regen_unix", now)
	var target_restore: Dictionary = save_payload.duplicate(true)
	target_restore["player_position"] = [21.0, 2.0, 1.0]
	_fail_factory_coordinate = Vector2i(3, -1)
	_check(bool(playground.director.bind_chunk_factory(Callable(self, "_make_fault_injected_chunk"))), "Fault-injected factory should bind")
	var failed_restore_ok: bool = bool(playground.restore_stream_state(target_restore, now))
	_check(not failed_restore_ok, "Restore must fail when a required target chunk cannot be generated")
	var restore_report: Dictionary = playground.get_last_restore_report()
	_check(str(restore_report.get("phase", "")) == "stream_sync", "Restore failure should report the streaming phase")
	_check(bool(restore_report.get("rollback_complete", false)), "Failed restore should report a complete rollback when recovery succeeds")
	_check(playground.player.global_position.is_equal_approx(before_position), "Failed restore must restore the prior player position")
	_check(playground.chunk_controller.get_loaded_chunk_ids() == before_ids, "Failed restore must restore the prior active chunk IDs")
	_check(playground.director.get_managed_chunk_ids() == before_ids, "Failed restore must reconcile director IDs to the controller")
	_check(playground.registry.get_saved_ids() == before_saved_ids, "Failed restore must restore the prior saved vein ID set")
	_check(int(restored_ore.get("remaining_units")) == 5, "Failed restore must restore the pre-attempt live mineral stock")
	_check(int(playground.crop_registry.get_crop(crop_stable_id).get("growth_stage", -1)) == 1, "Failed stream restore must roll back crop registry state")
	var restore_details: Dictionary = restore_report.get("details", {})
	var target_report: Dictionary = restore_details.get("target_sync_report", {})
	_check(str(target_report.get("phase", "")) == "load_factory", "Diagnostic report should retain the original target-load failure")
	var target_details: Dictionary = target_report.get("details", {})
	_check(target_details.get("newly_loaded_ids", []).size() > 0, "Failure injection should occur after at least one target chunk was loaded")
	var legacy_crop_save: Dictionary = save_payload.duplicate(true)
	legacy_crop_save.erase("crops")
	_check(bool(playground.crop_controller.advance_crop(crop_stable_id, 120.0, now + 600)), "Crop can change before checking a legacy stream save")
	_check(int(playground.crop_registry.get_crop(crop_stable_id).get("growth_stage", -1)) == 2, "Legacy compatibility setup advances crop to stage two")
	_check(bool(playground.restore_stream_state(legacy_crop_save, now + 600)), "Older stream save without a crops field remains loadable")
	_check(int(playground.crop_registry.get_crop(crop_stable_id).get("growth_stage", -1)) == 2, "Legacy stream save without crop data preserves the current crop registry")
	var legacy_restored_root: Node3D = playground.chunk_controller.get_chunk_root("surface/chunk_0_0")
	var legacy_restored_crop: Node = legacy_restored_root.get_node_or_null("CropPlot_0") if legacy_restored_root != null else null
	_check(legacy_restored_crop != null and str(legacy_restored_crop.get("status_text")).contains("2/4"), "Legacy save load refreshes the preserved crop visual")
	playground.queue_free()
	await process_frame
	_finish()

func _make_fault_injected_chunk(coord: Vector2i) -> Node3D:
	if coord == _fail_factory_coordinate:
		return null
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	return chunk_root

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _finish() -> void:
	_finished = true
	if is_instance_valid(_watchdog_timer):
		_watchdog_timer.stop()
		_watchdog_timer.free()
	if _failed:
		print("Surface chunk streaming playground integration tests failed.")
		quit(1)
	else:
		print("Surface chunk streaming playground integration tests passed.")
		quit(0)
