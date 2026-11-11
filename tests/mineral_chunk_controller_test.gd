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

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_single_pass_chunk_content_collection()
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
	await _test_invalid_mineral_binding_rejected_before_chunk_registration()
	await process_frame
	await _test_invalid_crop_binding_rejected_before_chunk_registration()
	await process_frame
	await _test_corner_report_proxy_is_defensive()
	await process_frame
	print("Mineral chunk controller integration tests passed.")
	quit(0)

func _test_single_pass_chunk_content_collection() -> void:
	var controller: Node3D = Controller.new()
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var gold: Node3D = MiningNode.new()
	gold.name = "gold-01"
	var crop: Node3D = CropPlot.new()
	crop.name = "CropPlot_0"
	var prop: Node3D = StatefulProp.new()
	prop.name = "SalvageCrate"
	var decor := Node3D.new()
	decor.name = "Decor"
	var iron: Node3D = MiningNode.new()
	iron.name = "iron-02"
	decor.add_child(iron)
	chunk.add_child(gold)
	chunk.add_child(crop)
	chunk.add_child(prop)
	chunk.add_child(decor)

	var veins: Dictionary = {}
	var crops: Dictionary = {}
	var world_objects: Dictionary = {}
	assert(bool(controller.call(
		"_collect_chunk_content_nodes",
		chunk,
		"ChunkRoot",
		veins,
		crops,
		world_objects
	)), "Single-pass collection accepts a valid mixed Chunk tree")
	assert(veins.size() == 2, "Single-pass collection discovers every mineral vein")
	assert(veins.get("ChunkRoot/gold-01") == gold, "Single-pass collection preserves the root-level mineral path")
	assert(veins.get("ChunkRoot/Decor/iron-02") == iron, "Single-pass collection preserves nested mineral paths")
	assert(crops.size() == 1 and crops.get("ChunkRoot/CropPlot_0") == crop, "Single-pass collection preserves crop paths")
	assert(world_objects.size() == 1 and world_objects.get("ChunkRoot/SalvageCrate") == prop, "Single-pass collection preserves stateful world-object paths")

	# Compare with the former category collectors to guard exact discovery semantics.
	var legacy_veins: Dictionary = {}
	var legacy_crops: Dictionary = {}
	var legacy_objects: Dictionary = {}
	assert(bool(controller.call("_collect_mineral_nodes", chunk, "ChunkRoot", legacy_veins)))
	assert(bool(controller.call("_collect_crop_plots", chunk, "ChunkRoot", legacy_crops)))
	assert(bool(controller.call("_collect_world_state_nodes", chunk, "ChunkRoot", legacy_objects)))
	assert(veins == legacy_veins, "Combined mineral discovery matches the former mineral collector")
	assert(crops == legacy_crops, "Combined crop discovery matches the former crop collector")
	assert(world_objects == legacy_objects, "Combined world-object discovery matches the former object collector")

	var invalid_veins: Dictionary = {}
	var invalid_crops: Dictionary = {}
	var invalid_objects: Dictionary = {}
	assert(not bool(controller.call(
		"_collect_chunk_content_nodes",
		chunk,
		"ChunkRoot//Invalid",
		invalid_veins,
		invalid_crops,
		invalid_objects
	)), "Single-pass collection preserves invalid stable-path rejection")
	chunk.free()
	controller.free()

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
