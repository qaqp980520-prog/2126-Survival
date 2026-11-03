extends Control

var _rules: Variant
var _state: Dictionary = {}
var _mission_label: Label
var _briefing_label: Label
var _altitude_label: Label
var _wind_label: Label
var _resource_label: Label
var _progress_label: Label
var _status_label: Label
var _altitude_bar: ProgressBar
var _action_buttons: Dictionary = {}
var _next_button: Button
var _restart_button: Button

func _ready() -> void:
    var attached_script: Script = get_script() as Script
    var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
    var rules_script: Script = load(rules_path) as Script
    if rules_script == null:
        push_error("Stratosphere Balloonist rules script could not be loaded: " + rules_path)
        return
    _rules = rules_script.new()
    _state = _rules.create_state(0)
    _build_ui()
    _refresh_ui()

func _build_ui() -> void:
    var compact: bool = float(DisplayServer.window_get_size().x) <= 520.0
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#071622")
    add_child(background)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 16 if compact else 28)
    margin.add_theme_constant_override("margin_right", 16 if compact else 28)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    scroll.add_child(margin)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)
    var title := Label.new()
    title.text = "KROLL // STRATOSPHERE BALLOONIST"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20 if compact else 30)
    title.add_theme_color_override("font_color", Color("#72dcff"))
    column.add_child(title)
    _mission_label = Label.new()
    _mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _mission_label.add_theme_font_size_override("font_size", 16 if compact else 21)
    _mission_label.add_theme_color_override("font_color", Color("#f0c879"))
    column.add_child(_mission_label)
    _briefing_label = Label.new()
    _briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _briefing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _briefing_label.add_theme_color_override("font_color", Color("#c4d8e6"))
    column.add_child(_briefing_label)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _make_panel_style())
    column.add_child(panel)
    var gauge := VBoxContainer.new()
    gauge.add_theme_constant_override("separation", 7)
    panel.add_child(gauge)
    _altitude_label = Label.new()
    _altitude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _altitude_label.add_theme_font_size_override("font_size", 18 if compact else 24)
    _altitude_label.add_theme_color_override("font_color", Color("#9be5c6"))
    gauge.add_child(_altitude_label)
    _altitude_bar = ProgressBar.new()
    _altitude_bar.min_value = 0.0
    _altitude_bar.max_value = 15.0
    _altitude_bar.custom_minimum_size = Vector2(0.0, 26.0)
    _altitude_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gauge.add_child(_altitude_bar)
    _wind_label = Label.new()
    _wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _wind_label.add_theme_color_override("font_color", Color("#8ebbd2"))
    gauge.add_child(_wind_label)
    _resource_label = Label.new()
    _resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _resource_label.add_theme_color_override("font_color", Color("#e5d5ad"))
    column.add_child(_resource_label)
    _progress_label = Label.new()
    _progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _progress_label.add_theme_color_override("font_color", Color("#91e8c2"))
    column.add_child(_progress_label)
    var actions: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    column.add_child(actions)
    var action_specs: Array[Dictionary] = [{"id":"ascend","text":"ASCEND  ↑"},{"id":"hold","text":"HOLD  ·  SPACE"},{"id":"descend","text":"DESCEND  ↓"}]
    for spec in action_specs:
        var button := Button.new()
        button.text = str(spec["text"])
        button.custom_minimum_size = Vector2(0.0, 48.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(perform_action.bind(str(spec["id"])))
        actions.add_child(button)
        _action_buttons[str(spec["id"])] = button
    var navigation := HBoxContainer.new()
    navigation.add_theme_constant_override("separation", 8)
    column.add_child(navigation)
    _next_button = Button.new()
    _next_button.text = "NEXT MISSION  ·  N"
    _next_button.custom_minimum_size = Vector2(0.0, 44.0)
    _next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _next_button.pressed.connect(advance_mission)
    navigation.add_child(_next_button)
    _restart_button = Button.new()
    _restart_button.text = "RESTART  ·  R"
    _restart_button.custom_minimum_size = Vector2(0.0, 44.0)
    _restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _restart_button.pressed.connect(restart_campaign)
    navigation.add_child(_restart_button)
    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color", Color("#f0c879"))
    column.add_child(_status_label)
    var hint := Label.new()
    hint.text = "UP: ascend   SPACE: hold   DOWN: descend   N: next   R: restart"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color("#7893a7"))
    column.add_child(hint)

