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

class FailingUndergroundRestoreDirector extends Node:
	func has_pending_registry_pair_recovery() -> bool:
		return false

	func get_pending_registry_pair_recovery_report() -> Dictionary:
		return {}

	func get_managed_chunk_ids() -> PackedStringArray:
		return PackedStringArray()

	func sync_to_world_position(_position: Vector3, _now_unix: int = -1) -> bool:
		return false

	func recover_to_world_position(_position: Vector3, _now_unix: int = -1) -> bool:
		return false
class RejectingStaminaRestore extends "res://systems/SurvivalStamina.gd":
	func load_save_dict(_data: Dictionary) -> bool:
		return false

class RejectingQuickUseRestore extends "res://systems/SurvivalQuickUse.gd":
	func load_save_dict(_data: Dictionary) -> bool:
		return false

var failures: Array[String] = []
var world: Node3D
var _promotion_fail_path: String = ""
var _temp_promotion_fail_path: String = ""
var _fail_chunk_coord: Vector2i = Vector2i(999999, 999999)
var _test_run_prefix: String = ""
var _owned_test_save_paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_run_prefix = "production_surface_world_" + str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec()) + "_"
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
	await _test_underground_restore_rollback_barrier()
	await _test_late_participant_restore_failures()
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
	var reserved_base_path: String = _test_user_path("reserved_primary")
	var reserved_directory_path: String = "user://" + _test_run_prefix + "reserved_directory"
	var reserved_paths: Array[String] = [
		reserved_base_path + ".tmp",
		reserved_base_path + ".bak",
		reserved_base_path + ".bak.tmp",
		reserved_base_path + ".previous",
		reserved_base_path + ".restore.tmp",
		reserved_base_path + ".corrupt.123",
		reserved_base_path + ".BAK",
		reserved_base_path + ".TMP",
		reserved_directory_path + ".bak/slot.json",
		reserved_directory_path + ".BAK/slot.json"
	]
	for reserved_path in reserved_paths:
		var write_report: Dictionary = SaveStoreScript.write_atomic(reserved_path, "{}", validator)
		_expect(not bool(write_report.get("ok", false)) and str(write_report.get("phase", "")) == "path_preflight" and str(write_report.get("reason", "")) == "unsupported_save_path", "writer rejects reserved save-family base path: " + reserved_path)
		var recovery_report: Dictionary = SaveStoreScript.recover_interrupted_write(reserved_path, validator)
		_expect(not bool(recovery_report.get("ok", false)) and str(recovery_report.get("reason", "")) == "unsupported_save_path", "interrupted-write recovery rejects reserved sidecar base path: " + reserved_path)
		var promotion_report: Dictionary = SaveStoreScript.promote_backup(reserved_path, validator)
		_expect(not bool(promotion_report.get("ok", false)) and str(promotion_report.get("phase", "")) == "path_preflight" and str(promotion_report.get("reason", "")) == "unsupported_save_path", "backup promotion rejects reserved sidecar base path: " + reserved_path)
		var save_ok: bool = bool(world.call("save_game", reserved_path))
		var save_report: Dictionary = world.call("get_last_save_report")
		_expect(not save_ok and str(save_report.get("phase", "")) == "path_preflight" and str(save_report.get("reason", "")) == "unsupported_save_path", "public save_game rejects reserved sidecar base path: " + reserved_path)
		_expect(world.call("_get_world_save_recovery_barrier_report").is_empty(), "invalid save path does not create a false recovery barrier: " + reserved_path)
		var load_ok: bool = bool(world.call("load_game", reserved_path))
		var load_report: Dictionary = world.call("get_last_save_report")
		_expect(not load_ok and str(load_report.get("phase", "")) == "path_preflight" and str(load_report.get("reason", "")) == "unsupported_save_path", "public load_game rejects reserved sidecar base path: " + reserved_path)
		_expect(world.call("_get_world_save_recovery_barrier_report").is_empty(), "invalid load path does not create a false recovery barrier: " + reserved_path)


func _user_entry_is_occupied(path: String, _directory: DirAccess) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var parent_directory: DirAccess = DirAccess.open(path.get_base_dir())
	var is_link: bool = parent_directory != null and parent_directory.is_link(path.get_file())
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute_path) or is_link


