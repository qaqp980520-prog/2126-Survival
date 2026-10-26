extends SceneTree
const SettingsProfile = preload("res://systems/BackroomsSettingsProfile.gd")
var failures: Array[String] = []
func _initialize() -> void:
    var path := "user://run11_settings_profile_test.cfg"
    SettingsProfile.delete_settings(path)
    var defaults: Dictionary = SettingsProfile.defaults()
    _expect(int(defaults["camera_mode"]) == 0, "default camera is first-person")
    _expect(is_equal_approx(float(defaults["mouse_sensitivity"]), 2.5), "default sensitivity is 2.5")
    _expect(not bool(defaults["high_graphics"]), "default graphics quality is low")
    _expect(not bool(defaults["flicker_enabled"]), "default flicker is off")
    _expect(SettingsProfile.sanitize({"camera_mode":"third", "mouse_sensitivity":"fast", "high_graphics":"yes", "flicker_enabled":1}) == defaults, "invalid types fall back to safe defaults")
    var clamped := SettingsProfile.sanitize({"camera_mode":8, "mouse_sensitivity":99.0, "high_graphics":true, "flicker_enabled":false})
    _expect(int(clamped["camera_mode"]) == 1, "camera mode clamps to supported range")
    _expect(is_equal_approx(float(clamped["mouse_sensitivity"]), 6.0), "sensitivity clamps to slider maximum")
    _expect(SettingsProfile.save_settings(clamped, path), "valid settings save to ConfigFile")
    _expect(SettingsProfile.load_settings(path) == clamped, "settings survive save/load round-trip")
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
