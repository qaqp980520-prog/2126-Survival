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

    var floor_material := world.call("_make_surface_material", true, Vector2i.ZERO) as StandardMaterial3D
    var wall_material := world.call("_make_surface_material", false, Vector2i(2, -3)) as StandardMaterial3D
    _expect(floor_material != null and floor_material.albedo_texture != null, "floor material loads the carpet SVG texture")
    _expect(floor_material != null and not floor_material.uv1_triplanar, "floor material uses mesh UVs for the carpet pattern")
    _expect(wall_material != null and wall_material.albedo_texture != null, "wall material loads the wallpaper SVG texture")
    _expect(wall_material != null and not wall_material.uv1_triplanar, "wall material uses mesh UVs for the wallpaper pattern")

    var player: Node = world.get_node("Player")
    _expect(not bool(player.call("is_third_person")), "fresh settings start in first-person")
    _expect(is_equal_approx(float(player.call("get_mouse_sensitivity")), 0.0025), "default sensitivity reaches player controller")
    _expect(bool(world.get("_flicker_enabled")), "fluorescent flicker is automatic by default")
    _expect(world.get_node_or_null("HUD/SettingsButton") is Button, "settings button exists in HUD")
    var panel: PanelContainer = world.get("_settings_panel")
    _expect(panel != null and not panel.visible, "settings panel starts hidden")
    _expect(panel == null or panel.find_child("FlickerButton", true, false) == null, "settings do not expose a flicker toggle")
    _expect(not bool(world.call("_should_enable_light_shadows", Vector2i.ZERO)), "low shadow quality disables dynamic shadows")

    world.call("_on_camera_setting_changed", 1)
    world.call("_on_sensitivity_changed", 4.2)
    world.call("_toggle_graphics_quality")
    _expect(bool(player.call("is_third_person")), "camera setting updates live player")
    _expect(is_equal_approx(float(player.call("get_mouse_sensitivity")), 0.0042), "sensitivity setting updates live player")
    _expect(bool(world.get("_high_graphics")), "geometry quality remains enabled independently of shadows")
    _expect(bool(world.get("_shadows_enabled")), "shadow toggle enables dynamic shadows")
    world.call("_on_resolution_changed", 1)
    _expect(int(world.get("_settings")["resolution_index"]) == 1, "resolution selection updates active settings")

    var saved: Dictionary = SettingsProfile.load_settings(path)
    _expect(int(saved["camera_mode"]) == 1, "camera setting is persisted")
    _expect(is_equal_approx(float(saved["mouse_sensitivity"]), 4.2), "sensitivity setting is persisted")
    _expect(bool(saved["high_graphics"]), "geometry quality is persisted")
    _expect(bool(saved["shadows_enabled"]), "dynamic shadows are persisted")
    _expect(int(saved["resolution_index"]) == 1, "resolution selection is persisted")
    _expect(not saved.has("flicker_enabled"), "flicker is not stored as a setting")

    world.queue_free()
    await process_frame
    var restored_world: Node = WorldScene.instantiate()
    restored_world.set("_settings_path", path)
    root.add_child(restored_world)
    await process_frame
    var restored_player: Node = restored_world.get_node("Player")
    _expect(bool(restored_player.call("is_third_person")), "saved camera mode applies after restart")
    _expect(is_equal_approx(float(restored_player.call("get_mouse_sensitivity")), 0.0042), "saved sensitivity applies after restart")
    _expect(bool(restored_world.get("_high_graphics")), "saved geometry quality applies after restart")
    _expect(bool(restored_world.get("_shadows_enabled")), "saved shadows apply after restart")
    _expect(int(restored_world.get("_settings")["resolution_index"]) == 1, "saved resolution applies after restart")
    _expect(bool(restored_world.get("_flicker_enabled")), "fluorescent flicker remains automatic after restart")
    var restored_panel: PanelContainer = restored_world.get("_settings_panel")
    var slider := restored_panel.find_child("SensitivitySlider", true, false) as HSlider
    var graphics_button := restored_panel.find_child("GraphicsButton", true, false) as Button
    _expect(restored_panel.find_child("FlickerButton", true, false) == null, "no flicker toggle appears after restart")
    _expect(slider != null and is_equal_approx(slider.value, 4.2), "slider reflects saved sensitivity")
    _expect(graphics_button != null and graphics_button.text.contains("光影") and graphics_button.text.contains("開"), "button reflects saved shadow setting")
    var resolution_option := restored_panel.find_child("ResolutionOption", true, false) as OptionButton
    _expect(resolution_option != null and resolution_option.selected == 1, "resolution dropdown reflects saved selection")

    _expect(bool(restored_world.call("debug_spawn_portal")), "debug portal can be spawned for graphics regression")
    _expect(bool(restored_world.call("debug_enter_active_portal")), "player enters Backrooms for graphics regression")
    var loaded_cells: Dictionary = restored_world.get("_loaded_cells")
    var room: Node = restored_world.get("backrooms_room")
    _expect(loaded_cells.size() == 25 and room.get_child_count() == 25, "streamed maze starts with 25 unique cells")
    var has_shadow_cell := false
    for z in range(-10, 11):
        for x in range(-10, 11):
            if bool(restored_world.call("_should_enable_light_shadows", Vector2i(x, z))):
                has_shadow_cell = true
                break
        if has_shadow_cell:
            break
    _expect(has_shadow_cell, "high shadow quality enables a deterministic subset of local shadows")

    restored_world.call("_toggle_graphics_quality")
    loaded_cells = restored_world.get("_loaded_cells")
    room = restored_world.get("backrooms_room")
    _expect(loaded_cells.size() == 25 and room.get_child_count() == 25, "low-quality refresh rebuilds without duplicate stale cells")
    _expect(not bool(restored_world.call("_should_enable_light_shadows", Vector2i(1, 1))), "low shadow quality disables dynamic shadows")
    restored_world.call("_toggle_graphics_quality")
    loaded_cells = restored_world.get("_loaded_cells")
    room = restored_world.get("backrooms_room")
    _expect(loaded_cells.size() == 25 and room.get_child_count() == 25, "high-quality refresh rebuilds without duplicate stale cells")
    var high_after_refresh := false
    for z in range(-10, 11):
        for x in range(-10, 11):
            if bool(restored_world.call("_should_enable_light_shadows", Vector2i(x, z))):
                high_after_refresh = true
                break
        if high_after_refresh:
            break
    _expect(high_after_refresh, "high shadow quality re-enables deterministic shadows after refresh")

    restored_world.call("_toggle_settings_panel")
    _expect(restored_panel.visible, "settings panel opens")
    restored_world.call("_toggle_settings_panel")
    _expect(not restored_panel.visible, "settings panel closes")
    restored_world.queue_free()
    await process_frame
    _expect(SettingsProfile.delete_settings(path), "temporary integration settings file cleanup succeeds")
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