func _test_save_path_symlink_guards() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	_expect(user_directory != null, "open user data for save-path symlink tests")
	if user_directory == null:
		return

	# Prove that a path collision fails closed without truncating or deleting the
	# existing entry. This sentinel is created and removed by this test only.
	var occupied_fixture_path: String = _test_user_path("occupied_claim")
	if _user_entry_is_occupied(occupied_fixture_path, user_directory):
		_expect(false, "occupied-path claim fixture starts from an unused per-run path")
		return
	var occupied_fixture_file := FileAccess.open(occupied_fixture_path, FileAccess.WRITE)
	if occupied_fixture_file == null:
		_expect(false, "create the owned occupied-path sentinel")
		return
	occupied_fixture_file.store_string("preserve-this-existing-entry")
	occupied_fixture_file.close()
	_expect(not _claim_test_save_path(occupied_fixture_path), "fixture ownership refuses a pre-existing file")
	_expect(not _write_test_text(occupied_fixture_path, "must-not-overwrite"), "test writer refuses an unclaimed occupied path")
	_expect(FileAccess.get_file_as_string(occupied_fixture_path) == "preserve-this-existing-entry", "occupied-path refusal preserves existing bytes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(occupied_fixture_path))

	# Every fixture uses a per-run namespace. Never delete a pre-existing entry
	# just to make a fixed test path available.
	var fixture_prefix: String = _test_run_prefix + "symlink_guard_"
	var target_directory: String = "user://" + fixture_prefix + "_target"
	if _user_entry_is_occupied(target_directory, user_directory):
		_expect(false, "directory-symlink fixture path is unused before creation")
		return
	var target_directory_absolute: String = ProjectSettings.globalize_path(target_directory)
	var target_directory_error: Error = DirAccess.make_dir_recursive_absolute(target_directory_absolute)
	if target_directory_error != OK and not DirAccess.dir_exists_absolute(target_directory_absolute):
		_expect(false, "create a symlink test target directory")
		return
	var target_file_path: String = target_directory + "/existing.json"
	if not _claim_test_save_path(target_file_path):
		_expect(false, "directory-symlink target file fixture claims a unique unused path")
		DirAccess.remove_absolute(target_directory_absolute)
		return
	var target_file_written: bool = _write_test_text(target_file_path, "protected-target-bytes")
	_expect(target_file_written, "write a file behind the directory symlink")
	if not target_file_written:
		_cleanup_save_test_files(target_file_path)
		DirAccess.remove_absolute(target_directory_absolute)
		return

	var directory_link_name: String = fixture_prefix + "_directory"
	var directory_link_path: String = "user://" + directory_link_name
	if _user_entry_is_occupied(directory_link_path, user_directory):
		_expect(false, "directory-symlink entry is unused before creation")
		_cleanup_save_test_files(target_file_path)
		DirAccess.remove_absolute(target_directory_absolute)
		return
	var directory_link_error: Error = user_directory.create_link(target_directory_absolute, directory_link_name)
	if directory_link_error != OK and OS.get_name() == "Windows":
		print("SKIP: symbolic-link regression fixture requires Windows Developer Mode or elevated privileges.")
		_cleanup_save_test_files(target_file_path)
		DirAccess.remove_absolute(target_directory_absolute)
		return
	_expect(directory_link_error == OK, "create a directory symlink inside user data")
	if directory_link_error == OK:
		var nested_write: Dictionary = SaveStoreScript.write_atomic(
			directory_link_path + "/new_save.json",
			"{}",
			Callable(world, "_validate_world_save_payload")
		)
		_expect(not bool(nested_write.get("ok", false)) and str(nested_write.get("phase", "")) == "path_symlink", "writer rejects a save path beneath a directory symlink")
		var nested_read: Dictionary = SaveStoreScript.read_valid_file(
			directory_link_path + "/existing.json",
			Callable(world, "_validate_world_save_payload")
		)
		_expect(not bool(nested_read.get("ok", false)) and str(nested_read.get("reason", "")) == "path_symlink", "reader rejects a path beneath a directory symlink")
		_expect(FileAccess.get_file_as_string(target_file_path) == "protected-target-bytes", "directory-symlink rejection preserves target bytes")
		user_directory.remove(directory_link_name)
	_cleanup_save_test_files(target_file_path)
	DirAccess.remove_absolute(target_directory_absolute)

	var direct_target: String = "user://" + fixture_prefix + "_direct_file_target.json"
	var direct_link_name: String = fixture_prefix + "_direct_file.json"
	var direct_link_path: String = "user://" + direct_link_name
	if not _claim_test_save_path(direct_target):
		_expect(false, "direct-file symlink target claims a unique unused path")
		return
	if _user_entry_is_occupied(direct_target, user_directory) or _user_entry_is_occupied(direct_link_path, user_directory):
		_expect(false, "direct-file symlink fixture paths are unused before creation")
		return
	var direct_target_written: bool = _write_test_text(direct_target, "protected-direct-file-bytes")
	_expect(direct_target_written, "write direct file-symlink target")
	if not direct_target_written:
		_cleanup_save_test_files(direct_target)
		return
	var direct_link_error: Error = user_directory.create_link(ProjectSettings.globalize_path(direct_target), direct_link_name)
	if direct_link_error != OK and OS.get_name() == "Windows":
		print("SKIP: direct file-symlink fixture requires Windows Developer Mode or elevated privileges.")
		_cleanup_save_test_files(direct_target)
		return
	_expect(direct_link_error == OK, "create a direct file symlink inside user data")
	if direct_link_error == OK:
		var direct_read: Dictionary = SaveStoreScript.read_valid_file(direct_link_path, Callable(world, "_validate_world_save_payload"))
		_expect(not bool(direct_read.get("ok", false)) and str(direct_read.get("reason", "")) == "path_symlink", "reader rejects a direct file symlink")
		var direct_write: Dictionary = SaveStoreScript.write_atomic(direct_link_path, "{}", Callable(world, "_validate_world_save_payload"))
		_expect(not bool(direct_write.get("ok", false)) and str(direct_write.get("phase", "")) == "path_symlink", "writer rejects a direct file symlink")
		_expect(FileAccess.get_file_as_string(direct_target) == "protected-direct-file-bytes", "direct-file-symlink rejection preserves target bytes")
		user_directory.remove(direct_link_name)
	_cleanup_save_test_files(direct_target)

	var archive_base_path: String = "user://" + fixture_prefix + "_archive_symlink_collision.json"
	var archive_timestamp: int = int(Time.get_unix_time_from_system()) + 31536000
	var expected_archive_path: String = archive_base_path + ".corrupt." + str(archive_timestamp)
	var archive_link_name: String = expected_archive_path.get_file()
	var missing_archive_target: String = "user://" + fixture_prefix + "_missing_archive_target.json"
	if _user_entry_is_occupied(expected_archive_path, user_directory) or _user_entry_is_occupied(missing_archive_target, user_directory):
		_expect(false, "archive symlink fixture paths are unused before creation")
		return
	var first_archive_candidate: String = SaveStoreScript._unique_corrupt_archive_path(archive_base_path, archive_timestamp)
	_expect(first_archive_candidate == expected_archive_path, "archive collision fixture starts from a deterministic unused candidate")
	var archive_link_error: Error = user_directory.create_link(ProjectSettings.globalize_path(missing_archive_target), archive_link_name)
	if archive_link_error != OK and OS.get_name() == "Windows":
		print("SKIP: dangling archive-symlink regression requires Windows Developer Mode or elevated privileges.")
	elif archive_link_error != OK:
		_expect(false, "create a dangling symlink at the next corrupt-archive candidate")
	else:
		_expect(not FileAccess.file_exists(expected_archive_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(expected_archive_path)), "dangling archive symlink is not reported as an ordinary file or directory")
		var collision_safe_candidate: String = SaveStoreScript._unique_corrupt_archive_path(archive_base_path, archive_timestamp)
		_expect(collision_safe_candidate == expected_archive_path + ".1", "corrupt-archive naming skips a dangling symlink and selects the next collision-free suffix")
		_expect(user_directory.is_link(archive_link_name), "archive candidate selection preserves the pre-existing dangling symlink")
		user_directory.remove(archive_link_name)

	# Exercise the real production load/recovery path, not only the archive-name helper.
	var end_to_end_archive_path: String = "user://" + fixture_prefix + "_archive_symlink_e2e.json"
	if not _claim_test_save_path(end_to_end_archive_path):
		_expect(false, "end-to-end archive fixture claims a unique unused save family")
		return
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".previous", ".restore.tmp"]:
		if _user_entry_is_occupied(end_to_end_archive_path + suffix, user_directory):
			_expect(false, "end-to-end save-family fixture paths are unused before creation")
			return
	var end_to_end_corrupt_primary: String = "{corrupt primary for end-to-end archive collision"
	var end_to_end_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not end_to_end_payload.is_empty(), "end-to-end archive collision fixture captures a valid production world payload")
	var end_to_end_temp_text: String = SaveStoreScript.encode_envelope(
		SaveStoreScript.build_envelope(end_to_end_payload, int(Time.get_unix_time_from_system()))
	)
	var end_to_end_setup_ok: bool = not end_to_end_payload.is_empty()
	if end_to_end_setup_ok:
		end_to_end_setup_ok = _write_test_text(end_to_end_archive_path, end_to_end_corrupt_primary)
		_expect(end_to_end_setup_ok, "end-to-end archive collision fixture writes an invalid primary")
	if end_to_end_setup_ok:
		end_to_end_setup_ok = _write_test_text(end_to_end_archive_path + ".tmp", end_to_end_temp_text)
		_expect(end_to_end_setup_ok, "end-to-end archive collision fixture writes a fully valid temp")
	if not end_to_end_setup_ok:
		_cleanup_save_test_files(end_to_end_archive_path)
		return
	var end_to_end_start_timestamp: int = int(Time.get_unix_time_from_system())
	var end_to_end_link_names: Array[String] = []
	var end_to_end_symlinks_supported: bool = true
	for offset in range(0, 12):
		if not end_to_end_symlinks_supported:
			break
		var candidate_timestamp: int = end_to_end_start_timestamp + offset
		var candidate_link_name: String = end_to_end_archive_path.get_file() + ".corrupt." + str(candidate_timestamp)
		var candidate_link_path: String = "user://" + candidate_link_name
		if _user_entry_is_occupied(candidate_link_path, user_directory):
			_expect(false, "end-to-end archive collision candidate is unused before fixture creation")
			end_to_end_symlinks_supported = false
			break
		var missing_target_path: String = candidate_link_path + ".missing-target"
		var create_link_error: Error = user_directory.create_link(ProjectSettings.globalize_path(missing_target_path), candidate_link_name)
		if create_link_error != OK:
			if OS.get_name() == "Windows":
				print("SKIP: end-to-end dangling archive-symlink regression requires Windows Developer Mode or elevated privileges.")
			else:
				_expect(false, "create a dangling symlink for the production archive recovery path")
			end_to_end_symlinks_supported = false
			break
		end_to_end_link_names.append(candidate_link_name)
	if end_to_end_symlinks_supported:
		var end_to_end_load_ok: bool = bool(world.call("load_game", end_to_end_archive_path))
		if not end_to_end_load_ok:
			push_error("End-to-end archive symlink recovery diagnostics: save=" + JSON.stringify(world.call("get_last_save_report")) + " restore=" + JSON.stringify(world.call("get_last_restore_report")))
		_expect(end_to_end_load_ok, "production load recovers a valid temp while archiving a corrupt primary beside a dangling symlink")
		if end_to_end_load_ok:
			_expect(FileAccess.get_file_as_string(end_to_end_archive_path) == end_to_end_temp_text, "production recovery promotes the exact verified temp bytes to primary")
			_expect(not FileAccess.file_exists(end_to_end_archive_path + ".tmp"), "production recovery consumes the source temp only after successful promotion")
			_expect(str(world.call("get_last_save_report").get("phase", "")) == "loaded_from_primary", "production load continues through the normal validated primary path after recovery")
			var archived_primary_count: int = 0
			var archived_primary_path: String = ""
			for offset in range(0, 12):
				var candidate_archive_path: String = end_to_end_archive_path + ".corrupt." + str(end_to_end_start_timestamp + offset) + ".1"
				if FileAccess.file_exists(candidate_archive_path) and FileAccess.get_file_as_string(candidate_archive_path) == end_to_end_corrupt_primary:
					archived_primary_count += 1
					archived_primary_path = candidate_archive_path
			_expect(archived_primary_count == 1, "production recovery archives the corrupt primary to the collision-free .1 suffix exactly once")
			if not archived_primary_path.is_empty():
				var occupied_symlink_path: String = archived_primary_path.trim_suffix(".1")
				_expect(user_directory.is_link(occupied_symlink_path.get_file()), "production recovery leaves the colliding dangling archive symlink intact")
				_expect(not FileAccess.file_exists(occupied_symlink_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(occupied_symlink_path)), "the preserved archive symlink remains dangling after the real archive rename")
	for link_name in end_to_end_link_names:
		if user_directory.is_link(link_name):
			user_directory.remove(link_name)
	_cleanup_save_test_files(end_to_end_archive_path)


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
	for test_path in _owned_test_save_paths.duplicate():
		_cleanup_save_test_files(test_path)
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
	var path: String = _test_user_path("save")
	var blocked_path: String = _test_user_path("save_blocked")
	var promotion_path: String = _test_user_path("save_promotion")
	var interrupted_path: String = _test_user_path("interrupted_restart")
	var first_write_temp_path: String = _test_user_path("first_write_temp_recovery")
	if not _claim_test_save_paths([path, blocked_path, promotion_path, interrupted_path, first_write_temp_path]):
		_expect(false, "all production save fixtures claim unique, unused per-process paths before writing")
		return

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
	var numeric_path: String = _test_user_path("json_numeric")
	if not _claim_test_save_path(numeric_path):
		_expect(false, "JSON numeric fixture claims a unique unused path")
		return
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
	var primary_precedence_payload: Dictionary = payload_a.duplicate(true)
	primary_precedence_payload["world_seed"] = int(primary_precedence_payload.get("world_seed", 0)) + 17
	var primary_precedence_temp_text: String = SaveStoreScript.encode_envelope(SaveStoreScript.build_envelope(primary_precedence_payload, now_unix + 1))
	_expect(_write_test_text(path + ".tmp", primary_precedence_temp_text), "valid committed primary fixture receives a different fully valid uncommitted temp")
	var committed_primary_before_temp_load: String = FileAccess.get_file_as_string(path)
	_expect(bool(world.call("load_game", path)), "valid committed primary loads when a different valid uncommitted temp is present")
	_expect(FileAccess.get_file_as_string(path) == committed_primary_before_temp_load, "valid committed primary remains byte-for-byte authoritative over a valid temp")
	_expect(FileAccess.get_file_as_string(path + ".tmp") == primary_precedence_temp_text, "valid committed primary prevents promotion or consumption of the uncommitted temp")
	_expect(int(world.get("world_seed")) == int(payload_a.get("world_seed", 0)), "load uses the committed primary payload rather than the newer uncommitted temp")
	_expect(str(world.call("get_last_save_report").get("phase", "")) == "loaded_from_primary", "primary-precedence recovery reports the committed primary as the load source")
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
	var uncommitted_temp_envelope: Dictionary = SaveStoreScript.build_envelope(payload_b, now_unix + 12)
	var uncommitted_temp_text: String = SaveStoreScript.encode_envelope(uncommitted_temp_envelope)
	_expect(_write_test_text(path + ".tmp", uncommitted_temp_text), "test creates a valid uncommitted temp beside a corrupt primary and valid backup")
	_expect(bool(SaveStoreScript.read_valid_file(path + ".tmp", Callable(world, "_validate_world_save_payload")).get("ok", false)), "uncommitted temp is fully valid before backup recovery")
	_expect(bool(world.call("load_game", path)), "valid backup is restored when the primary is corrupt")
	_expect(_inventory_count("berries") == 3, "backup recovery restores the previous valid inventory")
	var backup_stamina: RefCounted = world.get("stamina") as RefCounted
	var backup_quick_use: RefCounted = world.get("quick_use") as RefCounted
	_expect(is_equal_approx(float(backup_stamina.get("current_stamina")), 42.5), "backup recovery restores the previous stamina")
	_expect(int(backup_quick_use.get("selected_slot")) == 2, "backup recovery restores the previous quick-use selection")
	_expect(FileAccess.get_file_as_string(path + ".tmp") == uncommitted_temp_text, "valid committed backup takes precedence over an uncommitted valid temp")
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
	_expect(not FileAccess.file_exists(path + ".tmp"), "next successful save cleans the lower-priority uncommitted temp")
	var backup_rotation_report: Dictionary = world.call("get_last_save_report")
	var backup_archive_path: String = str(backup_rotation_report.get("details", {}).get("backup_archive_path", ""))
	_expect(not backup_archive_path.is_empty() and FileAccess.file_exists(backup_archive_path), "corrupt backup is preserved in a diagnostic archive before rotation")

	var invalid_path: String = _test_user_path("invalid_save")
	if not _claim_test_save_path(invalid_path):
		_expect(false, "invalid save fixture claims a unique unused path")
		return
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

	var first_write_payload: Dictionary = world.call("serialize_stream_state")
	var first_write_saved_at: int = int(Time.get_unix_time_from_system())
	var first_write_text: String = SaveStoreScript.encode_envelope(SaveStoreScript.build_envelope(first_write_payload, first_write_saved_at))
	_expect(_write_test_text(first_write_temp_path + ".tmp", first_write_text), "first-save interruption fixture leaves a complete verified temp without primary, backup, or previous")
	_expect(bool(SaveStoreScript.read_valid_file(first_write_temp_path + ".tmp", Callable(world, "_validate_world_save_payload")).get("ok", false)), "first-save temp passes full envelope and payload validation")
	_expect(not FileAccess.file_exists(first_write_temp_path) and not FileAccess.file_exists(first_write_temp_path + ".bak") and not FileAccess.file_exists(first_write_temp_path + ".previous"), "first-save recovery fixture has no committed file candidates")

	world.queue_free()
	await process_frame
	world = WorldScene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	_expect(bool(world.call("get_world_session_status").get("ready", false)), "fresh SurfaceWorld starts before first-write temp recovery")
	var first_write_load_ok: bool = bool(world.call("load_game", first_write_temp_path))
	if not first_write_load_ok:
		push_error("First-write temp load diagnostics: save=" + JSON.stringify(world.call("get_last_save_report")) + " restore=" + JSON.stringify(world.call("get_last_restore_report")) + " barrier=" + JSON.stringify(world.call("_get_world_save_recovery_barrier_report")))
	_expect(first_write_load_ok, "load entry promotes and restores a validated temp when no committed save exists")
	_expect(FileAccess.get_file_as_string(first_write_temp_path) == first_write_text, "first-write recovery preserves the exact validated temp bytes as primary")
	_expect(not FileAccess.file_exists(first_write_temp_path + ".tmp"), "successful first-write recovery consumes the temp sidecar")
	_expect(str(world.call("get_last_save_report").get("phase", "")) == "loaded_from_primary", "first-write recovery continues through the normal primary load path")
	_expect(_inventory_count("berries") == int(first_write_payload.get("inventory", {}).get("inventory", {}).get("berries", 0)), "first-write recovery restores the saved inventory after restart")

	var invalid_temp_path: String = _test_user_path("invalid_temp_recovery")
	if not _claim_test_save_path(invalid_temp_path):
		_expect(false, "invalid temp fixture claims a unique unused path")
		return
	var invalid_temp_bytes: String = "{partial interrupted temp"
	_expect(_write_test_text(invalid_temp_path + ".tmp", invalid_temp_bytes), "invalid first-write temp fixture is created")
	var before_invalid_temp_load: Dictionary = world.call("serialize_stream_state")
	_expect(not bool(world.call("load_game", invalid_temp_path)), "invalid temp without a committed primary or backup is not promoted")
	_expect(FileAccess.get_file_as_string(invalid_temp_path + ".tmp") == invalid_temp_bytes, "invalid temp is preserved byte-for-byte for diagnosis")
	_expect(not FileAccess.file_exists(invalid_temp_path), "invalid temp does not create a primary save")
	var after_invalid_temp_load: Dictionary = world.call("serialize_stream_state")
	_expect(bool(world.call("_world_recovery_matches_snapshot", after_invalid_temp_load, before_invalid_temp_load)), "invalid temp rejection leaves the live world snapshot unchanged")

	var corrupt_temp_path: String = _test_user_path("corrupt_primary_temp_recovery")
	if not _claim_test_save_path(corrupt_temp_path):
		_expect(false, "corrupt primary temp fixture claims a unique unused path")
		return
	var corrupt_primary_bytes: String = "{corrupt primary before verified temp recovery"
	var corrupt_temp_text: String = SaveStoreScript.encode_envelope(SaveStoreScript.build_envelope(first_write_payload, int(Time.get_unix_time_from_system())))
	_expect(_write_test_text(corrupt_temp_path, corrupt_primary_bytes), "corrupt-primary temp recovery fixture writes the invalid primary")
	_expect(_write_test_text(corrupt_temp_path + ".tmp", corrupt_temp_text), "corrupt-primary temp recovery fixture writes a valid temp")
	_temp_promotion_fail_path = corrupt_temp_path
	var failed_temp_promotion: Dictionary = SaveStoreScript.recover_interrupted_write(
		corrupt_temp_path,
		Callable(world, "_validate_world_save_payload"),
		Callable(self, "_rename_fail_temp_promotion")
	)
	_expect(not bool(failed_temp_promotion.get("ok", false)), "injected verified-temp promotion failure is reported")
	var failed_temp_details: Dictionary = failed_temp_promotion.get("temp_recovery", {})
	_expect(not bool(failed_temp_details.get("recovery_required", true)), "failed temp promotion restores the original corrupt primary when its archive rollback succeeds")
	_expect(FileAccess.get_file_as_string(corrupt_temp_path) == corrupt_primary_bytes, "failed temp promotion preserves the original primary bytes")
	_expect(FileAccess.get_file_as_string(corrupt_temp_path + ".tmp") == corrupt_temp_text, "failed temp promotion preserves the validated temp source")
	_temp_promotion_fail_path = ""
	_expect(bool(world.call("load_game", corrupt_temp_path)), "load retry promotes the verified temp after the injected failure is removed")
	_expect(FileAccess.get_file_as_string(corrupt_temp_path) == corrupt_temp_text, "retry installs the exact validated temp as primary")
	_expect(not FileAccess.file_exists(corrupt_temp_path + ".tmp"), "successful retry consumes the temp source")
	var corrupt_temp_archive_found: bool = false
	var corrupt_temp_directory: DirAccess = DirAccess.open("user://")
	if corrupt_temp_directory != null:
		for filename in corrupt_temp_directory.get_files():
			if filename.begins_with(corrupt_temp_path.get_file() + ".corrupt."):
				corrupt_temp_archive_found = true
				break
	_expect(corrupt_temp_archive_found, "verified-temp recovery archives the invalid primary before promotion")

	var rollback_failure_path: String = _test_user_path("temp_recovery_rollback_failure")
	if not _claim_test_save_path(rollback_failure_path):
		_expect(false, "rollback failure fixture claims a unique unused path")
		return
	var rollback_failure_primary_bytes: String = "{corrupt primary before temp recovery rollback failure"
	var rollback_failure_temp_text: String = SaveStoreScript.encode_envelope(SaveStoreScript.build_envelope(first_write_payload, int(Time.get_unix_time_from_system())))
	_expect(_write_test_text(rollback_failure_path, rollback_failure_primary_bytes), "rollback-failure fixture writes an invalid primary")
	_expect(_write_test_text(rollback_failure_path + ".tmp", rollback_failure_temp_text), "rollback-failure fixture writes a fully valid temp")
	_temp_promotion_fail_path = rollback_failure_path
	var rollback_failure_report: Dictionary = SaveStoreScript.recover_interrupted_write(
		rollback_failure_path,
		Callable(world, "_validate_world_save_payload"),
		Callable(self, "_rename_fail_temp_promotion_and_archive_rollback")
	)
	_expect(not bool(rollback_failure_report.get("ok", false)), "simultaneous temp promotion and archive rollback failures are reported")
	var rollback_failure_details: Dictionary = rollback_failure_report.get("temp_recovery", {})
	_expect(bool(rollback_failure_details.get("recovery_required", false)), "failed archive rollback retains an explicit recovery-required state")
	_expect(not FileAccess.file_exists(rollback_failure_path), "failed archive rollback does not claim a primary save exists")
	_expect(FileAccess.get_file_as_string(rollback_failure_path + ".tmp") == rollback_failure_temp_text, "failed archive rollback preserves the verified source temp for retry")
	var rollback_archive_found: bool = false
	var rollback_failure_directory: DirAccess = DirAccess.open("user://")
	if rollback_failure_directory != null:
		for filename in rollback_failure_directory.get_files():
			if filename.begins_with(rollback_failure_path.get_file() + ".corrupt."):
				rollback_archive_found = true
				break
	_expect(rollback_archive_found, "failed archive rollback retains the original corrupt primary archive")
	_temp_promotion_fail_path = ""
	_expect(bool(world.call("load_game", rollback_failure_path)), "fresh recovery attempt succeeds after the injected promotion and rollback failures are removed")
	_expect(FileAccess.get_file_as_string(rollback_failure_path) == rollback_failure_temp_text, "retry after rollback failure installs the exact verified temp")
	_expect(not FileAccess.file_exists(rollback_failure_path + ".tmp"), "successful retry after rollback failure consumes the source temp")
	_cleanup_save_test_files(rollback_failure_path)

	_cleanup_save_test_files(path)
	_cleanup_save_test_files(blocked_path)
	_cleanup_save_test_files(promotion_path)
	_cleanup_save_test_files(interrupted_path)
	_cleanup_save_test_files(first_write_temp_path)
	_cleanup_save_test_files(invalid_temp_path)
	_cleanup_save_test_files(corrupt_temp_path)
	_cleanup_save_test_files(invalid_path)


