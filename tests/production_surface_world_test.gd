extends SceneTree

const WorldScene = preload("res://world/SurfaceWorld.tscn")
const SaveStoreScript = preload("res://systems/SurfaceWorldSaveStore.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const TerrainPatchScript = preload("res://systems/SurfaceTerrainPatch.gd")
const MineLiftScript = preload("res://systems/UndergroundMineLift.gd")
const SurfaceChunkFactoryScript = preload("res://systems/SurfaceChunkFactory.gd")
const ORIGIN_CHUNK_ID: String = "surface/chunk_0_0"

class PendingRegistryPairDirector extends Node:
	var pending: bool = true

	func has_pending_registry_pair_recovery() -> bool:
		return pending

	func get_pending_registry_pair_recovery_report() -> Dictionary:
		return {"recovery_required": pending, "reason": "injected_pair_recovery", "chunk_ids": ["underground/test_chunk"]}

class MissingRegistryPairRecoveryApi extends Node:
	pass
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
	_test_world_object_json_numeric_variants()
	await _test_world_recovery_snapshot_comparison()
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

func _test_reserved_save_base_paths() -> void:
	var validator := Callable(world, "_validate_world_save_payload")
	var reserved_paths: Array[String] = [
		"user://run454_reserved_primary.tmp",
		"user://run454_reserved_primary.bak",
		"user://run454_reserved_primary.bak.tmp",
		"user://run454_reserved_primary.previous",
		"user://run454_reserved_primary.restore.tmp",
		"user://run454_reserved_primary.corrupt.123",
		"user://run454_reserved_directory.bak/slot.json"
	]
	for reserved_path in reserved_paths:
		var write_report: Dictionary = SaveStoreScript.write_atomic(reserved_path, "{}", validator)
		_expect(not bool(write_report.get("ok", false)) and str(write_report.get("phase", "")) == "path_preflight" and str(write_report.get("reason", "")) == "unsupported_save_path", "writer rejects reserved save-family base path: " + reserved_path)
		var recovery_report: Dictionary = SaveStoreScript.recover_interrupted_write(reserved_path, validator)
		_expect(not bool(recovery_report.get("ok", false)) and str(recovery_report.get("reason", "")) == "unsupported_save_path", "interrupted-write recovery rejects reserved sidecar base path: " + reserved_path)
		var promotion_report: Dictionary = SaveStoreScript.promote_backup(reserved_path, validator)
		_expect(not bool(promotion_report.get("ok", false)) and str(promotion_report.get("phase", "")) == "path_preflight" and str(promotion_report.get("reason", "")) == "unsupported_save_path", "backup promotion rejects reserved sidecar base path: " + reserved_path)


func _test_save_path_symlink_guards() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	_expect(user_directory != null, "open user data for save-path symlink tests")
	if user_directory == null:
		return
	var target_directory: String = "user://run451_symlink_target"
	if user_directory.is_link("run451_symlink_directory"):
		user_directory.remove("run451_symlink_directory")
	if user_directory.is_link("run451_symlink_file.json"):
		user_directory.remove("run451_symlink_file.json")
	var target_directory_absolute: String = ProjectSettings.globalize_path(target_directory)
	var target_directory_error: Error = DirAccess.make_dir_recursive_absolute(target_directory_absolute)
	_expect(target_directory_error == OK or DirAccess.dir_exists_absolute(target_directory_absolute), "create a symlink test target directory")
	var target_file_path: String = target_directory + "/existing.json"
	_expect(_write_test_text(target_file_path, "protected-target-bytes"), "write a file behind the directory symlink")
	var directory_link_name: String = "run451_symlink_directory"
	var directory_link_error: Error = user_directory.create_link(target_directory_absolute, directory_link_name)
	if directory_link_error != OK and OS.get_name() == "Windows":
		print("SKIP: symbolic-link regression fixture requires Windows Developer Mode or elevated privileges.")
		_cleanup_save_test_files(target_file_path)
		DirAccess.remove_absolute(target_directory_absolute)
		return
	_expect(directory_link_error == OK, "create a directory symlink inside user data")
	if directory_link_error == OK:
		var nested_write: Dictionary = SaveStoreScript.write_atomic(
			"user://" + directory_link_name + "/new_save.json",
			"{}",
			Callable(world, "_validate_world_save_payload")
		)
		_expect(not bool(nested_write.get("ok", false)) and str(nested_write.get("phase", "")) == "path_symlink", "writer rejects a save path beneath a directory symlink")
		var nested_read: Dictionary = SaveStoreScript.read_valid_file(
			"user://" + directory_link_name + "/existing.json",
			Callable(world, "_validate_world_save_payload")
		)
		_expect(not bool(nested_read.get("ok", false)) and str(nested_read.get("reason", "")) == "path_symlink", "reader rejects a path beneath a directory symlink")
		_expect(FileAccess.get_file_as_string(target_file_path) == "protected-target-bytes", "directory-symlink rejection preserves target bytes")
		user_directory.remove(directory_link_name)
	_cleanup_save_test_files(target_file_path)
	DirAccess.remove_absolute(target_directory_absolute)

	var direct_target: String = "user://run451_symlink_file_target.json"
	var direct_link_name: String = "run451_symlink_file.json"
	_expect(_write_test_text(direct_target, "protected-direct-file-bytes"), "write direct file-symlink target")
	var direct_link_error: Error = user_directory.create_link(ProjectSettings.globalize_path(direct_target), direct_link_name)
	if direct_link_error != OK and OS.get_name() == "Windows":
		print("SKIP: direct file-symlink fixture requires Windows Developer Mode or elevated privileges.")
		_cleanup_save_test_files(direct_target)
		return
	_expect(direct_link_error == OK, "create a direct file symlink inside user data")
	if direct_link_error == OK:
		var direct_path: String = "user://" + direct_link_name
		var direct_read: Dictionary = SaveStoreScript.read_valid_file(direct_path, Callable(world, "_validate_world_save_payload"))
		_expect(not bool(direct_read.get("ok", false)) and str(direct_read.get("reason", "")) == "path_symlink", "reader rejects a direct file symlink")
		var direct_write: Dictionary = SaveStoreScript.write_atomic(direct_path, "{}", Callable(world, "_validate_world_save_payload"))
		_expect(not bool(direct_write.get("ok", false)) and str(direct_write.get("phase", "")) == "path_symlink", "writer rejects a direct file symlink")
		_expect(FileAccess.get_file_as_string(direct_target) == "protected-direct-file-bytes", "direct-file-symlink rejection preserves target bytes")
		user_directory.remove(direct_link_name)
	_cleanup_save_test_files(direct_target)


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

func _test_world_recovery_snapshot_comparison() -> void:
	var expected_snapshot: Dictionary = world.call("serialize_stream_state")
	_expect(not expected_snapshot.is_empty(), "world recovery comparison captures a complete expected snapshot")
	_expect(bool(world.call("_world_recovery_matches_snapshot", expected_snapshot, expected_snapshot)), "world recovery comparison accepts an unchanged full snapshot")

	var changed_snapshot: Dictionary = expected_snapshot.duplicate(true)
	var mineral_payload: Dictionary = changed_snapshot.get("minerals", {})
	var veins: Dictionary = mineral_payload.get("veins", {})
	var mineral_ids: Array = veins.keys()
	_expect(not mineral_ids.is_empty(), "world recovery comparison fixture contains at least one mineral record")
	if not mineral_ids.is_empty():
		var stable_id: String = str(mineral_ids[0])
		var record: Dictionary = veins[stable_id].duplicate(true)
		var remaining_units: int = int(record.get("remaining_units", 0))
		var max_units: int = int(record.get("max_units", remaining_units + 1))
		if remaining_units < max_units:
			record["remaining_units"] = remaining_units + 1
		else:
			record["remaining_units"] = max(0, remaining_units - 1)
		veins[stable_id] = record
		mineral_payload["veins"] = veins
		changed_snapshot["minerals"] = mineral_payload
		_expect(bool(world.call("_validate_world_save_payload", changed_snapshot)), "changed mineral record remains a valid save payload")
		_expect(not bool(world.call("_world_recovery_matches_snapshot", changed_snapshot, expected_snapshot)), "world recovery comparison rejects changed mineral values even when stable IDs match")

	var exact_now: int = int(Time.get_unix_time_from_system())
	var exact_snapshot: Dictionary = expected_snapshot.duplicate(true)
	var exact_minerals: Dictionary = exact_snapshot.get("minerals", {})
	var exact_veins: Dictionary = exact_minerals.get("veins", {})
	var live_mineral_ids: PackedStringArray = world.chunk_controller.registry.call("get_registered_ids")
	var exact_stable_id: String = ""
	for raw_id in live_mineral_ids:
		var candidate_id: String = str(raw_id)
		if candidate_id.begins_with("surface"):
			exact_stable_id = candidate_id
			break
	_expect(not exact_stable_id.is_empty(), "exact-time recovery fixture selects a currently loaded surface mineral")
	if exact_stable_id.is_empty():
		return
	_expect(exact_veins.has(exact_stable_id), "exact-time recovery fixture selects a mineral present in the full snapshot")
	if not exact_veins.has(exact_stable_id):
		return
	var vein_marker: String = "/vein/"
	var vein_marker_index: int = exact_stable_id.find(vein_marker)
	_expect(vein_marker_index > 0, "selected surface mineral ID contains its owning chunk marker")
	if vein_marker_index <= 0:
		return
	var exact_chunk_id: String = exact_stable_id.substr(0, vein_marker_index)
	var exact_record: Dictionary = exact_veins[exact_stable_id].duplicate(true)
	var regen_interval: int = maxi(1, int(exact_record.get("regen_interval_seconds", 60)))
	var expected_last_regen: int = exact_now - regen_interval * 2
	exact_record["remaining_units"] = 0
	exact_record["last_regen_unix"] = expected_last_regen
	exact_veins[exact_stable_id] = exact_record
	exact_minerals["veins"] = exact_veins
	exact_snapshot["minerals"] = exact_minerals
	_expect(bool(world.call("_validate_world_save_payload", exact_snapshot)), "depleted mineral recovery snapshot remains valid with an elapsed regeneration interval")

	_expect(bool(world.call("debug_move_player_to", Vector3(200.0, 2.0, 200.0), exact_now)), "test moves away from the captured surface chunk before exact recovery")
	await process_frame
	_expect(not world.chunk_controller.is_chunk_loaded(exact_chunk_id), "captured surface mineral chunk unloads before recovery retry")
	world.set("_save_recovery_barrier_report", {"recovery_required": true, "reason": "test_exact_mineral_snapshot"})
	world.set("_save_recovery_kind", "world")
	world.set("_save_recovery_path", "")
	world.set("_pending_save_recovery_payload", exact_snapshot.duplicate(true))
	world.set("_pending_save_recovery_now", exact_now)
	var retry_succeeded: bool = bool(world.call("retry_save_recovery"))
	if not retry_succeeded:
		var retry_barrier: Dictionary = world.get("_save_recovery_barrier_report")
		var retry_restore_report: Dictionary = world.call("get_last_restore_report")
		var retry_controller_report: Dictionary = world.chunk_controller.call("get_last_chunk_load_report")
		var retry_object_report: Dictionary = world.chunk_controller.call("get_last_world_object_restore_report")
		push_error("Exact-time recovery diagnostics: barrier=%s restore=%s controller=%s world_objects=%s" % [str(retry_barrier), str(retry_restore_report), str(retry_controller_report), str(retry_object_report)])
	_expect(retry_succeeded, "world recovery retry restores the captured mineral snapshot")
	var recovery_readback: Dictionary = world.call("serialize_stream_state")
	var recovery_readback_minerals: Dictionary = recovery_readback.get("minerals", {})
	var recovery_readback_veins: Dictionary = recovery_readback_minerals.get("veins", {})
	var recovery_record: Dictionary = recovery_readback_veins.get(exact_stable_id, {})
	_expect(recovery_readback.get("crops", {}) == exact_snapshot.get("crops", {}), "cross-window recovery readback restores the exact crop registry after streaming")
	_expect(recovery_readback.get("world_objects", {}) == exact_snapshot.get("world_objects", {}), "cross-window recovery readback removes stale old-window world-object records")
	_expect(recovery_readback_minerals == exact_minerals, "exact-time recovery readback preserves the complete mineral payload before offline catch-up")
	_expect(int(recovery_record.get("remaining_units", -1)) == 0 and int(recovery_record.get("last_regen_unix", -1)) == expected_last_regen, "exact-time recovery does not regenerate a depleted mineral before readback")
	_expect(bool(world.call("_world_recovery_matches_snapshot", recovery_readback, exact_snapshot)), "exact-time recovery readback matches the full captured world snapshot")

	_expect(bool(world.call("_restore_stream_state_with_snapshot", expected_snapshot, exact_now, expected_snapshot, true)), "test restores the original world snapshot using exact mineral restoration")
	var restored_original: Dictionary = world.call("serialize_stream_state")
	_expect(bool(world.call("_world_recovery_matches_snapshot", restored_original, expected_snapshot)), "test fixture leaves the original world state fully restored")

func _test_world_object_json_numeric_variants() -> void:
	var crate: Node = StatefulPropScript.new()
	_expect(bool(crate.call("validate_world_object_state", {"opened": false, "loot_remaining": 2.0, "loot_item_id": "iron_ore"})), "salvage crate accepts integral JSON numeric loot counts")
	_expect(not bool(crate.call("validate_world_object_state", {"opened": true, "loot_remaining": 1.5, "loot_item_id": "iron_ore"})), "salvage crate rejects fractional loot counts")
	crate.free()

	var patch: Node = TerrainPatchScript.new()
	_expect(bool(patch.call("validate_world_object_state", {"height_level": 0.0, "surface_type": "soil", "revision": 0.0})), "terrain patch accepts integral JSON numeric height and revision")
	_expect(not bool(patch.call("validate_world_object_state", {"height_level": 0.5, "surface_type": "soil", "revision": 0.0})), "terrain patch rejects fractional height values")
	_expect(not bool(patch.call("validate_world_object_state", {"height_level": 0.0, "surface_type": "soil", "revision": 0.5})), "terrain patch rejects fractional revision values")
	patch.free()

	var lift: Node = MineLiftScript.new()
	_expect(bool(lift.call("validate_world_object_state", {"layer_index": float(lift.get("layer_index"))})), "mine lift accepts integral JSON numeric layer indices")
	_expect(not bool(lift.call("validate_world_object_state", {"layer_index": 0.5})), "mine lift rejects fractional layer indices")
	lift.free()


func _test_durable_save_load(now_unix: int) -> void:
	var path: String = "user://production_surface_world_save_test.json"
	var blocked_path: String = "user://production_surface_world_save_blocked_test.json"
	var promotion_path: String = "user://production_surface_world_save_promotion_test.json"
	var interrupted_path: String = "user://production_surface_world_interrupted_restart_test.json"
	_cleanup_save_test_files(path)
	_cleanup_save_test_files(blocked_path)
	_cleanup_save_test_files(promotion_path)
	_cleanup_save_test_files(interrupted_path)

	_expect(bool(world.inventory_bridge.call("collect_world_item", "berries", 3)), "production save fixture adds initial inventory")
	var stamina_model: RefCounted = world.get("stamina") as RefCounted
	var quick_use_model: RefCounted = world.get("quick_use") as RefCounted
	stamina_model.set("current_stamina", 42.5)
	_expect(bool(quick_use_model.call("select_slot", 2)), "production save fixture selects the third quick-use slot")
	var numeric_stamina: Dictionary = stamina_model.call("to_save_dict")
	numeric_stamina["schema_version"] = float(numeric_stamina.get("schema_version", 1))
	_expect(bool(stamina_model.call("validate_save_dict", numeric_stamina)), "stamina validator accepts integer-valued JSON schema numbers")
	var numeric_quick_use: Dictionary = quick_use_model.call("to_save_dict")
	numeric_quick_use["schema_version"] = float(numeric_quick_use.get("schema_version", 1))
	numeric_quick_use["selected_slot"] = float(numeric_quick_use.get("selected_slot", 0))
	_expect(bool(quick_use_model.call("validate_save_dict", numeric_quick_use)), "quick-use validator accepts integer-valued JSON schema and slot numbers")
	var json_numeric_payload: Dictionary = world.call("serialize_stream_state")
	json_numeric_payload["schema_version"] = float(json_numeric_payload.get("schema_version", 1))
	json_numeric_payload["mine_depth"] = float(json_numeric_payload.get("mine_depth", 0))
	_expect(bool(world.call("_validate_world_save_payload", json_numeric_payload)), "SurfaceWorld accepts whole-valued JSON schema and mine-depth numbers")
	_expect(bool(world.call("restore_stream_state", json_numeric_payload, now_unix)), "SurfaceWorld direct restore accepts whole-valued JSON schema and mine-depth numbers")
	var fractional_schema_payload: Dictionary = json_numeric_payload.duplicate(true)
	fractional_schema_payload["schema_version"] = 1.5
	_expect(not bool(world.call("_validate_world_save_payload", fractional_schema_payload)), "SurfaceWorld rejects fractional stream schema values")
	var fractional_depth_payload: Dictionary = json_numeric_payload.duplicate(true)
	fractional_depth_payload["mine_depth"] = 0.5
	_expect(not bool(world.call("_validate_world_save_payload", fractional_depth_payload)), "SurfaceWorld rejects fractional mine-depth values")
	var numeric_path: String = "user://production_surface_world_json_numeric_test.json"
	_cleanup_save_test_files(numeric_path)
	var numeric_envelope: Dictionary = SaveStoreScript.build_envelope(json_numeric_payload, now_unix)
	_expect(_write_test_text(numeric_path, SaveStoreScript.encode_envelope(numeric_envelope)), "write a JSON-decoded numeric compatibility fixture")
	var numeric_file_report: Dictionary = SaveStoreScript.read_valid_file(numeric_path, Callable(world, "_validate_world_save_payload"))
	_expect(bool(numeric_file_report.get("ok", false)), "file reader validates whole-valued JSON numbers after parsing")
	_cleanup_save_test_files(numeric_path)

	var order_a: Dictionary = {}
	order_a["alpha"] = 1
	order_a["beta"] = 2
	var order_b: Dictionary = {}
	order_b["beta"] = 2
	order_b["alpha"] = 1
	var envelope_order_a: Dictionary = SaveStoreScript.build_envelope(order_a, now_unix)
	var envelope_order_b: Dictionary = SaveStoreScript.build_envelope(order_b, now_unix)
	_expect(str(envelope_order_a.get("payload_sha256", "")) == str(envelope_order_b.get("payload_sha256", "")), "payload checksum is stable across Dictionary insertion order")
	_expect(bool(SaveStoreScript.decode_envelope(SaveStoreScript.encode_envelope(envelope_order_a)).get("ok", false)), "canonical envelope survives JSON encode and decode")
	var payload_a: Dictionary = world.call("serialize_stream_state")
	var first_save_ok: bool = bool(world.call("save_game", path))
	var first_save_report: Dictionary = world.call("get_last_save_report")
	_expect(first_save_ok, "production SurfaceWorld writes a versioned disk save: " + JSON.stringify(first_save_report))
	var primary_a: String = FileAccess.get_file_as_string(path)
	var decoded_a: Dictionary = SaveStoreScript.decode_envelope(primary_a)
	_expect(bool(decoded_a.get("ok", false)) and int(decoded_a.get("envelope", {}).get("format_version", 0)) == 1, "production save uses the explicit envelope version 1")
	var tampered_envelope: Dictionary = decoded_a.get("envelope", {}).duplicate(true)
	var tampered_payload: Dictionary = tampered_envelope.get("payload", {}).duplicate(true)
	tampered_payload["world_seed"] = int(tampered_payload.get("world_seed", 0)) + 1
	tampered_envelope["payload"] = tampered_payload
	var tampered_report: Dictionary = SaveStoreScript.decode_envelope(JSON.stringify(tampered_envelope))
	_expect(not bool(tampered_report.get("ok", false)) and str(tampered_report.get("reason", "")) == "payload_checksum_mismatch", "valid-looking payload tampering is rejected by the envelope checksum")
	_expect(not bool(SaveStoreScript.read_valid_file("res://forbidden_surface_world_save.json", Callable(world, "_validate_world_save_payload")).get("ok", false)), "save reader rejects paths outside user data")
	_test_reserved_save_base_paths()
	_test_save_path_symlink_guards()
	var unknown_version_envelope: Dictionary = {
		"format_id": "2126.surface_world",
		"format_version": 999,
		"saved_at_unix": now_unix,
		"payload": payload_a
	}
	var unknown_version_report: Dictionary = SaveStoreScript.decode_envelope(JSON.stringify(unknown_version_envelope))
	_expect(not bool(unknown_version_report.get("ok", false)) and str(unknown_version_report.get("reason", "")) == "unsupported_format_version", "unknown production save versions fail closed")
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
	var backup_bytes_before_collision: String = FileAccess.get_file_as_string(path + ".bak")
	var sidecar_collision_report: Dictionary = SaveStoreScript.write_atomic(path + ".bak", primary_a, Callable(world, "_validate_world_save_payload"))
	_expect(not bool(sidecar_collision_report.get("ok", false)) and str(sidecar_collision_report.get("phase", "")) == "path_preflight" and str(sidecar_collision_report.get("reason", "")) == "unsupported_save_path", "writer refuses to use another save family's .bak sidecar as a primary path")
	_expect(FileAccess.get_file_as_string(path + ".bak") == backup_bytes_before_collision, "rejected sidecar-path collision preserves the existing backup byte-for-byte")

	world.queue_free()
	await process_frame
	world = WorldScene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	_expect(bool(world.call("get_world_session_status").get("ready", false)), "fresh production SurfaceWorld instance initializes before disk restore")
	var primary_load_ok: bool = bool(world.call("load_game", path))
	if not primary_load_ok:
		push_error("Production primary load diagnostics: save=" + JSON.stringify(world.call("get_last_save_report")) + " restore=" + JSON.stringify(world.call("get_last_restore_report")) + " barrier=" + JSON.stringify(world.call("_get_world_save_recovery_barrier_report")))
	_expect(primary_load_ok, "production SurfaceWorld loads its primary save after a simulated restart")
	_expect(_inventory_count("berries") == int(payload_b.get("inventory", {}).get("inventory", {}).get("berries", 5)), "restart restore recovers the primary inventory count")
	var restored_stamina: RefCounted = world.get("stamina") as RefCounted
	var restored_quick_use: RefCounted = world.get("quick_use") as RefCounted
	_expect(is_equal_approx(float(restored_stamina.get("current_stamina")), 31.5), "restart restore recovers stamina")
	_expect(int(restored_quick_use.get("selected_slot")) == 1, "restart restore recovers the selected quick-use slot")
	var primary_report: Dictionary = world.call("get_last_save_report")
	_expect(str(primary_report.get("phase", "")) == "loaded_from_primary", "primary load reports its source explicitly")
	await _test_failed_restore_stream_rollback()

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
	_expect(_write_test_text(path + ".bak", "{corrupt-backup"), "test corrupts the existing backup while the primary remains valid")
	_expect(bool(world.call("save_game", path)), "valid primary can replace a corrupt backup without losing the primary")
	var backup_rotation_report: Dictionary = world.call("get_last_save_report")
	var backup_archive_path: String = str(backup_rotation_report.get("details", {}).get("backup_archive_path", ""))
	_expect(not backup_archive_path.is_empty() and FileAccess.file_exists(backup_archive_path), "corrupt backup is preserved in a diagnostic archive before rotation")

	var invalid_path: String = "user://production_surface_world_invalid_save_test.json"
	_cleanup_save_test_files(invalid_path)
	_expect(_write_test_text(invalid_path, "not-json") and _write_test_text(invalid_path + ".bak", "{also-not-json"), "test prepares invalid primary and backup envelopes")
	var before_invalid_position: Vector3 = world.player.global_position
	var before_invalid_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var before_invalid_minerals: Dictionary = world.chunk_controller.call("to_save_dict")
	var before_invalid_crops: Dictionary = world.crop_registry.call("to_save_dict")
	var before_invalid_objects: Dictionary = world.object_state_registry.call("to_save_dict")
	var before_invalid_stamina: Dictionary = world.stamina.call("to_save_dict")
	var before_invalid_quick_use: Dictionary = world.quick_use.call("to_save_dict")
	var before_invalid_seed: int = int(world.get("world_seed"))
	var before_invalid_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	var invalid_primary_bytes: String = FileAccess.get_file_as_string(invalid_path)
	var invalid_backup_bytes: String = FileAccess.get_file_as_string(invalid_path + ".bak")
	_expect(not bool(world.call("load_game", invalid_path)), "invalid primary and backup are rejected without restore")
	_expect(world.player.global_position.is_equal_approx(before_invalid_position) and int(world.get("world_seed")) == before_invalid_seed, "invalid envelopes preserve player position and world seed")
	_expect(world.inventory_bridge.call("serialize_inventory") == before_invalid_inventory, "invalid envelopes preserve inventory")
	_expect(world.chunk_controller.call("to_save_dict") == before_invalid_minerals, "invalid envelopes preserve mineral Registry")
	_expect(world.crop_registry.call("to_save_dict") == before_invalid_crops, "invalid envelopes preserve crop Registry")
	_expect(world.object_state_registry.call("to_save_dict") == before_invalid_objects, "invalid envelopes preserve world-object Registry")
	_expect(world.stamina.call("to_save_dict") == before_invalid_stamina and world.quick_use.call("to_save_dict") == before_invalid_quick_use, "invalid envelopes preserve stamina and quick-use state")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == before_invalid_ids, "invalid envelopes preserve the active chunk window")
	_expect(FileAccess.get_file_as_string(invalid_path) == invalid_primary_bytes and FileAccess.get_file_as_string(invalid_path + ".bak") == invalid_backup_bytes, "invalid envelopes are preserved byte-for-byte for diagnosis")
	var invalid_stream_payload: Dictionary = world.call("serialize_stream_state")
	invalid_stream_payload["minerals"] = {"schema_version": 1, "veins": []}
	var before_invalid_stream_position: Vector3 = world.player.global_position
	var before_invalid_stream_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	var before_invalid_stream_minerals: Dictionary = world.chunk_controller.call("to_save_dict")
	var before_invalid_stream_crops: Dictionary = world.crop_registry.call("to_save_dict")
	var before_invalid_stream_objects: Dictionary = world.object_state_registry.call("to_save_dict")
	var before_invalid_stream_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	_expect(not bool(world.call("restore_stream_state", invalid_stream_payload, now_unix + 9)), "invalid mineral payload is rejected by complete restore preflight")
	var invalid_stream_report: Dictionary = world.call("get_last_restore_report")
	_expect(str(invalid_stream_report.get("phase", "")) == "payload_validation", "invalid restore reports preflight rejection before streaming")
	_expect(world.player.global_position.is_equal_approx(before_invalid_stream_position) and world.chunk_controller.get_loaded_chunk_ids() == before_invalid_stream_ids, "invalid restore preflight preserves player position and active chunks")
	_expect(world.chunk_controller.call("to_save_dict") == before_invalid_stream_minerals and world.crop_registry.call("to_save_dict") == before_invalid_stream_crops, "invalid restore preflight preserves mineral and crop registries")
	_expect(world.object_state_registry.call("to_save_dict") == before_invalid_stream_objects and world.inventory_bridge.call("serialize_inventory") == before_invalid_stream_inventory, "invalid restore preflight preserves world-object Registry and inventory")

	_expect(bool(world.call("save_game", blocked_path)), "recovery-barrier test prepares an existing valid disk save")
	var blocked_primary_before: String = FileAccess.get_file_as_string(blocked_path)
	var blocked_registry_before_file_recovery: Dictionary = world.object_state_registry.call("to_save_dict")
	var previous_obstruction_absolute: String = ProjectSettings.globalize_path(blocked_path + ".previous")
	var previous_obstruction_error: Error = DirAccess.make_dir_recursive_absolute(previous_obstruction_absolute)
	_expect(previous_obstruction_error == OK or DirAccess.dir_exists_absolute(previous_obstruction_absolute), "create a previous-path obstruction for save recovery")
	_expect(not bool(world.call("save_game", blocked_path)), "save fails closed when interrupted-file recovery is obstructed")
	_expect(str(world.call("get_last_save_report").get("phase", "")) == "interrupted_write_recovery", "save reports the interrupted-file recovery phase")
	_expect(world.object_state_registry.call("to_save_dict") == blocked_registry_before_file_recovery, "file-recovery failure happens before live world-object capture")
	_expect(FileAccess.get_file_as_string(blocked_path) == blocked_primary_before, "file-recovery obstruction preserves the existing primary bytes")
	_expect(not FileAccess.file_exists(blocked_path + ".tmp"), "file-recovery obstruction creates no temporary save")
	DirAccess.remove_absolute(previous_obstruction_absolute)
	_expect(bool(world.call("retry_save_recovery")), "file-recovery barrier clears after the obstruction is removed")

	previous_obstruction_error = DirAccess.make_dir_recursive_absolute(previous_obstruction_absolute)
	_expect(previous_obstruction_error == OK or DirAccess.dir_exists_absolute(previous_obstruction_absolute), "recreate a previous-path obstruction for load recovery")
	_expect(not bool(world.call("load_game", blocked_path)), "load fails closed when interrupted-file recovery is obstructed")
	_expect(str(world.call("get_last_save_report").get("phase", "")) == "interrupted_write_recovery", "load reports the interrupted-file recovery phase")
	DirAccess.remove_absolute(previous_obstruction_absolute)
	_expect(bool(world.call("retry_save_recovery")), "load recovery barrier clears after the obstruction is removed")

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

	var missing_api_director := MissingRegistryPairRecoveryApi.new()
	root.add_child(missing_api_director)
	world.set("mine_director", missing_api_director)
	_expect(not bool(world.call("save_game", blocked_path)) and not bool(world.call("load_game", blocked_path)), "missing Underground Director recovery API fails closed for disk persistence")
	world.set("mine_director", original_mine_director)
	missing_api_director.queue_free()

	var original_registry: Node = world.get("registry") as Node
	var missing_registry_api := Node.new()
	root.add_child(missing_registry_api)
	world.set("registry", missing_registry_api)
	_expect(not bool(world.call("save_game", blocked_path)) and not bool(world.call("load_game", blocked_path)), "missing Mineral Registry recovery API fails closed for disk persistence")
	world.set("registry", original_registry)
	missing_registry_api.queue_free()

	var locked_chunk_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	if not locked_chunk_ids.is_empty():
		var locked_chunk_id: String = str(locked_chunk_ids[0])
		var lock_token: String = "surface-save-barrier-test"
		var lock_restore_payload: Dictionary = world.call("serialize_stream_state")
		_expect(bool(world.object_state_registry.call("lock_chunk_writes", locked_chunk_id, lock_token)), "test acquires an active WorldObject chunk write lease")
		_expect(not bool(world.call("restore_stream_state", lock_restore_payload, now_unix + 9)), "active WorldObject write lease blocks direct stream restore")
		_expect(str(world.call("get_last_restore_report").get("phase", "")) == "registry_pair_recovery_barrier", "active WorldObject write lease is reported as a restore barrier")
		_expect(world.call("serialize_stream_state").is_empty(), "active WorldObject write lease blocks new snapshots")
		var lock_primary_before: String = FileAccess.get_file_as_string(blocked_path)
		_expect(not bool(world.call("save_game", blocked_path)), "active WorldObject write lease blocks manual save")
		_expect(not bool(world.call("load_game", blocked_path)), "active WorldObject write lease blocks disk restore")
		_expect(FileAccess.get_file_as_string(blocked_path) == lock_primary_before, "active WorldObject write lease preserves existing save bytes")
		_expect(bool(world.object_state_registry.call("unlock_chunk_writes", locked_chunk_id, lock_token)), "test releases the WorldObject chunk write lease")

	var controller: Node = world.get("chunk_controller") as Node
	var previous_controller_recovery: Dictionary = controller.get("_pending_chunk_load_recovery")
	controller.set("_pending_chunk_load_recovery", {"test_fixture": true})
	_expect(bool(controller.call("has_pending_chunk_load_recovery")), "Controller reports a retained recovery payload as pending")
	_expect(world.call("serialize_stream_state").is_empty(), "pending Controller recovery blocks new world snapshots")
	var controller_barrier_bytes: String = FileAccess.get_file_as_string(blocked_path)
	_expect(not bool(world.call("save_game", blocked_path)), "pending Controller lifecycle recovery blocks disk save")
	_expect(not bool(world.call("load_game", blocked_path)), "pending Controller lifecycle recovery blocks disk load")
	_expect(not bool(world.call("restore_stream_state", payload_a, now_unix + 10)), "pending Controller lifecycle recovery blocks direct restore")
	_expect(str(world.call("get_last_restore_report").get("phase", "")) == "registry_pair_recovery_barrier", "Controller recovery blocks direct restore before participant mutation")
	_expect(FileAccess.get_file_as_string(blocked_path) == controller_barrier_bytes, "Controller recovery barrier preserves existing save bytes")
	controller.set("_pending_chunk_load_recovery", previous_controller_recovery)

	var surface_director: Node = world.get("director") as Node
	var previous_recovery_roots: Dictionary = surface_director.get("_pending_recovery_roots")
	surface_director.set("_pending_recovery_roots", {"test_fixture": {"root": null, "controller": controller}})
	var director_barrier_bytes: String = FileAccess.get_file_as_string(blocked_path)
	_expect(not bool(world.call("save_game", blocked_path)), "pending Surface Director recovery roots block disk save")
	_expect(not bool(world.call("load_game", blocked_path)), "pending Surface Director recovery roots block disk load")
	_expect(FileAccess.get_file_as_string(blocked_path) == director_barrier_bytes, "Surface Director recovery barrier preserves existing save bytes")
	surface_director.set("_pending_recovery_roots", previous_recovery_roots)

	var mineral_registry: Node = world.get("registry") as Node
	var previous_pending_recovery: Dictionary = mineral_registry.get("_pending_atomic_registration_recovery")
	mineral_registry.set("_pending_atomic_registration_recovery", {"test_fixture": true})
	var mineral_restore_payload: Dictionary = world.call("serialize_stream_state")
	_expect(mineral_restore_payload.is_empty(), "pending Mineral Registry recovery blocks new snapshots")
	_expect(not bool(world.call("restore_stream_state", payload_a, now_unix + 10)), "pending Mineral Registry recovery blocks direct stream restore")
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

	_cleanup_save_test_files(interrupted_path)
	_expect(bool(world.call("save_game", interrupted_path)), "restart-recovery fixture writes its first valid primary")
	var interrupted_primary_text: String = FileAccess.get_file_as_string(interrupted_path)
	var stage_interrupted_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(interrupted_path),
		ProjectSettings.globalize_path(interrupted_path + ".previous")
	)
	_expect(stage_interrupted_error == OK, "simulate a process interruption after staging the previous primary")
	_expect(not FileAccess.file_exists(interrupted_path) and FileAccess.file_exists(interrupted_path + ".previous"), "interrupted-write fixture leaves only the validated previous primary")
	_expect(not FileAccess.file_exists(interrupted_path + ".bak"), "first-save interruption fixture has no backup fallback")
	world.queue_free()
	await process_frame
	world = WorldScene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	_expect(bool(world.call("get_world_session_status").get("ready", false)), "fresh SurfaceWorld starts before interrupted-file recovery")
	var interrupted_load_ok: bool = bool(world.call("load_game", interrupted_path))
	if not interrupted_load_ok:
		push_error("Interrupted primary load diagnostics: save=" + JSON.stringify(world.call("get_last_save_report")) + " restore=" + JSON.stringify(world.call("get_last_restore_report")) + " barrier=" + JSON.stringify(world.call("_get_world_save_recovery_barrier_report")))
	_expect(interrupted_load_ok, "load entry recovers a validated previous primary after restart")
	_expect(FileAccess.get_file_as_string(interrupted_path) == interrupted_primary_text, "load recovery restores the exact previous primary bytes")
	_expect(not FileAccess.file_exists(interrupted_path + ".previous"), "successful load recovery consumes the staged previous file")

	_cleanup_save_test_files(path)
	_cleanup_save_test_files(blocked_path)
	_cleanup_save_test_files(promotion_path)
	_cleanup_save_test_files(interrupted_path)
	_cleanup_save_test_files(invalid_path)


