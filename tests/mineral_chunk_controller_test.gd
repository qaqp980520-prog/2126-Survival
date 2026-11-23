extends SceneTree

const MiningNode = preload("res://systems/MineralMiningNode.gd")
const Registry = preload("res://systems/MineralVeinRegistry.gd")
const Controller = preload("res://systems/MineralChunkController.gd")
const Adapter = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const ObjectRegistry = preload("res://systems/WorldObjectStateRegistry.gd")
const StatefulProp = preload("res://systems/WorldObjectStatefulProp.gd")
const CropRegistry = preload("res://systems/CropRegistry.gd")
const CropController = preload("res://systems/CropPlotController.gd")
const CropPlot = preload("res://systems/CropPlotVisual.gd")

class FakeCornerManager extends Node3D:
	var reports: Array[Dictionary] = []

	func get_blocked_corner_reports() -> Array[Dictionary]:
		return reports.duplicate(true)

class InstrumentedObjectRegistry:
	extends "res://systems/WorldObjectStateRegistry.gd"
	var full_snapshot_calls: int = 0
	var set_calls: int = 0
	var fail_after_set_calls: int = -1

	func to_save_dict() -> Dictionary:
		full_snapshot_calls += 1
		return super.to_save_dict()

	func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
		set_calls += 1
		if fail_after_set_calls >= 0 and set_calls > fail_after_set_calls:
			return false
		return super.set_object_state(stable_id, chunk_id, state)

class LegacyObjectRegistry extends Node:
	var _records: Dictionary = {}

	func get_object_state(stable_id: String) -> Dictionary:
		if not _records.has(stable_id):
			return {}
		return _records[stable_id].duplicate(true)

	func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
		_records[stable_id] = {"chunk_id": chunk_id, "state": state.duplicate(true)}
		return true

	func to_save_dict() -> Dictionary:
		return {"schema_version": 1, "objects": _records.duplicate(true)}

	func validate_save_dict(data: Dictionary) -> bool:
		var records: Variant = data.get("objects", null)
		return int(data.get("schema_version", -1)) == 1 and records is Dictionary

	func restore_save_dict(data: Dictionary) -> bool:
		if not validate_save_dict(data):
			return false
		var records: Dictionary = data.get("objects", {})
		_records = records.duplicate(true)
		return true


func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_nested_terrain_adjacency_batch_defers_rebuild()
	await process_frame
	await _test_chunk_save_unload_reload_with_offline_regeneration()
	await process_frame
	await _test_empty_chunk_and_duplicate_id()
	await process_frame
	await _test_failed_load_preserves_caller_root()
	await process_frame
	await _test_failed_unload_rolls_back_registration()
	await process_frame
	await _test_stateful_object_survives_unload_reload()
	await process_frame
	await _test_failed_object_state_application_is_atomic()
	await process_frame
	await _test_chunk_scoped_object_registry_rollback()
	await process_frame
	await _test_invalid_mineral_binding_rejected_before_chunk_registration()
	await process_frame
	await _test_invalid_crop_binding_rejected_before_chunk_registration()
	await process_frame
	await _test_corner_report_proxy_is_defensive()
	await process_frame
	print("Mineral chunk controller integration tests passed.")
	quit(0)