func _test_underground_restore_rollback_barrier() -> void:
	var rollback_world: Node3D = world
	_expect(rollback_world != null, "underground rollback-barrier fixture uses the initialized production SurfaceWorld")
	if rollback_world == null:
		return
	await process_frame
	var status: Dictionary = rollback_world.call("get_world_session_status")
	_expect(bool(status.get("ready", false)), "underground rollback-barrier fixture uses a ready streaming stack")
	if not bool(status.get("ready", false)):
		return

	var now_unix: int = int(Time.get_unix_time_from_system())
	var initial_payload: Dictionary = rollback_world.call("serialize_stream_state")
	_expect(not initial_payload.is_empty(), "underground rollback-barrier fixture captures a complete initial snapshot")
	if initial_payload.is_empty():
		return
	_expect(bool(rollback_world.call("restore_stream_state", initial_payload, now_unix, true)), "fixture primes a successful restore report before injecting a later failure")
	var previous_payload: Dictionary = rollback_world.call("serialize_stream_state")
	var previous_chunk_ids: PackedStringArray = rollback_world.chunk_controller.get_loaded_chunk_ids()
	var previous_minerals: Dictionary = rollback_world.chunk_controller.call("to_save_dict")
	var previous_objects: Dictionary = rollback_world.object_state_registry.call("to_save_dict")
	var previous_position: Vector3 = rollback_world.player.global_position
	var previous_world_seed: int = int(rollback_world.get("world_seed"))
	var original_mine_director: Node = rollback_world.get("mine_director") as Node

	var failing_director := FailingUndergroundRestoreDirector.new()
	failing_director.name = "InjectedFailingUndergroundDirector"
	rollback_world.add_child(failing_director)
	rollback_world.set("mine_director", failing_director)
	var candidate_payload: Dictionary = previous_payload.duplicate(true)
	candidate_payload["world_seed"] = previous_world_seed + 1
	var restored: bool = bool(rollback_world.call("restore_stream_state", candidate_payload, now_unix + 1))
	_expect(not restored, "failed underground target synchronization rejects the candidate world restore")
	var failed_report: Dictionary = rollback_world.call("get_last_restore_report")
	_expect(not bool(failed_report.get("rollback_complete", true)), "failed underground recovery cannot reuse a stale successful restore report")
	_expect(not rollback_world.call("_get_world_save_recovery_barrier_report").is_empty(), "incomplete underground rollback creates a world persistence barrier")
	_expect(rollback_world.call("serialize_stream_state").is_empty(), "incomplete underground rollback blocks new world snapshots")
	_expect(rollback_world.chunk_controller.get_loaded_chunk_ids() != previous_chunk_ids, "failure injection removes the underground window before recovery is refused")
	_expect(int(rollback_world.get("world_seed")) == previous_world_seed, "failed recovery restores the previous world seed even while the chunk window remains incomplete")

	rollback_world.set("mine_director", original_mine_director)
	failing_director.queue_free()
	await process_frame
	_expect(bool(rollback_world.call("retry_save_recovery")), "restoring the original underground Director allows the retained world snapshot to recover")
	var recovered_payload: Dictionary = rollback_world.call("serialize_stream_state")
	_expect(bool(rollback_world.call("_world_recovery_matches_snapshot", recovered_payload, previous_payload)), "recovery readback exactly matches the retained pre-restore world snapshot")
	_expect(rollback_world.chunk_controller.get_loaded_chunk_ids() == previous_chunk_ids, "recovery restores the original combined surface and underground chunk window")
	_expect(rollback_world.chunk_controller.call("to_save_dict") == previous_minerals, "recovery restores exact mineral records after underground resynchronization")
	_expect(rollback_world.object_state_registry.call("to_save_dict") == previous_objects, "recovery restores exact world-object records after underground resynchronization")
	_expect(rollback_world.player.global_position.is_equal_approx(previous_position), "recovery preserves the original player position")


