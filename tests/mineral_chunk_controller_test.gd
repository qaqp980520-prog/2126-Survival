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
const TerrainPatchScript = preload("res://systems/SurfaceTerrainPatch.gd")

class FakeCornerManager extends Node3D:
	var reports: Array[Dictionary] = []

	func get_blocked_corner_reports() -> Array[Dictionary]:
		return reports.duplicate(true)

class FaultInjectingTerrainPatch extends "res://systems/SurfaceTerrainPatch.gd":
	var invalid_profile: bool = false

	func get_edge_ramp_profile() -> Dictionary:
		if invalid_profile:
			return {"patch_size": 0.0}
		return super.get_edge_ramp_profile()

class FaultInjectingStatefulProp extends "res://systems/WorldObjectStatefulProp.gd":
	var fail_apply_count: int = 0

	func apply_world_object_state(state: Dictionary) -> bool:
		var applied: bool = super.apply_world_object_state(state)
		if fail_apply_count > 0:
			fail_apply_count -= 1
			return false
		return applied

class FaultInjectingObjectRegistry extends "res://systems/WorldObjectStateRegistry.gd":
	var fail_set_after_commit_count: int = 0
	var fail_restore_count: int = 0

	func set_object_state(stable_id: String, chunk_id: String, state: Dictionary) -> bool:
		var succeeded: bool = super.set_object_state(stable_id, chunk_id, state)
		if succeeded and fail_set_after_commit_count > 0:
			fail_set_after_commit_count -= 1
			return false
		return succeeded

	func restore_save_dict(data: Dictionary) -> bool:
		if fail_restore_count > 0:
			fail_restore_count -= 1
			return false
		return super.restore_save_dict(data)

class FaultInjectingCropController extends "res://systems/CropPlotController.gd":
	var fail_restore_count: int = 0

	func restore_save_dict(payload: Dictionary) -> bool:
		if fail_restore_count > 0:
			fail_restore_count -= 1
			return false
		return super.restore_save_dict(payload)

class FaultInjectingMiningNode extends "res://systems/MineralMiningNode.gd":
	var fail_apply_count: int = 0

	func load_save_dict(data: Dictionary, now_unix: int = -1, apply_elapsed: bool = true) -> bool:
		var loaded: bool = super.load_save_dict(data, now_unix, apply_elapsed)
		if not loaded:
			return false
		if fail_apply_count > 0:
			fail_apply_count -= 1
			return false
		return true

class FaultInjectingMineralRegistry extends "res://systems/MineralVeinRegistry.gd":
	var fail_rollback_count: int = 0

	func _restore_live_vein_state(vein: Node, snapshot: Dictionary) -> void:
		super._restore_live_vein_state(vein, snapshot)
		if fail_rollback_count > 0:
			fail_rollback_count -= 1
			vein.set("remaining_units", int(vein.get("max_units")))
			vein.set("visible", true)

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_chunk_save_unload_reload_with_offline_regeneration()
	await process_frame
	await _test_empty_chunk_and_duplicate_id()
	await process_frame
	await _test_failed_load_preserves_caller_root()
	await process_frame
	await _test_failed_load_preflight_is_atomic_for_all_veins()
	await process_frame
	await _test_new_mineral_regeneration_uses_explicit_chunk_timestamp()
	await process_frame
	await _test_failed_unload_preflight_is_atomic_for_all_veins()
	await process_frame
	await _test_failed_unload_preserves_terrain_adjacency()
	await process_frame
	await _test_stateful_object_survives_unload_reload()
	await process_frame
	await _test_failed_object_state_application_is_atomic()
	await process_frame
	await _test_incomplete_chunk_load_rollback_is_reported_and_recoverable()
	await process_frame
	await _test_incomplete_mineral_registry_rollback_is_reported_and_recoverable()
	await process_frame
	await _test_incomplete_chunk_unload_registry_rollback_is_reported_and_recoverable()
	await process_frame
	await _test_invalid_mineral_binding_rejected_before_chunk_registration()
	await process_frame
	await _test_invalid_crop_binding_rejected_before_chunk_registration()
	await process_frame
	await _test_corner_report_proxy_is_defensive()
	await process_frame
	print("Mineral chunk controller integration tests passed.")
	quit(0)

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

