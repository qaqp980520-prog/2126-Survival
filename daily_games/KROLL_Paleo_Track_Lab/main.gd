extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Paleo_Track_Lab/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"

class TrackwayView extends Control:
    var site: Dictionary = {}

    func set_site(next_site: Dictionary) -> void:
        site = next_site.duplicate(true)
        queue_redraw()

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.065, 0.07), true)
        for x in range(0, int(size.x), 32):
            draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.13, 0.22, 0.21, 0.55), 1.0)
        for y in range(0, int(size.y), 32):
            draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.13, 0.22, 0.21, 0.55), 1.0)
        if site.is_empty():
            return
        var bearing: float = deg_to_rad(float(site.get("bearing_deg", 0.0)))
        var forward := Vector2(sin(bearing), -cos(bearing))
        var lateral := Vector2(-forward.y, forward.x)
        var center := size * 0.5
        var foot_length: float = clampf(float(site.get("foot_length_cm", 24.0)) * 0.48, 22.0, 44.0)
        var foot_width: float = clampf(float(site.get("foot_width_cm", 18.0)) * 0.48, 16.0, 36.0)
        var count: int = int(site.get("print_count", 5))
        draw_line(center - forward * 150.0, center + forward * 150.0, Color(0.45, 0.77, 0.67, 0.5), 2.0)
        for index in range(count):
            var step_offset: float = float(index) - float(count - 1) * 0.5
            var side_offset: float = 11.0 if index % 2 == 0 else -11.0
            var print_center: Vector2 = center + forward * step_offset * 52.0 + lateral * side_offset
            draw_set_transform(print_center, bearing, Vector2.ONE)
            var print_color := Color(0.79, 0.67, 0.43, 0.92) if index % 2 == 0 else Color(0.55, 0.73, 0.62, 0.92)
            draw_rect(Rect2(Vector2(-foot_width * 0.34, -foot_length * 0.04), Vector2(foot_width * 0.68, foot_length * 0.62)), print_color, true)
            draw_circle(Vector2(0.0, -foot_length * 0.22), foot_width * 0.34, print_color)
            draw_circle(Vector2(-foot_width * 0.24, -foot_length * 0.43), foot_width * 0.16, print_color)
            draw_circle(Vector2(0.0, -foot_length * 0.49), foot_width * 0.17, print_color)
            draw_circle(Vector2(foot_width * 0.24, -foot_length * 0.43), foot_width * 0.16, print_color)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        draw_string(ThemeDB.fallback_font, Vector2(14.0, 24.0), "N", HORIZONTAL_ALIGNMENT_LEFT, 24, 14, Color(0.7, 0.9, 0.83))
        draw_line(Vector2(18.0, size.y - 24.0), Vector2(118.0, size.y - 24.0), Color(0.86, 0.79, 0.58), 3.0)
        draw_string(ThemeDB.fallback_font, Vector2(18.0, size.y - 34.0), "100 cm", HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.86, 0.79, 0.58))

var _rules: RefCounted
var _state: Dictionary = {}
var _track_view: TrackwayView
var _title_label: Label
var _site_label: Label
var _metrics_label: Label
var _status_label: Label
var _score_label: Label
var _submit_button: Button
var _reset_button: Button
var _next_button: Button
var _answer_buttons: Array[Button] = []
var _answer_button_specs: Array[Dictionary] = []