func _test_late_participant_restore_failures() -> void:
	await process_frame
	await _test_late_participant_restore_failure("stamina", RejectingStaminaRestore.new(), "stamina_restore", 20)
	await _test_late_participant_restore_failure("quick_use", RejectingQuickUseRestore.new(), "quick_use_restore", 40)


func _test_late_participant_restore_failure(
	participant_property: String,
	rejecting_participant: RefCounted,
	expected_phase: String,
	time_offset: int
) -> void:
	var original_participant: RefCounted = world.get(participant_property) as RefCounted
	_expect(original_participant != null, participant_property + " fixture captures the original participant")
	if original_participant == null:
		return

	var original_payload: Dictionary = world.call("serialize_stream_state")
	_expect(not original_payload.is_empty(), participant_property + " fixture captures a complete pre-restore snapshot")
	if original_payload.is_empty():
		return
	var original_position: Vector3 = world.player.global_position
	var original_chunk_ids: PackedStringArray = world.chunk_controller.get_loaded_chunk_ids()

	if participant_property == "stamina":
		rejecting_participant.set("current_stamina", float(original_participant.get("current_stamina")))
	else:
		rejecting_participant.set("slots", original_participant.get("slots").duplicate())
		rejecting_participant.set("selected_slot", int(original_participant.get("selected_slot")))

	world.set(participant_property, rejecting_participant)
	var retained_before_restore: Dictionary = world.call("serialize_stream_state")
	_expect(bool(world.call("_world_recovery_matches_snapshot", retained_before_restore, original_payload)), participant_property + " rejecting fixture preserves the exact pre-attempt participant state")
	var candidate_payload: Dictionary = original_payload.duplicate(true)
	var target_position: Vector3 = original_position + Vector3(128.0, 0.0, 128.0)
	candidate_payload["player_position"] = [target_position.x, target_position.y, target_position.z]
	if participant_property == "stamina":
		candidate_payload["stamina"]["current"] = maxf(0.0, float(candidate_payload["stamina"].get("current", 100.0)) - 15.0)
	else:
		candidate_payload["quick_use"]["selected_slot"] = (int(candidate_payload["quick_use"].get("selected_slot", 0)) + 1) % 4

	var restore_ok: bool = bool(world.call("restore_stream_state", candidate_payload, int(Time.get_unix_time_from_system()) + time_offset))
	_expect(not restore_ok, participant_property + " late participant rejection fails the candidate restore")
	var restore_report: Dictionary = world.call("get_last_restore_report")
	_expect(str(restore_report.get("phase", "")) == expected_phase and not bool(restore_report.get("rollback_complete", true)), participant_property + " rejection reports an incomplete late-phase restore")
	_expect(not world.call("_get_world_save_recovery_barrier_report").is_empty(), participant_property + " rejection retains the world persistence barrier")
	_expect(world.call("serialize_stream_state").is_empty(), participant_property + " rejection blocks subsequent world snapshots")
	_expect(not world.player.global_position.is_equal_approx(original_position), participant_property + " rejection occurs after the base world restore has changed the player position")

	_expect(not bool(world.call("retry_save_recovery")), participant_property + " recovery remains blocked while the participant continues rejecting")
	_expect(not world.call("_get_world_save_recovery_barrier_report").is_empty(), participant_property + " failed recovery retry keeps the persistence barrier")

	world.set(participant_property, original_participant)
	_expect(bool(world.call("retry_save_recovery")), participant_property + " recovery succeeds after the original participant is restored")
	var recovered_payload: Dictionary = world.call("serialize_stream_state")
	_expect(bool(world.call("_world_recovery_matches_snapshot", recovered_payload, original_payload)), participant_property + " recovery readback exactly matches the pre-attempt world snapshot")
	_expect(world.chunk_controller.get_loaded_chunk_ids() == original_chunk_ids, participant_property + " recovery restores the original active chunk window")


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