func _test_new_mineral_regeneration_uses_explicit_chunk_timestamp() -> void:
	var now: int = int(Time.get_unix_time_from_system()) - 120
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))

	var chunk_id := "earth/mineral-explicit-load-clock"
	var incoming: Node3D = _new_mineral_chunk(3, now - 120)
	var vein: Node = incoming.get_node("gold-01")
	assert(controller.load_chunk(chunk_id, incoming, now), "A new chunk without a saved mineral record loads successfully")
	assert(int(vein.get("remaining_units")) == 5, "Deferred _ready regeneration is applied exactly twice at the supplied load timestamp")
	assert(int(vein.get("last_regen_unix")) == now, "New-vein regeneration clock ends at the explicit load timestamp")
	assert(not bool(vein.call("is_chunk_load_restore_pending")), "Successful load clears the one-shot ready-regeneration guard")
	var stable_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	var saved_record: Dictionary = registry.to_save_dict().get("veins", {}).get(stable_id, {})
	assert(int(saved_record.get("remaining_units", -1)) == 5, "Registry commits the same once-regenerated state as the live node")
	assert(controller.unload_chunk(chunk_id, now), "The explicit-clock chunk unloads after successful registration")
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

func _test_failed_load_preflight_is_atomic_for_all_veins() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry: Node = Registry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))

	var chunk_id := "earth/mineral-load-atomic"
	var first_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/gold-01")
	var second_id: String = Adapter.make_stable_id(chunk_id, "ChunkRoot/iron-02")
	var saved_first: Dictionary = {
		"schema_version": 2,
		"mineral_id": "gold_ore",
		"remaining_units": 3,
		"max_units": 8,
		"regen_interval_seconds": 60,
		"last_regen_unix": now - 120
	}
	var saved_second: Dictionary = saved_first.duplicate(true)
	saved_second["remaining_units"] = 2
	var payload: Dictionary = {
		"schema_version": 1,
		"veins": {
			first_id: saved_first,
			second_id: saved_second
		}
	}
	assert(registry.restore_save_dict(payload, now), "Seed two valid unloaded records before the load transaction")
	var registry_before: Dictionary = registry.to_save_dict()

	var incoming: Node3D = _new_two_mineral_chunk(now)
	var first: Node = incoming.get_node("gold-01")
	var second: Node = incoming.get_node("iron-02")
	# A detached root with an old authored timestamp must not regenerate in _ready()
	# before the later saved-record mismatch rejects the complete transaction.
	first.set("last_regen_unix", now - 120)
	var first_before: Dictionary = first.call("to_save_dict")
	var second_before: Dictionary = second.call("to_save_dict")
	assert(not controller.load_chunk(chunk_id, incoming, now), "A later saved-record mineral mismatch rejects the whole chunk load")
	assert(incoming.get_parent() == null, "Rejected load leaves the caller-owned chunk detached")
	assert(not controller.is_chunk_loaded(chunk_id), "Rejected load does not publish chunk ownership")
	assert(first.call("to_save_dict") == first_before, "Rejected load does not apply elapsed regeneration to the earlier live vein")
	assert(second.call("to_save_dict") == second_before, "Rejected load does not mutate the rejected live vein")
	assert(not bool(first.call("is_chunk_load_restore_pending")) and not bool(second.call("is_chunk_load_restore_pending")), "Rejected load clears the one-shot ready-regeneration guard")
	assert(registry.to_save_dict() == registry_before, "Rejected load preserves the complete saved registry payload")
	assert(registry.get_registered_ids().is_empty(), "Rejected load registers no live vein")

	var repaired_payload: Dictionary = registry_before.duplicate(true)
	repaired_payload["veins"][second_id]["mineral_id"] = "iron_ore"
	assert(registry.restore_save_dict(repaired_payload, now), "Repair the later saved record without changing the earlier record")
	assert(controller.load_chunk(chunk_id, incoming, now), "The same caller-owned chunk succeeds after repairing the saved record")
	assert(controller.is_chunk_loaded(chunk_id), "Successful retry publishes chunk ownership")
	assert(registry.get_registered_ids().has(first_id) and registry.get_registered_ids().has(second_id), "Successful retry registers every vein")
	assert(int(first.get("remaining_units")) == 5, "First saved vein receives exactly two offline regeneration intervals")
	assert(int(second.get("remaining_units")) == 4, "Second saved vein receives exactly two offline regeneration intervals")
	assert(controller.unload_chunk(chunk_id, now), "The successfully loaded chunk can be atomically unloaded")
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_failed_unload_preflight_is_atomic_for_all_veins() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var unload_time: int = now + 120
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
	var first: Node = chunk.get_node("gold-01")
	var second: Node = chunk.get_node("iron-02")
	var first_state_before: Dictionary = first.call("to_save_dict")
	second.set("mineral_id", "missing_mineral")
	var registry_before: Dictionary = registry.call("to_save_dict")
	assert(not controller.unload_chunk(chunk_id, unload_time), "Invalid second vein must abort the complete chunk unload")
	assert(controller.is_chunk_loaded(chunk_id), "Failed unload must retain controller ownership")
	assert(controller.get_chunk_root(chunk_id) == chunk)
	assert(chunk.get_parent() == controller)
	assert(registry.get_registered_ids().has(first_id), "Atomic preflight keeps the first vein registered")
	assert(registry.get_registered_ids().has(second_id), "Atomic preflight keeps the rejected vein registered")
	assert(first.call("to_save_dict") == first_state_before, "A rejected batch must not advance regeneration on an earlier vein")
	assert(registry.call("to_save_dict") == registry_before, "A rejected batch must preserve the entire mineral registry snapshot")
	second.set("mineral_id", "iron_ore")
	assert(controller.unload_chunk(chunk_id, unload_time), "Unload should succeed after repairing invalid vein data")
	var saved_veins: Dictionary = registry.call("to_save_dict").get("veins", {})
	assert(int(saved_veins.get(first_id, {}).get("remaining_units", -1)) == 5, "Successful atomic unload applies the two elapsed regeneration intervals")
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_failed_unload_preserves_terrain_adjacency() -> void:
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

	var chunk_a: Node3D = _new_terrain_patch_chunk("ChunkA", Vector3.ZERO, 0)
	var chunk_b: Node3D = _new_terrain_patch_chunk("ChunkB", Vector3(TerrainPatchScript.PATCH_SIZE, 0.0, 0.0), 2)
	assert(controller.load_chunk("terrain/chunk-a", chunk_a, now))
	assert(controller.load_chunk("terrain/chunk-b", chunk_b, now))
	var patch_a: Node3D = chunk_a.get_node("TerrainPatch") as Node3D
	var patch_b: Node3D = chunk_b.get_node("TerrainPatch") as Node3D
	var edge_policy_a: Dictionary = patch_a.call("get_edge_policy", "east")
	var edge_policy_b: Dictionary = patch_b.call("get_edge_policy", "west")
	assert(str(edge_policy_a.get("mode", "")) == "neighbor_higher", "Loaded terrain patches bind the expected higher-neighbor edge")
	assert(str(edge_policy_b.get("mode", "")) == "local_higher", "The reciprocal terrain edge has the matching local-higher policy")
	var descriptors_before: Dictionary = controller.call("get_terrain_transition_descriptors")
	assert(descriptors_before.size() == 1, "Adjacent unequal-height patches publish one transition descriptor")
	var edge_key: String = str(descriptors_before.keys()[0])
	var collider_before: StaticBody3D = controller.call("get_terrain_transition_collider", edge_key) as StaticBody3D
	assert(is_instance_valid(collider_before), "The transition collider is live before the unload attempt")
	assert(int(controller.call("get_terrain_transition_collider_count")) == 1, "The controller owns one live transition collider")
	var object_registry_before: Dictionary = object_registry.call("to_save_dict")

	# Corrupt only the remaining patch's live state. Binder rejects it during preflight,
	# before clearing either side of the existing reciprocal edge.
	patch_b.set("invalid_profile", true)
	assert(not bool(controller.call("unload_chunk", "terrain/chunk-a", now)), "Unload rejects a candidate terrain set that fails Binder preflight")
	assert(bool(controller.call("is_chunk_loaded", "terrain/chunk-a")), "Rejected unload retains the departing chunk ownership")
	assert(controller.call("get_chunk_root", "terrain/chunk-a") == chunk_a, "Rejected unload retains the exact original chunk root")
	assert(chunk_a.get_parent() == controller, "Rejected unload keeps the original root attached")
	assert(controller.call("get_terrain_transition_descriptors") == descriptors_before, "Binder preflight failure preserves the prior descriptors")
	assert(int(controller.call("get_terrain_transition_collider_count")) == 1, "Binder preflight failure preserves the prior collider count")
	assert(controller.call("get_terrain_transition_collider", edge_key) == collider_before, "Binder preflight failure preserves the exact prior collider instance")
	assert(patch_a.call("get_edge_policy", "east") == edge_policy_a, "Binder preflight failure preserves the departing patch's live edge policy")
	assert(patch_b.call("get_edge_policy", "west") == edge_policy_b, "Binder preflight failure preserves the remaining patch's reciprocal edge policy")
	assert(object_registry.call("to_save_dict") == object_registry_before, "Rejected unload restores the complete object registry snapshot")
	assert(bool(controller.call("has_pending_terrain_adjacency_recovery")), "A failed terrain preflight marks adjacency recovery as required")

	assert(not bool(controller.call("unload_chunk", "terrain/chunk-b", now)), "Further unloads fail closed while the remaining patch is invalid")
	assert(bool(controller.call("is_chunk_loaded", "terrain/chunk-b")), "Fail-closed recovery retains the second chunk")
	patch_b.set("invalid_profile", false)
	assert(bool(controller.call("refresh_terrain_adjacency")), "A successful full Binder refresh clears the recovery barrier")
	assert(not bool(controller.call("has_pending_terrain_adjacency_recovery")), "Successful refresh clears the recovery-required state")
	assert(bool(controller.call("unload_chunk", "terrain/chunk-a", now)), "Unload succeeds after terrain adjacency recovery")
	assert(not bool(controller.call("is_chunk_loaded", "terrain/chunk-a")), "Successful unload releases the departing chunk")
	assert(bool(controller.call("is_chunk_loaded", "terrain/chunk-b")), "Successful unload retains the remaining chunk")
	assert(controller.call("get_terrain_transition_descriptors").is_empty(), "Successful unload removes the departed seam descriptor")
	assert(int(controller.call("get_terrain_transition_collider_count")) == 0, "Successful unload retires the departed seam collider")
	assert(str(patch_b.call("get_edge_policy", "west").get("mode", "")) == "ground_ramp", "Successful unload restores the remaining patch's outer ground ramp")

	controller.queue_free()
	object_registry.queue_free()
	mineral_registry.queue_free()
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