func _ready() -> void:
    var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
    var rules_script := load(rules_path) as Script
    if rules_script == null:
        push_error("KROLL Paleo Track Lab could not load its rules module.")
        return
    _rules = rules_script.new() as RefCounted
    _state = _rules.call("create_state", 0, 0)
    _build_ui()
    _refresh()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color(0.025, 0.045, 0.055)
    add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    _title_label = Label.new()
    _title_label.text = "KROLL // PALEO TRACK LAB"
    _title_label.add_theme_font_size_override("font_size", 27)
    _title_label.add_theme_color_override("font_color", Color(0.78, 0.91, 0.79))
    column.add_child(_title_label)

    _site_label = Label.new()
    _site_label.add_theme_font_size_override("font_size", 17)
    _site_label.add_theme_color_override("font_color", Color(0.91, 0.77, 0.48))
    column.add_child(_site_label)

    var work_area := HBoxContainer.new()
    work_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    work_area.add_theme_constant_override("separation", 14)
    column.add_child(work_area)

    var track_panel := PanelContainer.new()
    track_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    track_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    work_area.add_child(track_panel)
    _track_view = TrackwayView.new()
    _track_view.custom_minimum_size = Vector2(560.0, 330.0)
    _track_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _track_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    track_panel.add_child(_track_view)

    var data_panel := PanelContainer.new()
    data_panel.custom_minimum_size = Vector2(360.0, 0.0)
    work_area.add_child(data_panel)
    var data_column := VBoxContainer.new()
    data_column.add_theme_constant_override("separation", 10)
    data_panel.add_child(data_column)

    var metrics_heading := Label.new()
    metrics_heading.text = "FIELD MEASUREMENTS"
    metrics_heading.add_theme_color_override("font_color", Color(0.55, 0.85, 0.78))
    metrics_heading.add_theme_font_size_override("font_size", 17)
    data_column.add_child(metrics_heading)

    _metrics_label = Label.new()
    _metrics_label.custom_minimum_size = Vector2(330.0, 150.0)
    _metrics_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.84))
    _metrics_label.add_theme_font_size_override("font_size", 15)
    data_column.add_child(_metrics_label)

    var note := Label.new()
    note.text = "Compare footprint size, trackway gauge and stride ratio. Toe direction gives the heading."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_color_override("font_color", Color(0.68, 0.76, 0.72))
    data_column.add_child(note)

    var answer_panel := PanelContainer.new()
    column.add_child(answer_panel)
    var answer_column := VBoxContainer.new()
    answer_column.add_theme_constant_override("separation", 7)
    answer_panel.add_child(answer_column)

    var species_label := Label.new()
    species_label.text = "TRACKMAKER"
    species_label.add_theme_color_override("font_color", Color(0.78, 0.91, 0.79))
    answer_column.add_child(species_label)
    var species_row := HBoxContainer.new()
    answer_column.add_child(species_row)
    for option in _rules.call("get_species_options"):
        _add_answer_button(species_row, "species", str(option["id"]), str(option["label"]))

    var gait_label := Label.new()
    gait_label.text = "GAIT"
    gait_label.add_theme_color_override("font_color", Color(0.78, 0.91, 0.79))
    answer_column.add_child(gait_label)
    var gait_row := HBoxContainer.new()
    answer_column.add_child(gait_row)
    for option in _rules.call("get_gait_options"):
        _add_answer_button(gait_row, "gait", str(option["id"]), str(option["label"]))

    var heading_label := Label.new()
    heading_label.text = "HEADING"
    heading_label.add_theme_color_override("font_color", Color(0.78, 0.91, 0.79))
    answer_column.add_child(heading_label)
    var heading_grid := GridContainer.new()
    heading_grid.columns = 4
    heading_grid.add_theme_constant_override("h_separation", 5)
    heading_grid.add_theme_constant_override("v_separation", 5)
    answer_column.add_child(heading_grid)
    for option in _rules.call("get_heading_options"):
        _add_answer_button(heading_grid, "heading", str(option["id"]), str(option["label"]))

    var action_row := HBoxContainer.new()
    column.add_child(action_row)
    _submit_button = _make_action_button(action_row, "SUBMIT FIELD REPORT", submit_survey)
    _reset_button = _make_action_button(action_row, "RESET SITE (R)", reset_survey)
    _next_button = _make_action_button(action_row, "NEXT SITE (N)", advance_survey)

    _status_label = Label.new()
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.62))
    column.add_child(_status_label)

    _score_label = Label.new()
    _score_label.add_theme_color_override("font_color", Color(0.58, 0.85, 0.8))
    column.add_child(_score_label)

