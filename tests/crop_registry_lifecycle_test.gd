extends SceneTree

const CropRegistryScript = preload("res://systems/CropRegistry.gd")
const TOMATO_ID := "surface/chunk_0_0/tomato-01"
const WHEAT_ID := "surface/chunk_1_0/wheat-01"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var registry := CropRegistryScript.new()
    root.add_child(registry)
    var now: int = int(Time.get_unix_time_from_system())
    _expect(registry.register_crop(TOMATO_ID, "tomato", 0, 0.5, 65.0, now, 0), "register a crop for lifecycle testing")
    _expect(not registry.water_crop("missing/chunk/crop", 10.0, now + 1), "watering an unknown crop is rejected")
    _expect(not registry.water_crop(TOMATO_ID, 0.0, now + 1), "zero watering is rejected")
    _expect(registry.water_crop(TOMATO_ID, 100.0, now + 1), "valid watering succeeds")
    _expect(is_equal_approx(float(registry.get_crop(TOMATO_ID)["moisture"]), 100.0), "watering clamps moisture to 100")
    _expect(not registry.water_crop(TOMATO_ID, 10.0, now + 2), "saturated crop watering is a no-op")

    _expect(not registry.advance_growth(TOMATO_ID, 0.0, now + 2), "zero elapsed time is rejected")
    _expect(not registry.advance_growth(TOMATO_ID, -1.0, now + 2), "negative elapsed time is rejected")
    _expect(not registry.advance_growth(TOMATO_ID, 86401.0, now + 2), "unbounded elapsed time is rejected")
    _expect(registry.advance_growth(TOMATO_ID, 300.0, now + 3), "bounded elapsed time advances growth")
    var record: Dictionary = registry.get_crop(TOMATO_ID)
    _expect(record["growth_stage"] == 3, "one growth call can cross multiple stages deterministically")
    _expect(is_equal_approx(float(record["growth_progress"]), 0.0), "whole-stage growth leaves zero fractional progress")
    _expect(is_equal_approx(float(record["moisture"]), 25.0), "moisture drain is applied over elapsed time")
    var before_clock_rollback: Dictionary = registry.get_crop(TOMATO_ID)
    _expect(not registry.water_crop(TOMATO_ID, 5.0, now + 2), "watering cannot move the crop timestamp backwards")
    _expect(not registry.advance_growth(TOMATO_ID, 30.0, now + 2), "growth cannot move the crop timestamp backwards")
    _expect(registry.get_crop(TOMATO_ID) == before_clock_rollback, "clock rollback leaves the crop record unchanged")

    var immature_before: Dictionary = registry.get_crop(TOMATO_ID)
    _expect(registry.harvest_crop(TOMATO_ID, now + 4).is_empty(), "immature crop cannot be harvested")
    _expect(registry.get_crop(TOMATO_ID) == immature_before, "failed harvest leaves the crop unchanged")
    _expect(registry.advance_growth(TOMATO_ID, 120.0, now + 5), "growth advances until soil dries")
    record = registry.get_crop(TOMATO_ID)
    _expect(record["growth_stage"] == 3 and float(record["moisture"]) == 0.0, "dry soil pauses growth at its current stage")
    _expect(is_equal_approx(float(record["growth_progress"]), 0.8333333), "only the moist portion of elapsed time contributes growth")

    _expect(registry.water_crop(TOMATO_ID, 20.0, now + 6), "dry crop can be watered again")
    _expect(registry.advance_growth(TOMATO_ID, 20.0, now + 7), "watered crop resumes growth")
    record = registry.get_crop(TOMATO_ID)
    _expect(record["growth_stage"] == CropRegistryScript.MAX_STAGE, "crop reaches the mature stage")
    _expect(is_equal_approx(float(record["growth_progress"]), 1.0), "mature progress is clamped to one")
    var mature_before_harvest: Dictionary = registry.get_crop(TOMATO_ID)
    _expect(registry.harvest_crop(TOMATO_ID, now + 6).is_empty(), "harvest rejects timestamp rollback")
    _expect(registry.get_crop(TOMATO_ID) == mature_before_harvest, "rejected rollback harvest leaves mature crop unchanged")
    var receipt: Dictionary = registry.harvest_crop(TOMATO_ID, now + 8)
    _expect(bool(receipt.get("ok", false)), "mature crop harvest returns a receipt")
    _expect(receipt.get("crop_id") == "tomato" and receipt.get("harvest_count") == 1, "harvest receipt reports crop and count")
    record = registry.get_crop(TOMATO_ID)
    _expect(record["growth_stage"] == 0 and float(record["growth_progress"]) == 0.0, "harvest resets growth for the next cycle")
    _expect(record["harvest_count"] == 1, "harvest count persists in the crop record")
    _expect(float(record["moisture"]) == 0.0, "harvest consumes soil moisture")
    var saved_payload: Dictionary = registry.to_save_dict()
    var restored_registry := CropRegistryScript.new()
    root.add_child(restored_registry)
    _expect(restored_registry.restore_save_dict(saved_payload), "lifecycle state remains compatible with registry schema 1")
    _expect(restored_registry.get_crop(TOMATO_ID) == record, "harvested state round-trips without schema changes")
    restored_registry.queue_free()

    _expect(registry.register_crop(WHEAT_ID, "wheat", 1, 0.25, 0.0, now, 0), "register a dry crop")
    _expect(registry.advance_growth(WHEAT_ID, 60.0, now + 9), "dry crop time can advance without growth")
    var dry: Dictionary = registry.get_crop(WHEAT_ID)
    _expect(dry["growth_stage"] == 1 and is_equal_approx(float(dry["growth_progress"]), 0.25), "dry crop growth is paused")
    _expect(dry["last_updated_unix"] == now + 9, "injected timestamps are stored deterministically")

    var offline_id := "surface/chunk_3_0/offline-wheat"
    _expect(registry.register_crop(offline_id, "wheat", 0, 0.0, 60.0, now + 1000, 0), "register an offline-growth crop")
    var offline_target: int = now + 1000 + 86400 * 3
    _expect(registry.advance_to_time(offline_id, offline_target), "offline crop catches up after a multi-day absence")
    var offline: Dictionary = registry.get_crop(offline_id)
    _expect(offline["last_updated_unix"] == offline_target, "offline catch-up advances the persisted timestamp to the target")
    _expect(offline["growth_stage"] == 2 and is_equal_approx(float(offline["moisture"]), 0.0), "bounded catch-up reaches the dry steady state without inventing growth after water runs out")
    var offline_snapshot: Dictionary = offline.duplicate(true)
    _expect(registry.advance_to_time(offline_id, offline_target), "repeating the same catch-up timestamp is idempotent")
    _expect(not registry.advance_to_time(offline_id, offline_target - 1), "offline catch-up rejects clock rollback")
    _expect(registry.get_crop(offline_id) == offline_snapshot, "clock rollback leaves offline crop data unchanged")

    registry.queue_free()
    await process_frame
    if failures.is_empty():
        print("Crop registry lifecycle tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