func _test_failed_restore_stream_rollback() -> void:
	await process_frame
	var now_unix: int = int(Time.get_unix_time_from_system())
	for mineral_node_value in world.chunk_controller.get_loaded_mineral_nodes():
		var mineral_node: Node = mineral_node_value as Node
		if mineral_node != null and mineral_node.has_method("apply_elapsed_regeneration"):
			mineral_node.call("apply_elapsed_regeneration", now_unix)
	var original_director: Node = world.get("director") as Node
	var original_position: Vector3 = world.player.global_position
	var original_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()
	var original_inventory: Dictionary = world.inventory_bridge.call("serialize_inventory")
	var original_minerals: Dictionary = world.chunk_controller.call("to_save_dict")
	var original_crops: Dictionary = world.crop_registry.call("to_save_dict")
	var original_stamina: Dictionary = world.stamina.call("to_save_dict")
	var original_quick_use: Dictionary = world.quick_use.call("to_save_dict")
	var target_position: Vector3 = original_position + Vector3(1200.0, 0.0, 1200.0)
	_fail_chunk_coord = original_director.get_grid_coordinate(target_position)
	_expect(bool(original_director.call("bind_chunk_factory", Callable(self, "_make_chunk_with_injected_failure"))), "restore rollback test installs a deterministic failing chunk factory")
	var candidate: Dictionary = world.call("serialize_stream_state")
	var original_objects: Dictionary = candidate.get("world_objects", {})
	_expect(world.object_state_registry.call("to_save_dict") == original_objects, "rollback baseline uses the live-captured world-object snapshot")
	candidate["player_position"] = [target_position.x, target_position.y, target_position.z]
	var restored: bool = bool(world.call("restore_stream_state", candidate, now_unix))
	_expect(not restored, "failed target chunk streaming rejects the disk restore candidate")
	var report: Dictionary = world.call("get_last_restore_report")
	_expect(str(report.get("phase", "")) == "stream_sync" and bool(report.get("rollback_complete", false)), "failed target streaming reports a complete rollback: " + JSON.stringify(report))
	_expect(world.player.global_position.is_equal_approx(original_position), "failed target streaming restores the original player position")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == original_ids, "failed target streaming restores the original active chunk window")
	_expect(world.chunk_controller.call("to_save_dict") == original_minerals, "failed target streaming restores mineral records")
	_expect(world.crop_registry.call("to_save_dict") == original_crops, "failed target streaming restores crop records")
	_expect(world.object_state_registry.call("to_save_dict") == original_objects, "failed target streaming restores world-object records")
	_expect(world.inventory_bridge.call("serialize_inventory") == original_inventory, "failed target streaming preserves inventory")
	_expect(world.stamina.call("to_save_dict") == original_stamina and world.quick_use.call("to_save_dict") == original_quick_use, "failed target streaming preserves stamina and quick-use state")
	var expected_managed_ids: PackedStringArray = world.call("_get_expected_loaded_chunk_ids")
	_expect(expected_managed_ids == world.chunk_controller.get_loaded_chunk_ids(), "failed target streaming leaves combined Director and Controller chunk sets consistent")
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

