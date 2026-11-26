extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SaveStoreScript = preload("res://systems/SurfaceWorldSaveStore.gd")
const SurfaceChunkFactoryScript = preload("res://systems/SurfaceChunkFactory.gd")
const ORIGIN_CHUNK_ID: String = "surface/chunk_0_0"

class PendingRegistryPairDirector extends Node:
	var pending: bool = true

	func has_pending_registry_pair_recovery() -> bool:
		return pending

	func get_pending_registry_pair_recovery_report() -> Dictionary:
		return {"recovery_required": pending, "reason": "injected_pair_recovery", "chunk_ids": ["underground/test_chunk"]}
var failures: Array[String] = []
var world: Node3D
var _promotion_fail_path: String = ""
var _fail_chunk_coord: Vector2i = Vector2i(999999, 999999)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = WorldScene.instantiate() as Node3D
	_expect(world != null, "surface world scene instantiates")
	if world == null:
		_finish(1)
		return
	root.add_child(world)
	await process_frame
	_expect(bool(world.call("initialize_world_session")), "surface world initializes shared session")
	var diagnostics_panel: Control = world.find_child("StreamingDiagnosticsPanel", true, false) as Control
	_expect(diagnostics_panel != null, "surface world embeds the streaming diagnostics panel")
	if diagnostics_panel != null:
		_expect(not diagnostics_panel.visible, "streaming diagnostics panel starts hidden")
		diagnostics_panel.call("toggle_open")
		_expect(diagnostics_panel.visible, "streaming diagnostics panel opens through its toggle API")
		diagnostics_panel.call("toggle_open")
		_expect(not diagnostics_panel.visible, "streaming diagnostics panel closes through its toggle API")
	var status: Dictionary = world.call("get_world_session_status")
	_expect(bool(status.get("ready", false)), "surface world reports ready")
	var ids: PackedStringArray = status.get("active_chunk_ids", PackedStringArray())
	_expect(ids.size() == 18, "surface world loads nine surface chunks plus a nine-chunk underground mine window")
	_expect(ids.has("underground/mine_0_0"), "active chunk IDs include the persistent underground mine")
	_expect(int(status.get("saved_vein_count", 0)) == 36, "nine surface veins plus twenty-seven underground mine veins are registered")
	_expect(world.chunk_controller.is_chunk_loaded("underground/mine_0_0"), "dedicated underground mine chunk loads with the playable surface world")
	var surface_crate_count: int = 0
	var terrain_patch_count: int = 0
	var underground_cache_count: int = 0
	var underground_lift_count: int = 0
	for prop in world.chunk_controller.get_loaded_world_state_nodes():
		if not is_instance_valid(prop):
			continue
		if prop.name == "MineLiftAnchor":
			underground_lift_count += 1
		elif str(prop.name).begins_with("TerrainPatch"):
			terrain_patch_count += 1
			_expect(prop.has_method("get_world_object_state"), "surface terrain patch participates in the world-object state contract")
		elif prop.global_position.y < -7.0:
			if str(prop.name).begins_with("MineCache_"):
				underground_cache_count += 1
		else:
			if str(prop.name).begins_with("SalvageCrate"):
				surface_crate_count += 1
	_expect(surface_crate_count == 9, "nine surface chunks retain one stable salvage crate each")
	_expect(terrain_patch_count == 63, "nine loaded surface chunks register seven persistent terrain patches each")
	_expect(underground_cache_count == 7, "nine-room underground window contributes two origin caches and five regional caches")
	_expect(underground_lift_count == 1, "origin underground chunk registers one stateful lift anchor")
	_expect(int(status.get("saved_world_object_count", 0)) == 80, "world-object registry counts nine crates, sixty-three terrain patches, seven underground caches and one mine lift")
	var initial_plots: Array[Node3D] = world.chunk_controller.get_loaded_crop_plots()
	_expect(initial_plots.size() == 18, "two crop plot visuals are bound per loaded chunk")
	_expect(int(status.get("saved_crop_count", 0)) == 0, "empty plots are not prematurely written as planted crop records")
	var origin: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var crate: Node = origin.get_node_or_null("SalvageCrate") if origin != null else null
	_expect(crate != null, "origin chunk creates a salvage crate")
	if crate == null:
		_finish(1)
		return
	_expect(origin.get_node_or_null("Ground") != null, "shared factory creates a collidable ground body")
	_expect(origin.get_node_or_null("Ore_0_0") != null, "shared factory creates the mineral node")
	_expect(origin.get_node_or_null("CropPlot_0") != null and origin.get_node_or_null("CropPlot_1") != null, "shared factory creates both crop plots")
	var original_id: int = crate.get_instance_id()
	var item_id: String = str(crate.get("loot_item_id"))
	var crate_position: Vector3 = crate.global_position
	var near_crate: Vector3 = crate_position + Vector3(0.0, 1.0, 2.0)
	world.player.global_position = near_crate
	world.camera.look_at(crate_position + Vector3(0.0, 0.55, 0.0), Vector3.UP)
	await physics_frame
	await physics_frame
	var now: int = int(Time.get_unix_time_from_system())
	var first: Dictionary = world.call("_interact_nearest_world_prop", now)
	_expect(bool(first.get("ok", false)), "salvage interaction grants an item through the shared inventory bridge")
	_expect(_inventory_count(item_id) == 1, "first interaction adds exactly one item")
	var save_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not save_payload.is_empty() and save_payload.has("world_objects") and save_payload.has("inventory"), "save contains world objects and inventory")
	_expect(bool(world.call("debug_move_player_to", Vector3(21.0, 2.0, 1.0), now + 1)), "moving away advances the chunk window")
	await process_frame
	_expect(not world.chunk_controller.is_chunk_loaded(ORIGIN_CHUNK_ID), "origin chunk unloads outside the radius")
	_expect(bool(world.call("debug_move_player_to", near_crate, now + 2)), "returning to origin reloads the chunk")
	await process_frame
	world.camera.look_at(crate_position + Vector3(0.0, 0.55, 0.0), Vector3.UP)
	await physics_frame
	await physics_frame
	var restored_root: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var restored_crate: Node = restored_root.get_node_or_null("SalvageCrate") if restored_root != null else null
	_expect(restored_crate != null, "factory recreates the crate")
	if restored_crate == null:
		_finish(1)
		return
	_expect(restored_crate.get_instance_id() != original_id, "reloaded crate is a fresh node instance")
	_expect(str(restored_crate.get("loot_item_id")) == item_id and int(restored_crate.get("loot_remaining")) == 1, "reloaded crate restores identity and remaining count")
	_expect(_inventory_count(item_id) == 1, "reload does not duplicate inventory")
	var second: Dictionary = world.call("_interact_nearest_world_prop", now + 3)
	_expect(bool(second.get("ok", false)) and int(second.get("remaining", -1)) == 0, "reloaded crate grants its final unit")
	_expect(_inventory_count(item_id) == 2, "second interaction increments inventory once")
	_expect(bool(world.call("restore_stream_state", save_payload, now + 4)), "world restores the saved snapshot")
	var save_root: Node3D = world.chunk_controller.get_chunk_root(ORIGIN_CHUNK_ID)
	var save_crate: Node = save_root.get_node_or_null("SalvageCrate") if save_root != null else null
	_expect(save_crate != null and int(save_crate.get("loot_remaining")) == 1, "save restore reapplies crate state")
	_expect(_inventory_count(item_id) == 1, "save restore rolls inventory back to the matching count")
	var plots: Array[Node3D] = world.chunk_controller.get_loaded_crop_plots()
	_expect(not plots.is_empty(), "surface world exposes loaded crop plots")
	if not plots.is_empty():
		var crop_approach_position: Vector3 = plots[0].global_position + Vector3(0.0, 1.0, 2.0)
		_expect(bool(world.call("debug_move_player_to", crop_approach_position, now + 5)), "test setup synchronously prepares the crop interaction chunk window")
		world.camera.look_at(plots[0].global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
		await physics_frame
		await physics_frame
		var crop_result: Dictionary = world.call("_interact_nearest_crop_plot", now + 5)
		_expect(bool(crop_result.get("ok", false)), "E interaction plants or advances a crop")
	var buttons: Dictionary = world.get("touch_buttons")
	_expect(buttons.has("forward") and buttons.has("jump") and buttons.has("crop") and buttons.has("crate") and buttons.has("shaft"), "HUD exposes touch movement, mining and mine-shaft controls")
	var directions: Dictionary = world.get("_touch_directions")
	buttons["forward"].emit_signal("button_down")
	_expect(directions.has("forward"), "touch button activates virtual forward input")
	buttons["forward"].emit_signal("button_up")
	_expect(not directions.has("forward"), "touch release clears virtual input")
	_test_world_save_recovery_gate(save_payload, now + 6)
	await _test_durable_save_load(now + 7)
	_finish(0 if failures.is_empty() else 1)

func _test_world_save_recovery_gate(save_payload: Dictionary, now_unix: int) -> void:
	var previous_mine_director: Node = world.get("mine_director") as Node
	var barrier_director := PendingRegistryPairDirector.new()
	root.add_child(barrier_director)
	world.set("mine_director", barrier_director)

	var live_crate: Node = null
	for candidate in world.chunk_controller.get_loaded_world_state_nodes():
		if is_instance_valid(candidate) and str(candidate.name).begins_with("SalvageCrate"):
			live_crate = candidate
			break
	_expect(live_crate != null, "save-gate fixture finds a loaded stateful crate")
	if live_crate != null:
		var live_state: Variant = live_crate.call("get_world_object_state")
		if live_state is Dictionary:
			var changed_state: Dictionary = live_state.duplicate(true)
			var was_opened: bool = bool(changed_state.get("opened", false))
			changed_state["opened"] = not was_opened
			if changed_state.has("loot_remaining"):
				# WorldObjectStatefulProp.MAX_LOOT is 2: a closed crate is full;
				# an opened crate has consumed at least one unit.
				changed_state["loot_remaining"] = 2 if was_opened else 1
			_expect(bool(live_crate.call("apply_world_object_state", changed_state)), "save-gate fixture creates an unsaved live object-state change")
		else:
			_expect(false, "save-gate fixture reads a valid live object-state dictionary")

	var before_minerals: Dictionary = world.chunk_controller.call("to_save_dict")
	var before_crops: Dictionary = world.crop_registry.call("to_save_dict")
	var before_objects: Dictionary = world.object_state_registry.call("to_save_dict")
	var before_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var before_position: Vector3 = world.player.global_position
	var before_seed: int = int(world.get("world_seed"))
	var before_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()

	var blocked_save: Dictionary = world.call("serialize_stream_state")
	_expect(blocked_save.is_empty(), "world serialization is refused while Registry-pair recovery is pending")
	_expect(world.object_state_registry.call("to_save_dict") == before_objects, "blocked save does not capture or mutate live world-object records")
	_expect(world.chunk_controller.call("to_save_dict") == before_minerals, "blocked save preserves mineral records")
	_expect(world.crop_registry.call("to_save_dict") == before_crops, "blocked save preserves crop records")
	_expect(world.inventory_bridge.call("serialize_inventory") == before_inventory, "blocked save preserves inventory")

	var blocked_restore_payload: Dictionary = save_payload.duplicate(true)
	blocked_restore_payload["world_seed"] = before_seed + 1
	_expect(not bool(world.call("restore_stream_state", blocked_restore_payload, now_unix)), "world restore is refused before any streaming or seed mutation")
	var restore_report: Dictionary = world.call("get_last_restore_report")
	_expect(str(restore_report.get("phase", "")) == "registry_pair_recovery_barrier" and not bool(restore_report.get("rollback_complete", true)), "blocked restore exposes the pending pair barrier and incomplete status")
	_expect(world.chunk_controller.call("to_save_dict") == before_minerals, "blocked restore preserves mineral records")
	_expect(world.crop_registry.call("to_save_dict") == before_crops, "blocked restore preserves crop records")
	_expect(world.object_state_registry.call("to_save_dict") == before_objects, "blocked restore preserves world-object records")
	_expect(world.inventory_bridge.call("serialize_inventory") == before_inventory, "blocked restore preserves inventory")
	_expect(world.player.global_position.is_equal_approx(before_position) and int(world.get("world_seed")) == before_seed, "blocked restore preserves player position and world seed")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == before_ids, "blocked restore does not alter the active chunk window")

	world.set("mine_director", previous_mine_director)
	barrier_director.queue_free()
	var resumed_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not resumed_payload.is_empty(), "world serialization resumes after the original Director is restored")

	var missing_api_director := Node.new()
	root.add_child(missing_api_director)
	world.set("mine_director", missing_api_director)
	var missing_api_payload: Dictionary = world.call("serialize_stream_state")
	_expect(missing_api_payload.is_empty(), "save capture fails closed when the underground Director lacks the recovery API")
	world.set("mine_director", previous_mine_director)
	missing_api_director.queue_free()

