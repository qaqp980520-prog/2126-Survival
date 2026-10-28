extends SceneTree

const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const SAVE_PATH := "user://backrooms_playground_save.json"
const RELATED_PATHS := [
    "user://backrooms_playground_save.json",
    "user://backrooms_playground_save.json.tmp",
    "user://backrooms_playground_save.json.bak",
    "user://backrooms_playground_save.json.corrupt"
]
const CROP_A := "surface/chunk_2_0/plot_01"
const CROP_B := "surface/chunk_2_0/plot_02"
var failures: Array[String] = []
var world: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    world = WorldScene.instantiate()
    root.add_child(world)
    await process_frame
    await physics_frame
    var controller: Node = world.get("crop_plot_controller")
    var registry: Node = world.get("crop_registry")
    _expect(controller != null and controller.has_method("plant_crop"), "active world exposes the crop plot controller")
    _expect(registry != null, "active world owns the crop registry")
    if controller == null or registry == null:
        await _finish(1)
        return

    var now: int = int(Time.get_unix_time_from_system())
    _expect(bool(controller.call("plant_crop", CROP_A, "tomato", 40.0, now)), "plant a stable-ID tomato through the world controller")
    _expect(bool(controller.call("plant_crop", CROP_B, "wheat", 80.0, now + 5)), "plant a second crop with a later update timestamp")
    var before_a: Dictionary = controller.call("get_crop", CROP_A)
    var failed_batch: Dictionary = controller.call("advance_crops", [CROP_A, CROP_B], 60.0, now + 2)
    _expect(not bool(failed_batch.get("ok", true)), "a later plot timestamp rollback rejects the batch")
    _expect(controller.call("get_crop", CROP_A) == before_a, "failed batch restores the earlier crop without partial growth")

    var batch: Dictionary = controller.call("advance_crops", [CROP_A, CROP_B], 60.0, now + 6)
    _expect(bool(batch.get("ok", false)) and batch.get("advanced_ids", []).size() == 2, "valid batch advances both plots")
    _expect(is_equal_approx(float(controller.call("get_crop", CROP_A)["moisture"]), 25.0), "growth tick consumes moisture through the registry")
    _expect(bool(world.call("save_game")), "active world saves controller-managed crop records")

    _expect(bool(controller.call("water_crop", CROP_A, 50.0, now + 7)), "watering delegates through the world controller")
    _expect(bool(world.call("load_game")), "active world reloads the saved crop snapshot")
    _expect(is_equal_approx(float(controller.call("get_crop", CROP_A)["moisture"]), 25.0), "reload restores the crop moisture from disk")

    _expect(bool(controller.call("water_crop", CROP_A, 100.0, now + 8)), "crop can be re-watered after reload")
    _expect(bool(controller.call("advance_crop", CROP_A, 420.0, now + 428)), "long bounded growth tick advances the crop")
    _expect(int(controller.call("get_crop", CROP_A)["growth_stage"]) == 3, "first long tick reaches stage three")
    _expect(bool(controller.call("water_crop", CROP_A, 100.0, now + 429)), "dry crop can be watered for the final stage")
    _expect(bool(controller.call("advance_crop", CROP_A, 20.0, now + 449)), "final moist tick reaches maturity")
    _expect(int(controller.call("get_crop", CROP_A)["growth_stage"]) == 4, "world controller exposes a mature crop")
    var receipt: Dictionary = controller.call("harvest_crop", CROP_A, now + 450)
    _expect(bool(receipt.get("ok", false)) and int(receipt.get("harvest_count", 0)) == 1, "harvest returns a persisted receipt")

    world.queue_free()
    await process_frame
    _cleanup_save_files()
    if failures.is_empty():
        print("Crop plot controller integration tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _finish(code: int) -> void:
    if world != null and is_instance_valid(world):
        world.queue_free()
    await process_frame
    _cleanup_save_files()
    quit(code)

func _cleanup_save_files() -> void:
    for path in RELATED_PATHS:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