func _add_answer_button(parent: Container, field: String, value: String, label_text: String) -> void:
    var button := Button.new()
    button.text = label_text
    button.toggle_mode = true
    button.custom_minimum_size = Vector2(118.0, 38.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(func() -> void:
        select_answer(field, value)
    )
    parent.add_child(button)
    _answer_buttons.append(button)
    _answer_button_specs.append({"button": button, "field": field, "value": value})

func _make_action_button(parent: Container, label_text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(170.0, 42.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func select_answer(field: String, value: String) -> bool:
    var result: Dictionary = _rules.call("set_answer", _state, field, value)
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _refresh()
    return true

func submit_survey() -> bool:
    var result: Dictionary = _rules.call("submit_survey", _state)
    if not bool(result.get("ok", false)):
        _status_label.text = str(result.get("reason", "Unable to submit this survey."))
        return false
    _state = result["state"]
    _refresh()
    return true

func reset_survey() -> bool:
    var result: Dictionary = _rules.call("reset_survey", _state)
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _refresh()
    return true

func advance_survey() -> bool:
    var result: Dictionary = _rules.call("advance_survey", _state)
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _refresh()
    return true

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_title_text() -> String:
    return _title_label.text if _title_label != null else "KROLL // PALEO TRACK LAB"

func get_answer_button_count() -> int:
    return _answer_buttons.size()

func get_metrics_text() -> String:
    return _metrics_label.text if _metrics_label != null else ""

func _refresh() -> void:
    if _rules == null or _state.is_empty():
        return
    var site: Dictionary = _rules.call("get_site_definition", int(_state.get("site_index", -1)))
    _track_view.set_site(site)
    _site_label.text = "SITE %d / %d  //  %s" % [int(_state.get("site_index", 0)) + 1, int(_rules.call("site_count")), str(site.get("title", "UNKNOWN"))]
    _metrics_label.text = "FOOT LENGTH   %4.1f cm\nFOOT WIDTH    %4.1f cm\nSTRIDE        %4.1f cm\nTRACK GAUGE   %4.1f cm\nTOE BEARING   %4.1f deg\nPRINT COUNT   %d" % [
        float(site.get("foot_length_cm", 0.0)), float(site.get("foot_width_cm", 0.0)),
        float(site.get("stride_cm", 0.0)), float(site.get("track_gauge_cm", 0.0)),
        float(site.get("bearing_deg", 0.0)), int(site.get("print_count", 0))
    ]
    _status_label.text = str(_state.get("last_message", ""))
    _score_label.text = "CAMPAIGN SCORE  %d" % int(_state.get("score", 0))
    var answers: Dictionary = _state.get("answers", {})
    var status: String = str(_state.get("status", ""))
    for spec in _answer_button_specs:
        var button: Button = spec["button"]
        button.button_pressed = str(answers.get(str(spec["field"]), "")) == str(spec["value"])
        button.disabled = status != "scanning"
    _submit_button.disabled = status != "scanning"
    _reset_button.disabled = status in ["complete", "campaign_complete"]
    _next_button.disabled = status != "complete"

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_1:
            select_answer("species", "small_ornithopod")
        KEY_2:
            select_answer("species", "large_theropod")
        KEY_3:
            select_answer("species", "sauropod")
        KEY_4:
            select_answer("gait", "walk")
        KEY_5:
            select_answer("gait", "run")
        KEY_UP:
            select_answer("heading", "N")
        KEY_PAGEUP:
            select_answer("heading", "NE")
        KEY_RIGHT:
            select_answer("heading", "E")
        KEY_PAGEDOWN:
            select_answer("heading", "SE")
        KEY_DOWN:
            select_answer("heading", "S")
        KEY_END:
            select_answer("heading", "SW")
        KEY_LEFT:
            select_answer("heading", "W")
        KEY_HOME:
            select_answer("heading", "NW")
        KEY_ENTER, KEY_KP_ENTER:
            submit_survey()
        KEY_R:
            reset_survey()
        KEY_N:
            advance_survey()
        _:
            return
    accept_event()
