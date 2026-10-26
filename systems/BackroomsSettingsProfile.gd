extends RefCounted
## Validated persistent settings for the Backrooms 3D playground.
## Fluorescent flicker is always on and intentionally has no user-facing toggle.
const DEFAULT_PATH: String = "user://2126_backrooms_settings.cfg"

static func defaults() -> Dictionary:
    return {"camera_mode": 0, "mouse_sensitivity": 2.5, "high_graphics": true, "shadows_enabled": false, "resolution_index": 0}

static func sanitize(raw: Dictionary) -> Dictionary:
    var result := defaults()
    var camera_value: Variant = raw.get("camera_mode", 0)
    if typeof(camera_value) == TYPE_INT:
        result["camera_mode"] = clampi(int(camera_value), 0, 1)
    var sensitivity_value: Variant = raw.get("mouse_sensitivity", 2.5)
    if typeof(sensitivity_value) == TYPE_INT or typeof(sensitivity_value) == TYPE_FLOAT:
        result["mouse_sensitivity"] = clampf(float(sensitivity_value), 0.5, 6.0)
    var graphics_value: Variant = raw.get("high_graphics", true)
    if typeof(graphics_value) == TYPE_BOOL:
        result["high_graphics"] = graphics_value
    var shadows_value: Variant = raw.get("shadows_enabled", false)
    if typeof(shadows_value) == TYPE_BOOL:
        result["shadows_enabled"] = shadows_value
    var resolution_value: Variant = raw.get("resolution_index", 0)
    if typeof(resolution_value) == TYPE_INT:
        result["resolution_index"] = clampi(int(resolution_value), 0, 2)
    # Legacy flicker_enabled values are intentionally ignored.
    return result

static func load_settings(path: String = DEFAULT_PATH) -> Dictionary:
    var config := ConfigFile.new()
    if config.load(path) != OK:
        return defaults()
    return sanitize({
        "camera_mode": config.get_value("controls", "camera_mode", 0),
        "mouse_sensitivity": config.get_value("controls", "mouse_sensitivity", 2.5),
        "high_graphics": config.get_value("graphics", "high_graphics", true),
        "shadows_enabled": config.get_value("graphics", "shadows_enabled", false),
        "resolution_index": config.get_value("display", "resolution_index", 0),
        "flicker_enabled": config.get_value("graphics", "flicker_enabled", true)
    })

static func save_settings(raw: Dictionary, path: String = DEFAULT_PATH) -> bool:
    var settings := sanitize(raw)
    var config := ConfigFile.new()
    config.set_value("controls", "camera_mode", settings["camera_mode"])
    config.set_value("controls", "mouse_sensitivity", settings["mouse_sensitivity"])
    config.set_value("graphics", "high_graphics", settings["high_graphics"])
    config.set_value("graphics", "shadows_enabled", settings["shadows_enabled"])
    config.set_value("display", "resolution_index", settings["resolution_index"])
    return config.save(path) == OK

static func delete_settings(path: String = DEFAULT_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return true
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
