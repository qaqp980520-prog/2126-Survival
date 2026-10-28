extends SceneTree

const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const SAVE_PATHS := [
    "user://backrooms_playground_save.json",
    "user://backrooms_playground_save.json.tmp",
    "user://backrooms_playground_save.json.bak",
    "user://backrooms_playground_save.json.corrupt"
]
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_saves()
    var world := WorldScene.instantiate()
    root.add_child(world)
    await process_frame
    await physics_frame

    var plots: Array = world.get("crop_plot_views")
    var registry: Node = world.get("crop_registry")
    _expect(plots.size() == 4, "active surface builds four visible stable-ID crop plots")
    _expect(registry != null, "world still owns the authoritative CropRegistry")
    if plots.is_empty() or registry == null:
        world.queue_free()
        await process_frame
        _cleanup_saves()
        quit(1)
        return

    var plot: Node = plots[0]
    var stable_id := str(plot.get("stable_id"))
    var now := int(Time.get_unix_time_from_system())
    var player: Node3D = world.get_node("Player")
    player.global_position = plots[1].global_position
    world.call("_interact_nearest_crop_plot")
    var nearby_id := str(plots[1].get("stable_id"))
    _expect(not registry.call("get_crop", nearby_id).is_empty(), "active-world E interaction plants the nearest plot")
    world.set("in_backrooms", true)
    player.global_position = plots[2].global_position
    world.call("_interact_nearest_crop_plot")
    _expect(registry.call("get_crop", str(plots[2].get("stable_id"))).is_empty(), "Backrooms interaction cannot mutate surface crop plots")
    world.set("in_backrooms", false)
    player.global_position = Vector3.ZERO
    var result: Dictionary = plot.call("interact", now)
    _expect(bool(result.get("ok", false)) and result.get("action") == "planted", "interacting with an empty plot plants its configured crop")
    _expect(int(registry.call("get_crop", stable_id).get("growth_stage", -1)) == 0, "planted crop begins at stage zero")

    result = plot.call("interact", now + 1)
    _expect(bool(result.get("ok", false)) and result.get("action") == "advanced", "moist plot advances its growth interval")
    _expect(int(registry.call("get_crop", stable_id).get("growth_stage", -1)) == 1, "first interaction advances one stage")

    result = plot.call("interact", now + 2)
    _expect(bool(result.get("ok", false)) and result.get("action") == "advanced", "second moist interaction advances another stage")
    _expect(float(registry.call("get_crop", stable_id).get("moisture", -1.0)) == 0.0, "growth consumes moisture deterministically")

    result = plot.call("interact", now + 3)
    _expect(bool(result.get("ok", false)) and result.get("action") == "watered", "dry plot interaction waters instead of forcing growth")
    result = plot.call("interact", now + 4)
    _expect(bool(result.get("ok", false)) and result.get("action") == "advanced", "watered plot resumes growth")
    result = plot.call("interact", now + 5)
    _expect(bool(result.get("ok", false)) and result.get("action") == "watered", "low-moisture plot can be watered again")
    result = plot.call("interact", now + 6)
    _expect(bool(result.get("ok", false)) and result.get("action") == "advanced", "final growth tick reaches maturity")
    var mature: Dictionary = registry.call("get_crop", stable_id)
    _expect(int(mature.get("growth_stage", 0)) == 4 and float(mature.get("growth_progress", 0.0)) == 1.0, "plot exposes mature stage before harvest")
    _expect(bool(plot.get_node("CropFruit").visible), "mature plot displays a harvestable fruit visual")

    result = plot.call("interact", now + 7)
    _expect(bool(result.get("ok", false)) and result.get("action") == "harvested", "mature plot interaction harvests and resets the cycle")
    _expect(int(registry.call("get_crop", stable_id).get("harvest_count", 0)) == 1, "harvest count is stored in the registry")
    _expect(not bool(plot.get_node("CropFruit").visible), "harvest refresh hides the mature fruit visual")
    _expect(bool(world.call("save_game")), "visible crop interaction state can be saved by the active world")
    _expect(bool(world.call("load_game")), "active world reloads the crop registry")
    _expect(int(registry.call("get_crop", stable_id).get("harvest_count", 0)) == 1, "harvest state survives world save/load")

    world.queue_free()
    await process_frame
    _cleanup_saves()
    if failures.is_empty():
        print("Crop plot visual interaction integration tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _cleanup_saves() -> void:
    for path in SAVE_PATHS:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
