extends SceneTree

const SettingsProfile = preload("res://systems/BackroomsSettingsProfile.gd")
var failures: Array[String] = []

func _initialize() -> void:
    var path := "user://run11_settings_profile_test.cfg"
    SettingsProfile.delete_settings(path)
    var defaults: Dictionary = SettingsProfile.defaults()
    _expect(int(defaults["camera_mode"]) == 0, "default camera is first-person")
    _expect(is_equal_approx(float(defaults["mouse_sensitivity"]), 2.5), "default sensitivity is 2.5")
    _expect(not bool(defaults["high_graphics"]), "default shadow quality is low")
    _expect(not defaults.has("flicker_enabled"), "flicker is not user-configurable")
    var invalid := SettingsProfile.sanitize({"camera_mode":"third", "mouse_sensitivity":"fast", "high_graphics":"yes", "flicker_enabled":false})
    _expect(invalid == defaults, "invalid types fall back to safe defaults and legacy flicker option is ignored")
    var clamped := SettingsProfile.sanitize({"camera_mode":8, "mouse_sensitivity":99.0, "high_graphics":true})
    _expect(int(clamped["camera_mode"]) == 1, "camera mode clamps to supported range")
    _expect(is_equal_approx(float(clamped["mouse_sensitivity"]), 6.0), "sensitivity clamps to slider maximum")
    _expect(SettingsProfile.save_settings(clamped, path), "valid settings save to ConfigFile")
    _expect(SettingsProfile.load_settings(path) == clamped, "settings survive save/load round-trip")
    var config := ConfigFile.new()
    config.set_value("graphics", "high_graphics", true)
    config.set_value("graphics", "flicker_enabled", false)
    _expect(config.save(path) == OK, "legacy settings fixture saves")
    var loaded_legacy: Dictionary = SettingsProfile.load_settings(path)
    _expect(not loaded_legacy.has("flicker_enabled"), "legacy flicker key is not exposed to settings")
    _expect(bool(loaded_legacy["high_graphics"]), "legacy load preserves shadow quality")
    _expect(SettingsProfile.delete_settings(path), "temporary settings cleanup succeeds")
    var exit_code := 0
    if failures.is_empty():
        print("Backrooms settings profile tests passed.")
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