func _test_nested_terrain_adjacency_batch_defers_rebuild() -> void:
	var controller: Node3D = Controller.new()
	root.add_child(controller)
	await process_frame
	var initial_rebuild_count: int = int(controller.call("get_terrain_adjacency_rebuild_count"))
	assert(bool(controller.call("begin_terrain_adjacency_batch")), "outer terrain adjacency batch opens")
	assert(bool(controller.call("begin_terrain_adjacency_batch")), "nested terrain adjacency batch opens")
	var empty_patches: Array[Node3D] = []
	var deferred_request: Dictionary = controller.call("_request_terrain_adjacency_rebind", empty_patches)
	assert(bool(deferred_request.get("ok", false)) and bool(deferred_request.get("deferred", false)), "nested batch defers the adjacency request")
	var inner_result: Dictionary = controller.call("end_terrain_adjacency_batch")
	assert(bool(inner_result.get("ok", false)) and bool(inner_result.get("deferred", false)), "inner batch close defers finalization")
	assert(int(controller.call("get_terrain_adjacency_rebuild_count")) == initial_rebuild_count, "inner close performs no rebuild")
	var outer_result: Dictionary = controller.call("end_terrain_adjacency_batch")
	assert(bool(outer_result.get("ok", false)), "outer batch close finalizes successfully")
	assert(int(controller.call("get_terrain_adjacency_rebuild_count")) == initial_rebuild_count + 1, "outer close performs exactly one full adjacency rebuild")
	var extra_result: Dictionary = controller.call("end_terrain_adjacency_batch")
	assert(bool(extra_result.get("ok", false)) and not bool(extra_result.get("active", true)), "extra close is safely reported as inactive")
	assert(int(controller.call("get_terrain_adjacency_rebuild_count")) == initial_rebuild_count + 1, "extra close does not rebuild again")
	controller.queue_free()
	await process_frame

func _test_chunk_save_unload_reload_with_offline_regeneration() -> void:
	var base_time: int = int(Time.get_unix_time_from_system()) - 5
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))

	var chunk_id := "earth/sector-2/chunk--4"
	var first_chunk: Node3D = _new_mineral_chunk(1, base_time + 5)
	assert(controller.load_chunk(chunk_id, first_chunk, base_time + 5))
	var stable_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	assert(registry.get_registered_ids().has(stable_id))
	assert(controller.get_chunk_root(chunk_id) == first_chunk)
	assert(controller.unload_chunk(chunk_id, base_time + 5))
	assert(not registry.get_registered_ids().has(stable_id))
	assert(registry.get_saved_ids().has(stable_id))
	var payload: Dictionary = controller.to_save_dict()
	assert(payload.get("veins", {}).has(stable_id))

	controller.queue_free()
	registry.queue_free()
	await process_frame

	var restored_registry: Node = Registry.new()
	root.add_child(restored_registry)
	await process_frame
	assert(restored_registry.restore_save_dict(payload, base_time + 125))
	var restored_controller: Node3D = Controller.new()
	root.add_child(restored_controller)
	await process_frame
	assert(restored_controller.bind_registry(restored_registry))

	var replacement: Node3D = _new_mineral_chunk(8, int(Time.get_unix_time_from_system()))
	assert(restored_controller.load_chunk(chunk_id, replacement, base_time + 125))
	var restored_vein: Node = replacement.get_node("gold-01")
	assert(restored_vein.remaining_units == 3, "Reload should restore one saved unit plus two elapsed regeneration intervals")
	assert(restored_registry.get_registered_ids().has(stable_id))
	assert(restored_controller.unload_chunk(chunk_id, base_time + 125))
	restored_controller.queue_free()
	restored_registry.queue_free()
	await process_frame