func _test_incomplete_chunk_load_rollback_is_reported_and_recoverable() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var crop_registry: Node = CropRegistry.new()
	var crop_controller: Node = FaultInjectingCropController.new()
	var object_registry: Node = ObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(crop_registry)
	root.add_child(crop_controller)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	assert(crop_controller.bind_registry(crop_registry))
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_crop_controller(crop_controller))
	assert(controller.bind_object_state_registry(object_registry))

	var chunk_id := "earth/aggregate-load-rollback"
	var crop_id := chunk_id + "/crop/ChunkRoot/CropPlot_0"
	var object_id := chunk_id + "/object/ChunkRoot/FaultProp"
	assert(crop_registry.register_crop(crop_id, "wheat", 0, 0.0, 80.0, now - 120, 0))
	assert(object_registry.set_object_state(object_id, chunk_id, {"opened": true, "loot_remaining": 1}))
	var crop_before: Dictionary = crop_registry.to_save_dict()
	var object_before: Dictionary = object_registry.to_save_dict()

	var incoming := Node3D.new()
	incoming.name = "ChunkRoot"
	var plot: Node3D = _new_crop_plot()
	incoming.add_child(plot)
	var prop: Node = FaultInjectingStatefulProp.new()
	prop.name = "FaultProp"
	prop.set("fail_apply_count", 2)
	incoming.add_child(prop)
	crop_controller.set("fail_restore_count", 1)

	assert(not controller.load_chunk(chunk_id, incoming, now), "A world-object apply failure rejects the complete chunk load")
	assert(incoming.get_parent() == null, "The rejected root remains caller-owned and detached")
	assert(controller.has_pending_chunk_load_recovery(), "A failed crop/live-object rollback blocks further chunk lifecycle changes")
	var report: Dictionary = controller.get_last_chunk_load_report()
	var details: Dictionary = report.get("details", {})
	assert(str(report.get("phase", "")) == "world_object_restore")
	assert(not bool(report.get("rollback_complete", true)), "The Controller must not report a complete rollback when a participant rejects restoration")
	assert(not bool(details.get("world_object_live_nodes_ok", true)), "The failed live-object rollback is surfaced")
	assert(bool(details.get("world_object_registry_ok", false)), "The object registry snapshot was restored")
	assert(not bool(details.get("crop_registry_ok", true)), "The failed crop registry restore is surfaced")
	assert(crop_registry.to_save_dict() != crop_before, "The injected crop restore failure leaves a detectable pending recovery")
	var blocked_root := Node3D.new()
	assert(not controller.load_chunk("earth/blocked-during-recovery", blocked_root, now), "New chunk loads are blocked while participant recovery is pending")
	assert(blocked_root.get_parent() == null)
	blocked_root.free()

	assert(controller.recover_failed_chunk_load(), "A later recovery pass retries every failed participant")
	assert(not controller.has_pending_chunk_load_recovery(), "Successful recovery clears the lifecycle barrier")
	assert(crop_registry.to_save_dict() == crop_before, "Recovery restores the exact crop registry snapshot")
	assert(object_registry.to_save_dict() == object_before, "Recovery restores the exact world-object registry snapshot")
	assert(prop.call("get_world_object_state") == {"opened": false, "loot_remaining": 2, "loot_item_id": "iron_ore"}, "Recovery restores the caller-owned live object state")
	var recovery_report: Dictionary = controller.get_last_chunk_load_report()
	assert(bool(recovery_report.get("success", false)) and str(recovery_report.get("phase", "")) == "recovery_complete")

	assert(controller.load_chunk(chunk_id, incoming, now), "The same caller-owned root can be retried after recovery")
	assert(bool(prop.get("opened")) and int(prop.get("loot_remaining")) == 1, "The retry applies the saved object state")
	assert(controller.unload_chunk(chunk_id, now), "The recovered chunk can complete a normal unload")
	controller.queue_free()
	object_registry.queue_free()
	crop_controller.queue_free()
	crop_registry.queue_free()
	mineral_registry.queue_free()
	await process_frame