func _inventory_count(item_id: String) -> int:
	var payload: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var counts: Dictionary = payload.get("inventory", {})
	return int(counts.get(item_id, 0))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish(exit_code: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if exit_code == 0 and failures.is_empty():
		print("Production surface world integration tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _test_durable_save_load(now_unix: int) -> void:
	var path: String = "user://production_surface_world_save_test.json"
	var blocked_path: String = "user://production_surface_world_save_blocked_test.json"
	var promotion_path: String = "user://production_surface_world_save_promotion_test.json"
	_cleanup_save_test_files(path)
	_cleanup_save_test_files(blocked_path)
	_cleanup_save_test_files(promotion_path)

	_expect(bool(world.inventory_bridge.call("collect_world_item", "berries", 3)), "production save fixture adds initial inventory")
	var stamina_model: RefCounted = world.get("stamina") as RefCounted
	var quick_use_model: RefCounted = world.get("quick_use") as RefCounted
	stamina_model.set("current_stamina", 42.5)
	_expect(bool(quick_use_model.call("select_slot", 2)), "production save fixture selects the third quick-use slot")
	var payload_a: Dictionary = world.call("serialize_stream_state")
	_expect(bool(world.call("save_game", path)), "production SurfaceWorld writes a versioned disk save")
	var primary_a: String = FileAccess.get_file_as_string(path)
	var decoded_a: Dictionary = SaveStoreScript.decode_envelope(primary_a)
	_expect(bool(decoded_a.get("ok", false)) and int(decoded_a.get("envelope", {}).get("format_version", 0)) == 1, "production save uses the explicit envelope version 1")
	_expect(bool(_write_test_text(path + ".tmp", "interrupted temporary write")), "test creates a stale interrupted temp file")

	_expect(bool(world.inventory_bridge.call("collect_world_item", "berries", 2)), "production save fixture advances inventory before second save")
	stamina_model.set("current_stamina", 31.5)
	_expect(bool(quick_use_model.call("select_slot", 1)), "production save fixture changes selected quick-use slot")
	var payload_b: Dictionary = world.call("serialize_stream_state")
	_expect(bool(world.call("save_game", path)), "second save replaces the primary after validating a temp copy")
	_expect(not FileAccess.file_exists(path + ".tmp"), "successful save removes the interrupted temp file")
	var backup_a: Dictionary = SaveStoreScript.read_valid_file(path + ".bak", Callable(world, "_validate_world_save_payload"))
	_expect(bool(backup_a.get("ok", false)), "second save preserves the prior valid primary as backup")
	if bool(backup_a.get("ok", false)):
		_expect(backup_a.get("payload", {}).get("inventory", {}).get("inventory", {}).get("berries", -1) == payload_a.get("inventory", {}).get("inventory", {}).get("berries", -2), "backup retains the first save's inventory snapshot")

	world.queue_free()
	await process_frame
	world = WorldScene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	_expect(bool(world.call("get_world_session_status").get("ready", false)), "fresh production SurfaceWorld instance initializes before disk restore")
	_expect(bool(world.call("load_game", path)), "production SurfaceWorld loads its primary save after a simulated restart")
	_expect(_inventory_count("berries") == 5, "restart restore recovers the primary inventory count")
	var restored_stamina: RefCounted = world.get("stamina") as RefCounted
	var restored_quick_use: RefCounted = world.get("quick_use") as RefCounted
	_expect(is_equal_approx(float(restored_stamina.get("current_stamina")), 31.5), "restart restore recovers stamina")
	_expect(int(restored_quick_use.get("selected_slot")) == 1, "restart restore recovers the selected quick-use slot")
	var primary_report: Dictionary = world.call("get_last_save_report")
	_expect(str(primary_report.get("phase", "")) == "loaded_from_primary", "primary load reports its source explicitly")
	await _test_failed_restore_stream_rollback(now_unix + 8)

	_expect(_write_test_text(path, "{corrupt-primary"), "test corrupts the primary save")
	_expect(bool(world.call("load_game", path)), "valid backup is restored when the primary is corrupt")
	_expect(_inventory_count("berries") == 3, "backup recovery restores the previous valid inventory")
	var backup_stamina: RefCounted = world.get("stamina") as RefCounted
	var backup_quick_use: RefCounted = world.get("quick_use") as RefCounted
	_expect(is_equal_approx(float(backup_stamina.get("current_stamina")), 42.5), "backup recovery restores the previous stamina")
	_expect(int(backup_quick_use.get("selected_slot")) == 2, "backup recovery restores the previous quick-use selection")
	var archive_found: bool = false
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory != null:
		for filename in user_directory.get_files():
			if filename.begins_with(path.get_file() + ".corrupt."):
				archive_found = true
				break
	_expect(archive_found, "corrupt primary is preserved in a diagnostic archive")
	var promoted_primary: Dictionary = SaveStoreScript.read_valid_file(path, Callable(world, "_validate_world_save_payload"))
	_expect(bool(promoted_primary.get("ok", false)), "validated backup is promoted to the primary path after successful world restore")

	var invalid_path: String = "user://production_surface_world_invalid_save_test.json"
	_cleanup_save_test_files(invalid_path)
	_expect(_write_test_text(invalid_path, "not-json") and _write_test_text(invalid_path + ".bak", "{also-not-json"), "test prepares invalid primary and backup envelopes")
	var before_invalid_position: Vector3 = world.player.global_position
	var before_invalid_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var invalid_primary_bytes: String = FileAccess.get_file_as_string(invalid_path)
	var invalid_backup_bytes: String = FileAccess.get_file_as_string(invalid_path + ".bak")
	_expect(not bool(world.call("load_game", invalid_path)), "invalid primary and backup are rejected without restore")
	_expect(world.player.global_position.is_equal_approx(before_invalid_position), "invalid envelopes preserve player position")
	_expect(world.inventory_bridge.call("serialize_inventory") == before_invalid_inventory, "invalid envelopes preserve inventory")
	_expect(FileAccess.get_file_as_string(invalid_path) == invalid_primary_bytes and FileAccess.get_file_as_string(invalid_path + ".bak") == invalid_backup_bytes, "invalid envelopes are preserved byte-for-byte for diagnosis")
	var invalid_stream_payload: Dictionary = world.call("serialize_stream_state")
	invalid_stream_payload["minerals"] = {"schema_version": 1, "veins": []}
	var before_invalid_stream_position: Vector3 = world.player.global_position
	var before_invalid_stream_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	_expect(not bool(world.call("restore_stream_state", invalid_stream_payload, now_unix + 9)), "invalid mineral payload is rejected by complete restore preflight")
	var invalid_stream_report: Dictionary = world.call("get_last_restore_report")
	_expect(str(invalid_stream_report.get("phase", "")) == "payload_validation", "invalid restore reports preflight rejection before streaming")
	_expect(world.player.global_position.is_equal_approx(before_invalid_stream_position) and world.chunk_controller.get_loaded_chunk_ids() == before_invalid_stream_ids, "invalid restore preflight preserves player position and active chunks")

	_expect(bool(world.call("save_game", blocked_path)), "recovery-barrier test prepares an existing valid disk save")
	var blocked_primary_before: String = FileAccess.get_file_as_string(blocked_path)
	var original_mine_director: Node = world.get("mine_director") as Node
	var pending_director := PendingRegistryPairDirector.new()
	root.add_child(pending_director)
	world.set("mine_director", pending_director)
	_expect(not bool(world.call("save_game", blocked_path)), "pending Registry-pair recovery blocks manual disk writes")
	_expect(not bool(world.call("load_game", blocked_path)), "pending Registry-pair recovery blocks disk reads and restores")
	_expect(FileAccess.get_file_as_string(blocked_path) == blocked_primary_before, "blocked save and load preserve existing primary bytes")
	_expect(not FileAccess.file_exists(blocked_path + ".tmp"), "blocked save does not create a temporary file")
	world.set("mine_director", original_mine_director)
	pending_director.queue_free()

	var locked_chunk_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	if not locked_chunk_ids.is_empty():
		var locked_chunk_id: String = str(locked_chunk_ids[0])
		var lock_token: String = "surface-save-barrier-test"
		_expect(bool(world.object_state_registry.call("lock_chunk_writes", locked_chunk_id, lock_token)), "test acquires an active WorldObject chunk write lease")
		var lock_primary_before: String = FileAccess.get_file_as_string(blocked_path)
		_expect(not bool(world.call("save_game", blocked_path)), "active WorldObject write lease blocks manual save")
		_expect(not bool(world.call("load_game", blocked_path)), "active WorldObject write lease blocks disk restore")
		_expect(FileAccess.get_file_as_string(blocked_path) == lock_primary_before, "active WorldObject write lease preserves existing save bytes")
		_expect(bool(world.object_state_registry.call("unlock_chunk_writes", locked_chunk_id, lock_token)), "test releases the WorldObject chunk write lease")

	var mineral_registry: Node = world.get("registry") as Node
	var previous_pending_recovery: Dictionary = mineral_registry.get("_pending_atomic_registration_recovery")
	mineral_registry.set("_pending_atomic_registration_recovery", {"test_fixture": true})
	var mineral_barrier_bytes: String = FileAccess.get_file_as_string(blocked_path)
	_expect(not bool(world.call("save_game", blocked_path)), "pending Mineral Registry recovery blocks manual save")
	_expect(not bool(world.call("load_game", blocked_path)), "pending Mineral Registry recovery blocks disk restore")
	_expect(FileAccess.get_file_as_string(blocked_path) == mineral_barrier_bytes, "pending Mineral Registry recovery preserves the existing save")
	mineral_registry.set("_pending_atomic_registration_recovery", previous_pending_recovery)

	_expect(bool(world.call("save_game", promotion_path)), "promotion-failure test creates an initial valid save")
	_expect(bool(world.inventory_bridge.call("collect_world_item", "berries", 1)), "promotion-failure fixture advances the live inventory")
	_expect(bool(world.call("save_game", promotion_path)), "promotion-failure test creates a valid backup")
	var last_valid_primary: String = FileAccess.get_file_as_string(promotion_path)
	_expect(bool(world.inventory_bridge.call("collect_world_item", "berries", 1)), "promotion-failure fixture prepares a newer candidate")
	var failed_promotion_payload: Dictionary = world.call("serialize_stream_state")
	var failed_promotion_envelope: Dictionary = SaveStoreScript.build_envelope(failed_promotion_payload, now_unix + 10)
	_promotion_fail_path = promotion_path
	var failed_promotion_report: Dictionary = SaveStoreScript.write_atomic(
		promotion_path,
		SaveStoreScript.encode_envelope(failed_promotion_envelope),
		Callable(world, "_validate_world_save_payload"),
		Callable(self, "_rename_fail_primary_promotion")
	)
	_expect(not bool(failed_promotion_report.get("ok", false)), "injected primary promotion failure is reported")
	_expect(not bool(failed_promotion_report.get("recovery_required", false)), "previous primary is restored after injected promotion failure")
	_expect(FileAccess.get_file_as_string(promotion_path) == last_valid_primary, "failed promotion preserves the last valid primary byte-for-byte")
	_expect(bool(SaveStoreScript.read_valid_file(promotion_path, Callable(world, "_validate_world_save_payload")).get("ok", false)), "last valid primary remains fully readable after failed promotion")
	var interrupted_candidate: Dictionary = world.call("serialize_stream_state")
	var interrupted_envelope: Dictionary = SaveStoreScript.build_envelope(interrupted_candidate, now_unix + 11)
	var interrupted_report: Dictionary = SaveStoreScript.write_atomic(
		promotion_path,
		SaveStoreScript.encode_envelope(interrupted_envelope),
		Callable(world, "_validate_world_save_payload"),
		Callable(self, "_rename_fail_primary_and_rollback")
	)
	_expect(not bool(interrupted_report.get("ok", false)) and bool(interrupted_report.get("recovery_required", false)), "injected promotion and rollback failure leaves an explicit recovery requirement")
	_expect(not FileAccess.file_exists(promotion_path) and FileAccess.file_exists(promotion_path + ".previous"), "interrupted promotion retains the staged previous primary")
	var recovered_file_report: Dictionary = SaveStoreScript.recover_interrupted_write(promotion_path, Callable(world, "_validate_world_save_payload"))
	_expect(bool(recovered_file_report.get("ok", false)), "interrupted promotion can be recovered from its validated previous primary")
	_expect(FileAccess.get_file_as_string(promotion_path) == last_valid_primary, "interrupted promotion recovery restores the last valid primary byte-for-byte")
	_promotion_fail_path = ""

	_cleanup_save_test_files(path)
	_cleanup_save_test_files(blocked_path)
	_cleanup_save_test_files(promotion_path)
	_cleanup_save_test_files(invalid_path)


func _test_failed_restore_stream_rollback(now_unix: int) -> void:
	var original_director: Node = world.get("director") as Node
	var original_position: Vector3 = world.player.global_position
	var original_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	var original_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var original_minerals: Dictionary = world.chunk_controller.call("to_save_dict")
	var target_position: Vector3 = original_position + Vector3(1200.0, 0.0, 1200.0)
	_fail_chunk_coord = original_director.get_grid_coordinate(target_position)
	_expect(bool(original_director.call("bind_chunk_factory", Callable(self, "_make_chunk_with_injected_failure"))), "restore rollback test installs a deterministic failing chunk factory")
	var candidate: Dictionary = world.call("serialize_stream_state")
	candidate["player_position"] = [target_position.x, target_position.y, target_position.z]
	var restored: bool = bool(world.call("restore_stream_state", candidate, now_unix))
	_expect(not restored, "failed target chunk streaming rejects the disk restore candidate")
	var report: Dictionary = world.call("get_last_restore_report")
	_expect(str(report.get("phase", "")) == "stream_sync" and bool(report.get("rollback_complete", false)), "failed target streaming reports a complete rollback")
	_expect(world.player.global_position.is_equal_approx(original_position), "failed target streaming restores the original player position")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == original_ids, "failed target streaming restores the original active chunk window")
	_expect(world.chunk_controller.call("to_save_dict") == original_minerals, "failed target streaming restores mineral records")
	_expect(world.inventory_bridge.call("serialize_inventory") == original_inventory, "failed target streaming preserves inventory")
	_expect(original_director.get_managed_chunk_ids() == world.chunk_controller.get_loaded_chunk_ids(), "failed target streaming leaves Director and Controller chunk sets consistent")
	_expect(bool(original_director.call("bind_chunk_factory", Callable(world, "_make_chunk"))), "restore rollback test reinstates the production chunk factory")
	_fail_chunk_coord = Vector2i(999999, 999999)

func _make_chunk_with_injected_failure(coord: Vector2i) -> Node3D:
	if coord == _fail_chunk_coord:
		return null
	return SurfaceChunkFactoryScript.make_chunk(coord, int(world.get("_stream_clock_unix")))


func _write_test_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var success: bool = file.get_error() == OK
	file.close()
	return success

func _cleanup_save_test_files(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".previous", ".restore.tmp"]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return
	var prefix: String = path.get_file() + ".corrupt."
	for filename in directory.get_files():
		if filename.begins_with(prefix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + filename))

func _rename_fail_primary_and_rollback(source_absolute: String, destination_absolute: String) -> int:
	var primary_absolute: String = ProjectSettings.globalize_path(_promotion_fail_path)
	if destination_absolute == primary_absolute and (source_absolute.ends_with(".tmp") or source_absolute.ends_with(".previous")):
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(source_absolute, destination_absolute)


func _rename_fail_primary_promotion(source_absolute: String, destination_absolute: String) -> int:
	var primary_absolute: String = ProjectSettings.globalize_path(_promotion_fail_path)
	if destination_absolute == primary_absolute and source_absolute.ends_with(".tmp"):
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(source_absolute, destination_absolute)