func _test_user_path(label: String) -> String:
	return "user://" + _test_run_prefix + label + ".json"

func _claim_test_save_paths(paths: Array[String]) -> bool:
	for path in paths:
		if not _claim_test_save_path(path):
			return false
	return true

func _claim_test_save_path(path: String) -> bool:
	if _owned_test_save_paths.has(path) or _test_run_prefix.is_empty() or not path.begins_with("user://" + _test_run_prefix):
		return false
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory == null:
		return false
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".previous", ".restore.tmp"]:
		if _user_entry_is_occupied(path + suffix, directory):
			return false
	var archive_prefix: String = path.get_file() + ".corrupt."
	for filename in directory.get_files():
		if filename.begins_with(archive_prefix):
			return false
	for directory_name in directory.get_directories():
		if directory_name.begins_with(archive_prefix):
			return false
	_owned_test_save_paths.append(path)
	return true

func _is_owned_test_save_entry(path: String) -> bool:
	for base_path in _owned_test_save_paths:
		if path == base_path or path.begins_with(base_path + "."):
			return true
	return false

func _write_test_text(path: String, content: String) -> bool:
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null or not _is_owned_test_save_entry(path) or _user_entry_is_occupied(path, directory):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var success: bool = file.get_error() == OK
	file.close()
	return success

func _cleanup_save_test_files(path: String) -> void:
	if not _owned_test_save_paths.has(path):
		push_error("Refusing to clean an unclaimed test save path: " + path)
		return
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory == null:
		# A nested fixture directory may already have been removed after cleanup.
		_owned_test_save_paths.erase(path)
		return
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".previous", ".restore.tmp"]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	var prefix: String = path.get_file() + ".corrupt."
	for filename in directory.get_files():
		if filename.begins_with(prefix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir() + "/" + filename))

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


func _rename_fail_temp_promotion(source_absolute: String, destination_absolute: String) -> int:
	var primary_absolute: String = ProjectSettings.globalize_path(_temp_promotion_fail_path)
	if destination_absolute == primary_absolute and source_absolute.ends_with(".restore.tmp"):
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(source_absolute, destination_absolute)


func _rename_fail_temp_promotion_and_archive_rollback(source_absolute: String, destination_absolute: String) -> int:
	var primary_absolute: String = ProjectSettings.globalize_path(_temp_promotion_fail_path)
	if destination_absolute == primary_absolute and (source_absolute.ends_with(".restore.tmp") or source_absolute.contains(".corrupt.")):
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(source_absolute, destination_absolute)