func _test_empty_chunk_and_duplicate_id() -> void:
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))
	var empty_chunk := Node3D.new()
	empty_chunk.name = "EmptyChunk"
	assert(controller.load_chunk("earth/empty-chunk", empty_chunk, int(Time.get_unix_time_from_system())))
	assert(controller.is_chunk_loaded("earth/empty-chunk"))
	var duplicate := Node3D.new()
	duplicate.name = "DifferentChunk"
	assert(not controller.load_chunk("earth/empty-chunk", duplicate), "A duplicate chunk ID must not replace the live root")
	assert(controller.get_chunk_root("earth/empty-chunk") == empty_chunk)
	assert(controller.unload_chunk("earth/empty-chunk"))
	assert(not controller.is_chunk_loaded("earth/empty-chunk"))
	duplicate.free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_failed_load_preserves_caller_root() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))
	var chunk_id := "earth/conflict"
	var stable_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	var existing: Node3D = MiningNode.new()
	existing.name = "ExistingGold"
	existing.mineral_id = "gold_ore"
	existing.max_units = 8
	existing.remaining_units = 4
	existing.regen_interval_seconds = 60
	existing.last_regen_unix = now
	assert(registry.register_vein(stable_id, existing, now))
	var incoming: Node3D = _new_mineral_chunk(2, now)
	assert(not controller.load_chunk(chunk_id, incoming, now), "Duplicate stable ID must reject the incoming chunk")
	assert(is_instance_valid(incoming), "Failed load must not free the caller-owned root")
	assert(incoming.get_parent() == null, "Failed load must detach the root so it can be retried")
	assert(registry.get_registered_ids().has(stable_id))
	assert(registry.unregister_vein(stable_id, existing, now))
	incoming.free()
	existing.free()
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_failed_unload_rolls_back_registration() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))
	var chunk_id := "earth/rollback"
	var chunk: Node3D = _new_two_mineral_chunk(now)
	assert(controller.load_chunk(chunk_id, chunk, now))
	var first_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	var second_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/iron-02")
	var second: Node = chunk.get_node("iron-02")
	second.mineral_id = "missing_mineral"
	assert(not controller.unload_chunk(chunk_id, now), "Invalid second vein must abort unload")
	assert(controller.is_chunk_loaded(chunk_id), "Failed unload must retain controller ownership")
	assert(controller.get_chunk_root(chunk_id) == chunk)
	assert(chunk.get_parent() == controller)
	assert(registry.get_registered_ids().has(first_id), "Previously unregistered first vein must be restored")
	assert(registry.get_registered_ids().has(second_id), "Failed vein must remain registered")
	second.mineral_id = "iron_ore"
	assert(controller.unload_chunk(chunk_id, now), "Unload should succeed after repairing invalid vein data")
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_stateful_object_survives_unload_reload() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var object_registry: Node = ObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_object_state_registry(object_registry))
	var chunk_id := "earth/object-sector"
	var first_chunk: Node3D = _new_stateful_chunk()
	assert(controller.load_chunk(chunk_id, first_chunk, now))
	var stable_id := chunk_id + "/object/ChunkRoot/SalvageCrate"
	var crate: Node = first_chunk.get_node("SalvageCrate")
	assert(int(object_registry.get_object_state(stable_id).get("state", {}).get("loot_remaining", -1)) == 2, "First load seeds the object's default state")
	assert(bool(crate.call("interact")), "The stateful prop can be interacted with")
	assert(controller.capture_loaded_world_object_states(), "Saving captures current live prop state")
	assert(controller.unload_chunk(chunk_id, now), "Chunk unload captures object state before freeing nodes")
	var saved: Dictionary = object_registry.get_object_state(stable_id).get("state", {})
	assert(bool(saved.get("opened", false)) and int(saved.get("loot_remaining", -1)) == 1, "Unload stores the opened crate state")
	var replacement: Node3D = _new_stateful_chunk()
	assert(controller.load_chunk(chunk_id, replacement, now), "Reload reapplies the saved object state")
	var restored: Node = replacement.get_node("SalvageCrate")
	assert(bool(restored.get("opened")) and int(restored.get("loot_remaining")) == 1, "Reloaded prop matches its stable-ID record")
	var registry_before_invalid_capture: Dictionary = object_registry.to_save_dict()
	# Test-only reflection deliberately corrupts backing state to exercise capture rollback.
	restored.set("_opened", true)
	restored.set("_loot_remaining", 2)
	assert(not controller.capture_loaded_world_object_states(), "Capture rejects semantically invalid live state")
	assert(object_registry.to_save_dict() == registry_before_invalid_capture, "Invalid live state cannot partially mutate the registry")
	assert(not controller.unload_chunk(chunk_id, now), "Unload rejects semantically invalid live state")
	assert(controller.is_chunk_loaded(chunk_id), "Rejected unload keeps ownership of the live chunk")
	assert(object_registry.to_save_dict() == registry_before_invalid_capture, "Rejected unload preserves the registry snapshot")
	assert(bool(restored.call("apply_world_object_state", {"opened": true, "loot_remaining": 1})), "Prop can be repaired to a valid state after rejected capture")
	assert(controller.unload_chunk(chunk_id, now))
	controller.queue_free()
	object_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _test_failed_object_state_application_is_atomic() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var object_registry: Node = ObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_object_state_registry(object_registry))
	var chunk_id := "earth/object-reject"
	var stable_id := chunk_id + "/object/ChunkRoot/SalvageCrate"
	assert(object_registry.set_object_state(stable_id, chunk_id, {"opened": true, "loot_remaining": 2}), "Registry accepts bounded primitive state even if a specific prop rejects the semantic combination")
	var before: Dictionary = object_registry.to_save_dict()
	var incoming: Node3D = _new_stateful_chunk()
	assert(not controller.load_chunk(chunk_id, incoming, now), "Prop must reject an incompatible saved state")
	assert(incoming.get_parent() == null, "Failed state application leaves the caller-owned chunk detached")
	var incoming_crate: Node = incoming.get_node("SalvageCrate")
	assert(not bool(incoming_crate.get("opened")) and int(incoming_crate.get("loot_remaining")) == 2, "Failed apply restores the incoming prop's original state")
	assert(object_registry.to_save_dict() == before, "Failed apply restores the object registry snapshot atomically")
	assert(not controller.is_chunk_loaded(chunk_id), "Failed object restoration must not register a partial chunk")
	incoming.free()
	controller.queue_free()
	object_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _test_chunk_scoped_object_registry_rollback() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var registry: Node = InstrumentedObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_object_state_registry(registry))
	var chunk_id := "earth/scoped-rollback"
	var unrelated_id := "earth/unloaded/object/SalvageCrate"
	var unrelated_state := {"opened": true, "loot_remaining": 1}
	assert(registry.call("set_object_state", unrelated_id, "earth/unloaded", unrelated_state))
	registry.set("set_calls", 0)
	registry.set("fail_after_set_calls", 1)
	var incoming: Node3D = _new_two_stateful_chunk()
	assert(not controller.load_chunk(chunk_id, incoming, now), "A failure after the first default record must reject the whole chunk")
	assert(incoming.get_parent() == null, "A failed scoped rollback leaves the caller-owned root detached")
	var first_id := chunk_id + "/object/ChunkRoot/SalvageCrate"
	var second_id := chunk_id + "/object/ChunkRoot/SalvageCrate_Second"
	assert(registry.call("get_object_state", first_id).is_empty(), "Scoped rollback removes the first newly-created record")
	assert(registry.call("get_object_state", second_id).is_empty(), "Scoped rollback leaves the rejected second record absent")
	assert(registry.call("get_object_state", unrelated_id).get("state", {}) == unrelated_state, "Scoped rollback preserves an unrelated unloaded-chunk record")
	assert(int(registry.get("full_snapshot_calls")) == 0, "Chunk load rollback never copies the full object registry")
	assert(int(registry.get("set_calls")) == 2, "The test reaches the failure after exactly one successful scoped record write")
	incoming.free()
	controller.queue_free()
	registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

	var successful_mineral_registry: Node = Registry.new()
	var successful_registry: Node = InstrumentedObjectRegistry.new()
	var successful_controller: Node3D = Controller.new()
	root.add_child(successful_mineral_registry)
	root.add_child(successful_registry)
	root.add_child(successful_controller)
	await process_frame
	assert(successful_controller.bind_registry(successful_mineral_registry))
	assert(successful_controller.bind_object_state_registry(successful_registry))
	var successful_chunk_id := "earth/scoped-success"
	var chunk: Node3D = _new_two_stateful_chunk()
	assert(successful_controller.load_chunk(successful_chunk_id, chunk, now))
	assert(int(successful_registry.get("full_snapshot_calls")) == 0, "Successful chunk load uses only the chunk-scoped snapshot")
	var first_prop: Node = chunk.get_node("SalvageCrate")
	var second_prop: Node = chunk.get_node("SalvageCrate_Second")
	var first_id := successful_chunk_id + "/object/ChunkRoot/SalvageCrate"
	var second_id := successful_chunk_id + "/object/ChunkRoot/SalvageCrate_Second"
	var first_record_before_capture: Dictionary = successful_registry.call("get_object_state", first_id)
	var second_record_before_capture: Dictionary = successful_registry.call("get_object_state", second_id)
	assert(bool(first_prop.call("interact")), "The first loaded stateful prop changes before capture")
	second_prop.set("_opened", true)
	second_prop.set("_loot_remaining", 2)
	assert(not successful_controller.capture_loaded_world_object_states(), "An invalid later prop rejects a partially-applied world-state capture")
	assert(successful_registry.call("get_object_state", first_id) == first_record_before_capture, "Capture rollback restores the earlier record written before validation failed")
	assert(successful_registry.call("get_object_state", second_id) == second_record_before_capture, "Capture rollback preserves the later record")
	assert(int(successful_registry.get("full_snapshot_calls")) == 0, "Failed loaded-state capture uses only scoped records")
	assert(bool(second_prop.call("apply_world_object_state", {"opened": false, "loot_remaining": 2})), "The invalid second prop can be repaired")
	assert(successful_controller.capture_loaded_world_object_states(), "World save capture succeeds with scoped record snapshots")
	var first_record_after_capture: Dictionary = successful_registry.call("get_object_state", first_id)
	assert(bool(first_record_after_capture.get("state", {}).get("opened", false)), "Successful capture persists the first prop's changed state")
	assert(int(successful_registry.get("full_snapshot_calls")) == 0, "Loaded-state capture avoids a full-registry snapshot")
	assert(bool(first_prop.call("apply_world_object_state", {"opened": false, "loot_remaining": 2})), "The first prop is changed after the saved state is captured")
	second_prop.set("_opened", true)
	second_prop.set("_loot_remaining", 2)
	assert(not successful_controller.unload_chunk(successful_chunk_id, now), "An invalid later prop rejects a partially-applied chunk unload")
	assert(successful_controller.is_chunk_loaded(successful_chunk_id), "A rejected unload retains controller ownership")
	assert(successful_registry.call("get_object_state", first_id) == first_record_after_capture, "Unload rollback restores the earlier record written before validation failed")
	assert(successful_registry.call("get_object_state", second_id) == second_record_before_capture, "Unload rollback preserves the later record")
	assert(int(successful_registry.get("full_snapshot_calls")) == 0, "Failed chunk unload uses only scoped records")
	assert(bool(first_prop.call("apply_world_object_state", first_record_after_capture.get("state", {}))), "The first prop can be restored to its saved state")
	assert(bool(second_prop.call("apply_world_object_state", {"opened": false, "loot_remaining": 2})), "The second prop can be repaired after rejected unload")
	assert(successful_controller.unload_chunk(successful_chunk_id, now), "Chunk unload succeeds with scoped record snapshots")
	assert(int(successful_registry.get("full_snapshot_calls")) == 0, "Chunk unload avoids a full-registry snapshot")
	successful_controller.queue_free()
	successful_registry.queue_free()
	successful_mineral_registry.queue_free()
	await process_frame

	var legacy_registry: Node = LegacyObjectRegistry.new()
	var legacy_controller: Node3D = Controller.new()
	root.add_child(legacy_registry)
	root.add_child(legacy_controller)
	await process_frame
	assert(legacy_controller.bind_object_state_registry(legacy_registry))
	var legacy_target := "earth/legacy/object/SalvageCrate"
	var legacy_unrelated := "earth/legacy-unloaded/object/SalvageCrate"
	var legacy_target_state := {"opened": false, "loot_remaining": 2}
	var legacy_unrelated_state := {"opened": true, "loot_remaining": 1}
	assert(legacy_registry.call("set_object_state", legacy_target, "earth/legacy", legacy_target_state))
	assert(legacy_registry.call("set_object_state", legacy_unrelated, "earth/legacy-unloaded", legacy_unrelated_state))
	var legacy_ids: Array[String] = [legacy_target]
	var legacy_snapshot: Dictionary = legacy_controller.call("_capture_world_object_registry_snapshot", legacy_ids)
	assert(str(legacy_snapshot.get("mode", "")) == "full", "Older registries without forget_object_state use the full-save fallback")
	assert(legacy_registry.call("set_object_state", legacy_target, "earth/legacy", {"opened": true, "loot_remaining": 1}))
	assert(legacy_registry.call("set_object_state", legacy_unrelated, "earth/legacy-unloaded", {"opened": false, "loot_remaining": 2}))
	assert(legacy_controller.call("_restore_world_object_registry_snapshot", legacy_snapshot), "Legacy full-snapshot fallback restores successfully")
	assert(legacy_registry.call("get_object_state", legacy_target).get("state", {}) == legacy_target_state, "Legacy fallback restores the target record")
	assert(legacy_registry.call("get_object_state", legacy_unrelated).get("state", {}) == legacy_unrelated_state, "Legacy fallback preserves its historical whole-registry semantics")
	legacy_controller.queue_free()
	legacy_registry.queue_free()
	await process_frame