func _test_incomplete_mineral_registry_rollback_is_reported_and_recoverable() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var registry: Node = FaultInjectingMineralRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(registry))

	var incoming := Node3D.new()
	incoming.name = "ChunkRoot"
	var vein: Node = FaultInjectingMiningNode.new()
	vein.name = "gold-01"
	vein.set("mineral_id", "gold_ore")
	vein.set("max_units", 8)
	vein.set("remaining_units", 3)
	vein.set("regen_interval_seconds", 60)
	vein.set("last_regen_unix", now)
	vein.set("fail_apply_count", 1)
	incoming.add_child(vein)
	var vein_before: Dictionary = vein.call("to_save_dict")
	registry.set("fail_rollback_count", 1)

	assert(not controller.load_chunk("earth/mineral-registry-recovery", incoming, now), "An injected live mineral apply failure rejects the chunk")
	assert(incoming.get_parent() == null, "The failed mineral candidate remains caller-owned")
	assert(registry.call("has_pending_atomic_registration_recovery"), "The Registry retains a recovery record when live-node rollback verification fails")
	assert(controller.has_pending_chunk_load_recovery(), "The Controller raises its cross-system recovery barrier")
	var report: Dictionary = controller.get_last_chunk_load_report()
	var details: Dictionary = report.get("details", {})
	assert(str(report.get("phase", "")) == "mineral_registration")
	assert(not bool(report.get("rollback_complete", true)))
	assert(not bool(details.get("mineral_registry_rollback_ok", true)))
	assert(bool(details.get("mineral_registry_recovery_required", false)))
	assert(controller.recover_failed_chunk_load(), "Controller recovery delegates to the pending Registry participant")
	assert(not registry.call("has_pending_atomic_registration_recovery"))
	assert(not controller.has_pending_chunk_load_recovery())
	assert(vein.call("to_save_dict") == vein_before, "Registry recovery restores the exact live mineral snapshot")

	assert(controller.load_chunk("earth/mineral-registry-recovery", incoming, now), "The same candidate can be retried after mineral recovery")
	assert(controller.unload_chunk("earth/mineral-registry-recovery", now))
	controller.queue_free()
	registry.queue_free()
	await process_frame