func perform_action(action: String) -> Dictionary:
    if _rules == null:
        return {"ok":false,"reason":"rules_unavailable"}
    var result: Dictionary = _rules.apply_action(_state, action)
    if bool(result.get("ok", false)):
        _state = result["state"]
    else:
        _status_label.text = "COMMAND REJECTED: " + str(result.get("reason", "unknown"))
    _refresh_ui()
    return result

func advance_mission() -> Dictionary:
    var result: Dictionary = _rules.advance_mission(_state)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh_ui()
    return result

func restart_campaign() -> void:
    var result: Dictionary = _rules.restart_campaign()
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh_ui()

func get_title_text() -> String:
    return "KROLL // STRATOSPHERE BALLOONIST"

func get_mission_count() -> int:
    return int(_rules.get_mission_count()) if _rules != null else 0

func get_action_button_count() -> int:
    return _action_buttons.size()

func get_control_button_count() -> int:
    return _action_buttons.size() + 2

func get_state_snapshot() -> Dictionary:
    return _state.duplicate(true)

func _refresh_ui() -> void:
    if _rules == null or _state.is_empty():
        return
    var mission_index: int = int(_state.get("mission_index", 0))
    var mission: Dictionary = _rules.get_mission_definition(mission_index)
    var target: float = float(mission["target_altitude"])
    var altitude: float = float(_state.get("altitude", 0.0))
    var status: String = str(_state.get("status", "playing"))
    _mission_label.text = "MISSION %d / %d  ·  %s" % [mission_index + 1, _rules.get_mission_count(), str(mission["title"])]
    _briefing_label.text = str(mission["briefing"])
    _altitude_label.text = "ALTITUDE  %.2f km   /   TARGET  %.2f km" % [altitude, target]
    _altitude_bar.max_value = target + 2.0
    _altitude_bar.value = clampf(altitude, 0.0, _altitude_bar.max_value)
    _wind_label.text = "WIND DRIFT  %+0.2f km / tick" % float(_rules.get_current_wind_bias(_state))
    _resource_label.text = "BALLAST  %d     ENVELOPE  %d%%     TICK  %d / %d" % [int(_state.get("ballast", 0)), int(_state.get("gas_integrity", 0)), int(_state.get("ticks", 0)), int(mission["max_ticks"])]
    _progress_label.text = "STABLE SAMPLE  %d / %d" % [int(_state.get("sample_progress", 0)), _rules.get_sample_requirement()]
    match status:
        "playing":
            _status_label.text = "Maintain altitude inside the target band for three calm ticks."
        "passed":
            _status_label.text = "SAMPLE CAPTURED  ·  +%d POINTS" % int(_state.get("mission_score", 0))
        "failed":
            _status_label.text = "FLIGHT ABORTED  ·  RESTART THE CAMPAIGN"
        "campaign_complete":
            _status_label.text = "CAMPAIGN COMPLETE  ·  TOTAL SCORE %d" % int(_state.get("campaign_score", 0))
        _:
            _status_label.text = "FLIGHT STATUS: " + status
    for button in _action_buttons.values():
        (button as Button).disabled = status != "playing"
    _next_button.disabled = status != "passed"
    _restart_button.disabled = false

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_UP:
            perform_action("ascend")
            get_viewport().set_input_as_handled()
        KEY_SPACE:
            perform_action("hold")
            get_viewport().set_input_as_handled()
        KEY_DOWN:
            perform_action("descend")
            get_viewport().set_input_as_handled()
        KEY_N:
            advance_mission()
            get_viewport().set_input_as_handled()
        KEY_R:
            restart_campaign()
            get_viewport().set_input_as_handled()

func _make_panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#102838")
    style.border_color = Color("#2c5d70")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    return style