func _test_invalid_mineral_binding_rejected_before_chunk_registration() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var crop_registry: Node = CropRegistry.new()
	var crop_controller: Node = CropController.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(crop_registry)
	root.add_child(crop_controller)
	root.add_child(controller)
	await process_frame
	assert(crop_controller.bind_registry(crop_registry))
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_crop_controller(crop_controller))

	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var plot: Node3D = CropPlot.new()
	plot.name = "CropPlot_0"
	plot.set("crop_id", "wheat")
	plot.set("plot_index", 1)
	chunk.add_child(plot)
	var invalid_vein: Node3D = MiningNode.new()
	invalid_vein.name = "InvalidVein"
	invalid_vein.set("mineral_id", "missing_mineral")
	invalid_vein.set("last_regen_unix", now)
	chunk.add_child(invalid_vein)
	assert(not bool(invalid_vein.call("can_register")), "unknown mineral IDs fail the pure registration preflight")
	assert(not controller.load_chunk("earth/mineral-preflight", chunk, now), "invalid mineral data rejects the whole chunk before crop binding")
	assert(chunk.get_parent() == null, "rejected mineral chunk remains caller-owned and detached")
	assert(crop_registry.get_saved_ids().is_empty(), "invalid mineral preflight prevents a sibling crop from creating a partial registry record")
	assert(mineral_registry.get_registered_ids().is_empty(), "invalid mineral preflight does not register any vein")
	assert(not controller.is_chunk_loaded("earth/mineral-preflight"), "invalid mineral preflight does not register a partial chunk")
	chunk.free()

	var adapter: Node = Adapter.new()
	root.add_child(adapter)
	await process_frame
	assert(bool(adapter.call("bind_registry", mineral_registry)))
	var valid_vein: Node3D = MiningNode.new()
	valid_vein.name = "ValidVein"
	valid_vein.set("mineral_id", "iron_ore")
	valid_vein.set("max_units", 8)
	valid_vein.set("remaining_units", 4)
	valid_vein.set("last_regen_unix", now)
	var adapter_invalid_vein: Node3D = MiningNode.new()
	adapter_invalid_vein.name = "AdapterInvalidVein"
	adapter_invalid_vein.set("mineral_id", "unknown_mineral")
	adapter_invalid_vein.set("last_regen_unix", now)
	assert(not bool(adapter.call("load_chunk", "earth/adapter-preflight", {"valid": valid_vein, "invalid": adapter_invalid_vein}, now)), "adapter independently preflights every vein before registering any")
	assert(mineral_registry.get_registered_ids().is_empty(), "adapter preflight leaves no partial mineral registration")
	var adapter_loaded_ids: PackedStringArray = adapter.call("get_loaded_chunk_ids")
	assert(adapter_loaded_ids.is_empty(), "adapter preflight does not mark a rejected chunk as loaded")
	valid_vein.free()
	adapter_invalid_vein.free()
	adapter.queue_free()
	controller.queue_free()
	crop_controller.queue_free()
	crop_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _test_invalid_crop_binding_rejected_before_chunk_registration() -> void:
	var mineral_registry: Node = Registry.new()
	var crop_registry: Node = CropRegistry.new()
	var crop_controller: Node = CropController.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(crop_registry)
	root.add_child(crop_controller)
	root.add_child(controller)
	await process_frame
	assert(crop_controller.bind_registry(crop_registry))
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_crop_controller(crop_controller))
	var chunk_id := "earth/crop-sector"
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var plot: Node3D = CropPlot.new()
	plot.name = "CropPlot_0"
	plot.set("crop_id", "unknown_crop")
	plot.set("plot_index", 1)
	chunk.add_child(plot)
	var valid_stable_id := chunk_id + "/crop/ChunkRoot/CropPlot_0"
	assert(not bool(plot.call("can_configure", crop_controller, valid_stable_id, "unknown_crop", 1)), "unsupported crop kinds fail the binding preflight")
	assert(not bool(plot.call("can_configure", crop_controller, "earth//crop/plot", "wheat", 1)), "repeated stable-ID separators are rejected")
	assert(not bool(plot.call("can_configure", crop_controller, valid_stable_id, "wheat", 0)), "non-positive plot indices are rejected")
	var incomplete_controller := Node.new()
	assert(not bool(plot.call("can_configure", incomplete_controller, valid_stable_id, "wheat", 1)), "controllers missing required crop lifecycle methods are rejected")
	incomplete_controller.free()
	assert(not controller.load_chunk(chunk_id, chunk), "chunk loading rejects an invalid crop binding before registration")
	assert(chunk.get_parent() == null, "rejected crop chunk remains caller-owned and detached")
	assert(crop_registry.get_saved_ids().is_empty(), "rejected crop binding does not create a partial crop record")
	assert(not controller.is_chunk_loaded(chunk_id), "rejected crop binding does not register a partial chunk")
	chunk.free()
	controller.queue_free()
	crop_controller.queue_free()
	crop_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _test_corner_report_proxy_is_defensive() -> void:
	var controller: Node3D = Controller.new()
	root.add_child(controller)
	var manager := FakeCornerManager.new()
	manager.reports = [{
		"stable_id": "surface/patch_4_4",
		"corner": "north_east",
		"edge_keys": ["edge_east", "edge_north"],
		"policy": "step_fallback"
	}]
	controller.add_child(manager)
	controller.set("_terrain_transition_collider_manager", manager)
	var reports: Array[Dictionary] = controller.call("get_blocked_terrain_corner_reports")
	assert(reports.size() == 1, "Controller exposes the manager's blocked corner report")
	assert(str(reports[0].get("corner", "")) == "north_east", "Controller preserves the reported corner orientation")
	reports[0]["corner"] = "tampered"
	var copied_edges: Array = reports[0].get("edge_keys", [])
	copied_edges.append("tampered")
	assert(str(manager.reports[0].get("corner", "")) == "north_east", "Mutating the returned report cannot change manager state")
	var manager_edges: Array = manager.reports[0].get("edge_keys", [])
	assert(manager_edges.size() == 2, "Nested edge-key arrays are deep-copied")
	controller.queue_free()
	await process_frame

func _new_stateful_chunk() -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var crate: Node3D = StatefulProp.new()
	crate.name = "SalvageCrate"
	chunk.add_child(crate)
	return chunk

func _new_two_stateful_chunk() -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var first: Node3D = StatefulProp.new()
	first.name = "SalvageCrate"
	chunk.add_child(first)
	var second: Node3D = StatefulProp.new()
	second.name = "SalvageCrate_Second"
	chunk.add_child(second)
	return chunk

func _new_mineral_chunk(units: int, regen_time: int) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var vein: Node3D = MiningNode.new()
	vein.name = "gold-01"
	vein.mineral_id = "gold_ore"
	vein.max_units = 8
	vein.remaining_units = units
	vein.regen_interval_seconds = 60
	vein.last_regen_unix = regen_time
	chunk.add_child(vein)
	return chunk

func _new_two_mineral_chunk(now: int) -> Node3D:
	var chunk: Node3D = _new_mineral_chunk(3, now)
	var second: Node3D = MiningNode.new()
	second.name = "iron-02"
	second.mineral_id = "iron_ore"
	second.max_units = 8
	second.remaining_units = 5
	second.regen_interval_seconds = 60
	second.last_regen_unix = now
	chunk.add_child(second)
	return chunk