func _test_incomplete_chunk_unload_registry_rollback_is_reported_and_recoverable() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var mineral_registry: Node = Registry.new()
	var object_registry: Node = FaultInjectingObjectRegistry.new()
	var controller: Node3D = Controller.new()
	root.add_child(mineral_registry)
	root.add_child(object_registry)
	root.add_child(controller)
	await process_frame
	assert(controller.bind_registry(mineral_registry))
	assert(controller.bind_object_state_registry(object_registry))

	var chunk_id := "earth/object-unload-recovery"
	var chunk: Node3D = _new_stateful_chunk()
	assert(controller.load_chunk(chunk_id, chunk, now))
	var stable_id := chunk_id + "/object/ChunkRoot/SalvageCrate"
	var crate: Node = chunk.get_node("SalvageCrate")
	assert(bool(crate.call("interact")), "The live crate changes before the unload attempt")
	var registry_before: Dictionary = object_registry.to_save_dict()
	object_registry.set("fail_set_after_commit_count", 1)
	object_registry.set("fail_restore_count", 1)

	assert(not controller.unload_chunk(chunk_id, now), "A registry write that commits then rejects, followed by a failed snapshot restore, rejects unload")
	assert(controller.is_chunk_loaded(chunk_id), "Failed unload retains Controller ownership of the original chunk")
	assert(chunk.get_parent() == controller, "Failed unload keeps the original root attached")
	assert(controller.has_pending_chunk_load_recovery(), "Failed world-object registry restoration raises the lifecycle recovery barrier")
	var report: Dictionary = controller.get_last_chunk_load_report()
	var details: Dictionary = report.get("details", {})
	assert(str(report.get("phase", "")) == "world_object_capture")
	assert(not bool(report.get("rollback_complete", true)), "The Controller must not claim a complete rollback when registry restoration failed")
	assert(bool(report.get("recovery_required", false)))
	assert(not bool(details.get("world_object_registry_rollback_ok", true)))
	assert(object_registry.to_save_dict() != registry_before, "The injected restore failure leaves a detectable pending registry mutation")

	var blocked_root := Node3D.new()
	assert(not controller.load_chunk("earth/blocked-during-unload-recovery", blocked_root, now), "New loads are blocked during unload recovery")
	assert(not controller.unload_chunk(chunk_id, now), "Further unloads are blocked during unload recovery")
	assert(blocked_root.get_parent() == null)
	blocked_root.free()

	assert(controller.recover_failed_chunk_load(), "The shared recovery entry point retries the failed unload participant")
	assert(not controller.has_pending_chunk_load_recovery(), "Successful object-registry recovery clears the lifecycle barrier")
	assert(object_registry.to_save_dict() == registry_before, "Recovery restores the exact pre-unload object registry snapshot")
	assert(controller.is_chunk_loaded(chunk_id) and chunk.get_parent() == controller, "Recovery keeps the original chunk available for retry")

	assert(controller.unload_chunk(chunk_id, now), "The same chunk can unload after recovery")
	var saved_state: Dictionary = object_registry.get_object_state(stable_id).get("state", {})
	assert(bool(saved_state.get("opened", false)) and int(saved_state.get("loot_remaining", -1)) == 1, "Successful retry captures the live object's current state")
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

func _new_terrain_patch_chunk(chunk_name: String, world_position: Vector3, height_level: int) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = chunk_name
	chunk.position = world_position
	var patch: Node3D = FaultInjectingTerrainPatch.new()
	patch.name = "TerrainPatch"
	patch.set("_height_level", height_level)
	chunk.add_child(patch)
	return chunk

func _new_stateful_chunk() -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "ChunkRoot"
	var crate: Node3D = StatefulProp.new()
	crate.name = "SalvageCrate"
	chunk.add_child(crate)
	return chunk

func _new_crop_plot() -> Node3D:
	var plot: Node3D = CropPlot.new()
	plot.name = "CropPlot_0"
	plot.set("crop_id", "wheat")
	plot.set("plot_index", 1)
	for child_name in ["CropStem", "CropFruit", "CropTypeMarker"]:
		var mesh := MeshInstance3D.new()
		mesh.name = child_name
		mesh.material_override = StandardMaterial3D.new()
		plot.add_child(mesh)
	return plot

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
