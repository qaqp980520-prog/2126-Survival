extends SceneTree
const WorldScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const SettingsProfile = preload("res://systems/BackroomsSettingsProfile.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var path := "user://run11_settings_integration_test.cfg"
    SettingsProfile.delete_settings(path)
    var world: Node = WorldScene.instantiate()
    world.set("_settings_path", path)
    root.add_child(world)
    await process_frame
    var floor_material := world.call("_make_surface_material", true, Vector2i.ZERO) as ShaderMaterial
    var wall_material := world.call("_make_surface_material", false, Vector2i(2, -3)) as ShaderMaterial
    _expect(floor_material != null and floor_material.shader.code.contains("base_color"), "high-quality floor shader material is constructed")
    _expect(floor_material != null and not floor_material.shader.code.contains("seed_offset"), "floor shader has no wall-only seed parameter")
    _expect(wall_material != null and wall_material.shader.code.contains("seed_offset"), "wall shader declares its per-cell variation parameter")
    var player: Node = world.get_node("Player")
    _expect(not bool(player.call("is_third_person")), "fresh settings start in first-person")
    _expect(is_equal_approx(float(player.call("get_mouse_sensitivity")), 0.0025), "default sensitivity reaches player")
    _expect(world.get_node_or_null("HUD/SettingsButton") is Button, "settings button exists")
    var panel: PanelContainer = world.get("_settings_panel")
    _expect(panel != null and not panel.visible, "settings panel starts hidden")
    world.call("_on_camera_setting_changed", 1)
    world.call("_on_sensitivity_changed", 4.2)
    world.call("_toggle_graphics_quality")
    _expect(bool(player.call("is_third_person")), "camera setting updates live player")
    _expect(is_equal_approx(float(player.call("get_mouse_sensitivity")), 0.0042), "sensitivity setting updates live player")
    var saved: Dictionary = SettingsProfile.load_settings(path)
    _expect(int(saved["camera_mode"]) == 1, "camera setting is persisted")
    _expect(is_equal_approx(float(saved["mouse_sensitivity"]), 4.2), "sensitivity setting is persisted")
    _expect(bool(saved["high_graphics"]), "shadow/quality setting is persisted")
    world.queue_free()
    await process_frame
    var restored_world: Node = WorldScene.instantiate()
    restored_world.set("_settings_path", path)
    root.add_child(restored_world)
    await process_frame
    var restored_player: Node = restored_world.get_node("Player")
    _expect(bool(restored_player.call("is_third_person")), "saved camera mode applies after restart")
    _expect(is_equal_approx(float(restored_player.call("get_mouse_sensitivity")), 0.0042), "saved sensitivity applies after restart")
    _expect(bool(restored_world.get("_high_graphics")), "saved quality applies after restart")
    _expect(bool(restored_world.get("_flicker_enabled")), "fluorescent flicker remains automatic")
    var restored_panel: PanelContainer = restored_world.get("_settings_panel")
    var camera_option := restored_panel.find_child("CameraOption", true, false) as OptionButton
    var slider := restored_panel.find_child("SensitivitySlider", true, false) as HSlider
    var graphics_button := restored_panel.find_child("GraphicsButton", true, false) as Button
    _expect(camera_option != null and camera_option.selected == 1, "camera option reflects saved mode")
    _expect(slider != null and is_equal_approx(slider.value, 4.2), "slider reflects saved sensitivity")
    _expect(graphics_button != null and graphics_button.text.contains("高"), "quality button reflects saved state")
    _expect(restored_panel.find_child("FlickerButton", true, false) == null, "flicker remains automatic rather than a separate toggle")
    _expect(bool(restored_world.call("debug_spawn_portal")), "debug portal can be spawned for graphics regression")
    _expect(bool(restored_world.call("debug_enter_active_portal")), "player enters Backrooms for graphics regression")
    var loaded_cells: Dictionary = restored_world.get("_loaded_cells")
    var room: Node = restored_world.get("backrooms_room")
    _expect(loaded_cells.size() == 25 and room.get_child_count() == 25, "maze starts with 25 unique cells")
    restored_world.call("_toggle_graphics_quality")
    loaded_cells = restored_world.get("_loaded_cells")
    room = restored_world.get("backrooms_room")
    _expect(loaded_cells.size() == 25 and room.get_child_count() == 25, "low-quality refresh does not duplicate cells")
    restored_world.call("_toggle_graphics_quality")
    loaded_cells = restored_world.get("_loaded_cells")
    room = restored_world.get("backrooms_room")
    _expect(loaded_cells.size() == 25 and room.get_child_count() == 25, "high-quality refresh does not duplicate cells")
    restored_world.call("_toggle_settings_panel")
    _expect(restored_panel.visible, "settings panel opens")
    restored_world.call("_toggle_settings_panel")
    _expect(not restored_panel.visible, "settings panel closes")
    restored_world.queue_free()
    await process_frame
    _expect(SettingsProfile.delete_settings(path), "temporary settings file cleanup succeeds")
    var exit_code := 0
    if failures.is_empty():
        print("Backrooms settings integration tests passed.")
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        exit_code = 1
    quit(exit_code)
func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
