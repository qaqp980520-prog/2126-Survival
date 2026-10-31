extends SceneTree

const RegistryScript = preload("res://systems/CropRegistry.gd")
const CropControllerScript = preload("res://systems/CropPlotController.gd")
const ChunkControllerScript = preload("res://systems/MineralChunkController.gd")
const MineralRegistryScript = preload("res://systems/MineralVeinRegistry.gd")
const AdapterScript = preload("res://systems/MineralChunkLifecycleAdapter.gd")
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const CropPlotScene = preload("res://systems/CropPlotVisual.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var now: int = int(Time.get_unix_time_from_system())
    var registry: Node = RegistryScript.new()
    var crop_controller: Node = CropControllerScript.new()
    var mineral_registry: Node = MineralRegistryScript.new()
    var chunk_controller: Node3D = ChunkControllerScript.new()
    root.add_child(registry)
    root.add_child(crop_controller)
    root.add_child(mineral_registry)
    root.add_child(chunk_controller)
    await process_frame
    assert(crop_controller.bind_registry(registry))
    assert(chunk_controller.bind_registry(mineral_registry))
    assert(chunk_controller.bind_crop_controller(crop_controller))

    var chunk_id := "surface/offline-growth-test"
    var first_root := _new_chunk()
    assert(chunk_controller.load_chunk(chunk_id, first_root, now))
    var stable_id := chunk_id + "/crop/ChunkRoot/CropPlot_0"
    assert(crop_controller.plant_crop(stable_id, "wheat", 60.0, now))
    assert(crop_controller.advance_crop(stable_id, 120.0, now + 120))
    var before_unload: Dictionary = crop_controller.get_crop(stable_id)
    assert(int(before_unload.get("growth_stage", -1)) == 1)
    assert(is_equal_approx(float(before_unload.get("moisture", -1.0)), 30.0))
    assert(chunk_controller.unload_chunk(chunk_id, now + 120))

    var reloaded_root := _new_chunk()
    assert(chunk_controller.load_chunk(chunk_id, reloaded_root, now + 240))
    var after_reload: Dictionary = crop_controller.get_crop(stable_id)
    assert(int(after_reload.get("growth_stage", -1)) == 2, "Offline interval should advance the crop by one additional stage")
    assert(is_equal_approx(float(after_reload.get("moisture", -1.0)), 0.0), "The remaining moisture is consumed during offline growth")
    assert(int(after_reload.get("last_updated_unix", 0)) == now + 240, "Reload records the catch-up target timestamp")
    var reloaded_plot: Node = reloaded_root.get_node_or_null("CropPlot_0")
    assert(reloaded_plot != null and str(reloaded_plot.get("status_text")).contains("2/4"), "Reloaded visual reflects offline growth")

    assert(chunk_controller.unload_chunk(chunk_id, now + 240))

    var failure_chunk_id := "surface/offline-failure-test"
    var failure_crop_id := failure_chunk_id + "/crop/ChunkRoot/CropPlot_0"
    assert(crop_controller.plant_crop(failure_crop_id, "tomato", 60.0, now + 300))
    var failure_before: Dictionary = crop_controller.get_crop(failure_crop_id)
    var conflict_ore: Node3D = MiningNodeScript.new()
    conflict_ore.name = "ConflictOre"
    conflict_ore.mineral_id = "iron_ore"
    conflict_ore.max_units = 5
    conflict_ore.remaining_units = 5
    conflict_ore.regen_interval_seconds = 60
    conflict_ore.last_regen_unix = now + 300
    root.add_child(conflict_ore)
    var conflict_stable_id: String = AdapterScript.make_stable_id(failure_chunk_id, "ChunkRoot/BadOre")
    assert(mineral_registry.register_vein(conflict_stable_id, conflict_ore, now + 300), "Register a conflicting stable vein ID")
    var bad_root := _new_chunk()
    var bad_ore: Node3D = MiningNodeScript.new()
    bad_ore.name = "BadOre"
    bad_ore.mineral_id = "iron_ore"
    bad_ore.max_units = 5
    bad_ore.remaining_units = 5
    bad_ore.regen_interval_seconds = 60
    bad_ore.last_regen_unix = now + 300
    bad_root.add_child(bad_ore)
    assert(not chunk_controller.load_chunk(failure_chunk_id, bad_root, now + 420), "Duplicate stable vein registration rejects the chunk")
    assert(bad_root.get_parent() == null, "Failed chunk registration leaves the scene root with the caller")
    assert(crop_controller.get_crop(failure_crop_id) == failure_before, "Failed mineral registration rolls back offline crop catch-up")
    var failed_plot: Node = bad_root.get_node_or_null("CropPlot_0")
    assert(failed_plot != null, "Rejected chunk keeps the crop visual available to the caller")
    assert(failed_plot.get("controller") == null and str(failed_plot.get("stable_id")).is_empty(), "Preflight rejection happens before crop visual binding")
    assert(mineral_registry.unregister_vein(conflict_stable_id, conflict_ore, now + 420), "Remove the pre-existing conflict after the assertion")
    conflict_ore.queue_free()
    bad_root.free()

    chunk_controller.queue_free()
    crop_controller.queue_free()
    mineral_registry.queue_free()
    registry.queue_free()
    await process_frame
    print("Crop chunk offline growth integration test passed.")
    quit(0)

func _new_chunk() -> Node3D:
    var chunk := Node3D.new()
    chunk.name = "ChunkRoot"
    var plot: Node3D = CropPlotScene.instantiate()
    plot.name = "CropPlot_0"
    plot.crop_id = "wheat"
    plot.plot_index = 1
    chunk.add_child(plot)
    return chunk
