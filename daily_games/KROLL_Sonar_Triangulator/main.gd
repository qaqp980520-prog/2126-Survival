extends Control

var _rules: Variant
var _state: Dictionary = {}
var _sensor_buttons: Array[Button] = []
var _cell_buttons: Dictionary = {}
var _mission_label: Label
var _briefing_label: Label
var _candidate_label: Label
var _status_label: Label
var _submit_button: Button
var _next_button: Button
var _restart_button: Button
var _last_message: String = ""

func _ready() -> void:
    var attached_script: Script = get_script() as Script
    if attached_script == null:
        push_error("Sonar Triangulator main script is unavailable.")
        set_process(false)
        return
    var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
    var rules_script: Script = load(rules_path) as Script
    if rules_script == null:
        push_error("Sonar Triangulator rules script could not be loaded: " + rules_path)
        set_process(false)
        return
    _rules = rules_script.new()
    _state = _rules.create_state(0)
    _build_ui()
    _refresh_ui()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#061521")
    add_child(background)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)

    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    scroll.add_child(margin)

    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)

    var title := Label.new()
    title.text = "KROLL // SONAR TRIANGULATOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#6bdfff"))
    column.add_child(title)

    _mission_label = Label.new()
    _mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _mission_label.add_theme_font_size_override("font_size", 18)
    _mission_label.add_theme_color_override("font_color", Color("#f0c879"))
    column.add_child(_mission_label)

    _briefing_label = Label.new()
    _briefing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _briefing_label.add_theme_color_override("font_color", Color("#c5d8e5"))
    column.add_child(_briefing_label)

    var sensor_title := Label.new()
    sensor_title.text = "ACOUSTIC BUOYS  ·  SELECT UP TO FOUR PINGS"
    sensor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sensor_title.add_theme_color_override("font_color", Color("#86b9d2"))
    column.add_child(sensor_title)

    var sensor_row := HBoxContainer.new()
    sensor_row.add_theme_constant_override("separation", 8)
    column.add_child(sensor_row)
    for sensor_index in range(_rules.get_sensor_count()):
        var button := Button.new()
        button.name = "Sensor%d" % sensor_index
        button.custom_minimum_size = Vector2(0.0, 62.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 13)
        button.pressed.connect(scan_sensor.bind(sensor_index))
        sensor_row.add_child(button)
        _sensor_buttons.append(button)

    _candidate_label = Label.new()
    _candidate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _candidate_label.add_theme_font_size_override("font_size", 16)
    _candidate_label.add_theme_color_override("font_color", Color("#91e8c2"))
    column.add_child(_candidate_label)

    var board_frame := PanelContainer.new()
    board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    board_frame.add_theme_stylebox_override("panel", _make_panel_style())
    column.add_child(board_frame)

    var board := GridContainer.new()
    board.name = "SonarGrid"
    board.columns = 8
    board.add_theme_constant_override("h_separation", 4)
    board.add_theme_constant_override("v_separation", 4)
    board_frame.add_child(board)
    for y in range(8):
        for x in range(8):
            var cell := Vector2i(x, y)
            var button := Button.new()
            button.name = "Cell_%d_%d" % [x, y]
            button.text = "·"
            button.custom_minimum_size = Vector2(44.0, 42.0)
            button.add_theme_font_size_override("font_size", 18)
            button.pressed.connect(select_cell.bind(x, y))
            board.add_child(button)
            _cell_buttons[cell] = button

    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 10)
    column.add_child(controls)
    _submit_button = Button.new()
    _submit_button.text = "LOCK TARGET  ·  ENTER"
    _submit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _submit_button.custom_minimum_size = Vector2(0.0, 48.0)
    _submit_button.pressed.connect(submit_target)
    controls.add_child(_submit_button)
    _next_button = Button.new()
    _next_button.text = "NEXT  ·  N"
    _next_button.custom_minimum_size = Vector2(110.0, 48.0)
    _next_button.pressed.connect(advance_mission)
    controls.add_child(_next_button)
    _restart_button = Button.new()
    _restart_button.text = "RESTART  ·  R"
    _restart_button.custom_minimum_size = Vector2(120.0, 48.0)
    _restart_button.pressed.connect(restart_campaign)
    controls.add_child(_restart_button)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.custom_minimum_size = Vector2(0.0, 44.0)
    _status_label.add_theme_color_override("font_color", Color("#d4e7ef"))
    column.add_child(_status_label)

    var hint := Label.new()
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.text = "1–4 ping four buoys · three pings unlock guesses · buoy D can break the standard three-corner tie · tap a candidate cell and lock it. R restarts the campaign; N advances."
    hint.add_theme_color_override("font_color", Color("#8ba8bb"))
    column.add_child(hint)

func _make_panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0d2534")
    style.border_color = Color("#2e6074")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(8)
    return style

func _refresh_ui() -> void:
    if _state.is_empty():
        return
    var mission_index: int = int(_state.get("mission_index", 0))
    var mission: Dictionary = _rules.get_mission_definition(mission_index)
    var status: String = _rules.get_status(_state)
    var scans: Dictionary = _state.get("scans", {})
    var candidates: Array[Vector2i] = _rules.get_candidate_positions(_state)
    var excluded: Array[Vector2i] = _rules.get_excluded_cells(_state)
    var selected: Vector2i = _state.get("selected", Vector2i(-1, -1))
    _mission_label.text = "MISSION %02d / %02d  ·  %s" % [mission_index + 1, _rules.get_mission_count(), str(mission.get("title", "UNKNOWN"))]
    _briefing_label.text = str(mission.get("briefing", "No mission briefing available."))
    _candidate_label.text = "PINGS %d / 4  ·  %d POSSIBLE CELLS  ·  3 REQUIRED TO LOCK" % [scans.size(), candidates.size()]

    for sensor_index in range(_sensor_buttons.size()):
        var sensor_name: String = ["A", "B", "C", "D"][sensor_index]
        var button: Button = _sensor_buttons[sensor_index]
        if scans.has(sensor_index):
            button.text = "%s  ·  RANGE %d" % [sensor_name, int(scans[sensor_index])]
        else:
            button.text = "%s  ·  PING %s" % [sensor_name, ["1", "2", "3", "4"][sensor_index]]
        button.disabled = status != "playing" or scans.has(sensor_index)

    for cell_value in _cell_buttons.keys():
        var cell: Vector2i = cell_value
        var button: Button = _cell_buttons[cell] as Button
        var sensor_index: int = _sensor_at(cell)
        if sensor_index >= 0:
            button.text = ["A", "B", "C", "D"][sensor_index]
            button.disabled = true
            button.add_theme_color_override("font_color", Color("#6bdfff"))
        elif selected == cell:
            button.text = "◆"
            button.disabled = status != "playing"
            button.add_theme_color_override("font_color", Color("#ffe18a"))
        elif candidates.has(cell):
            button.text = "◇"
            button.disabled = status != "playing" or scans.size() < _rules.get_minimum_scan_count()
            button.add_theme_color_override("font_color", Color("#91e8c2"))
        elif excluded.has(cell):
            button.text = "×"
            button.disabled = true
            button.add_theme_color_override("font_color", Color("#ef7f78"))
        else:
            button.text = "·"
            button.disabled = true
            button.add_theme_color_override("font_color", Color("#496272"))

    _submit_button.disabled = status != "playing" or scans.size() < _rules.get_minimum_scan_count() or selected == Vector2i(-1, -1)
    _next_button.disabled = status != "passed"
    _restart_button.disabled = false
    if status == "passed":
        _status_label.text = "TARGET LOCKED  ·  SCORE %d  ·  PRESS N FOR NEXT SURVEY" % _rules.get_mission_score(_state)
    elif status == "campaign_complete":
        _status_label.text = "ALL THREE BEACONS RECOVERED  ·  TOTAL SCORE %d  ·  PRESS R TO RESTART" % _rules.get_campaign_score(_state)
    elif status == "failed":
        _status_label.text = "SURVEY LOST  ·  PRESS R TO RESTART THE CAMPAIGN"
    elif not _last_message.is_empty():
        _status_label.text = _last_message
    elif scans.size() < _rules.get_minimum_scan_count():
        _status_label.text = "PING AT LEAST THREE BUOYS TO BEGIN TRIANGULATION."
    elif candidates.size() > 1:
        var unused_buoys: String = ""
        for sensor_index in range(_rules.get_sensor_count()):
            if not scans.has(sensor_index):
                if not unused_buoys.is_empty():
                    unused_buoys += ", "
                unused_buoys += ["A", "B", "C", "D"][sensor_index]
        if unused_buoys.is_empty():
            _status_label.text = "AMBIGUOUS RETURN  ·  ELIMINATE A FALSE CELL."
        else:
            _status_label.text = "AMBIGUOUS RETURN  ·  USE UNUSED BUOY %s OR ELIMINATE A FALSE CELL." % unused_buoys
    else:
        _status_label.text = "SINGLE RETURN LOCK  ·  SELECT THE REMAINING CELL."

func scan_sensor(sensor_index: int) -> bool:
    var result: Dictionary = _rules.scan_sensor(_state, sensor_index)
    if not bool(result.get("ok", false)):
        _last_message = "PING REJECTED  ·  " + str(result.get("reason", "unknown"))
        _refresh_ui()
        return false
    _state = result["state"]
    _last_message = "BUOY %s RETURNED RANGE %d  ·  %d CANDIDATES REMAIN." % [
        ["A", "B", "C", "D"][sensor_index],
        int(result.get("reading", -1)),
        int(result.get("candidate_count", 0))
    ]
    _refresh_ui()
    return true

func select_cell(x: int, y: int) -> bool:
    var result: Dictionary = _rules.select_cell(_state, Vector2i(x, y))
    if not bool(result.get("ok", false)):
        _last_message = "CELL SELECTION REJECTED  ·  " + str(result.get("reason", "unknown"))
        _refresh_ui()
        return false
    _state = result["state"]
    _last_message = "SELECTED GRID COORDINATE  ·  (%d, %d)" % [x, y]
    _refresh_ui()
    return true

func submit_target() -> bool:
    var result: Dictionary = _rules.submit_target(_state)
    if not bool(result.get("ok", false)):
        _last_message = "TARGET LOCK REJECTED  ·  " + str(result.get("reason", "unknown"))
        _refresh_ui()
        return false
    _state = result["state"]
    if bool(result.get("hit", false)):
        _last_message = "BEACON CONFIRMED  ·  %d POINTS" % int(result.get("score", 0))
    else:
        _last_message = "FALSE RETURN EXCLUDED  ·  %d CANDIDATES REMAIN." % int(result.get("candidate_count", 0))
    _refresh_ui()
    return true

func advance_mission() -> bool:
    var result: Dictionary = _rules.advance_mission(_state)
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _last_message = ""
    _refresh_ui()
    return true

func restart_campaign() -> bool:
    var result: Dictionary = _rules.restart_campaign()
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _last_message = "NEW SURVEY CAMPAIGN INITIALIZED."
    _refresh_ui()
    return true

func get_title_text() -> String:
    return "KROLL // SONAR TRIANGULATOR"

func get_mission_count() -> int:
    return _rules.get_mission_count()

func get_sensor_button_count() -> int:
    return _sensor_buttons.size()

func get_cell_button_count() -> int:
    return _cell_buttons.size()

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_status_text() -> String:
    return _status_label.text if is_instance_valid(_status_label) else ""

func _sensor_at(cell: Vector2i) -> int:
    for sensor_index in range(_rules.get_sensor_count()):
        if _rules.get_sensor_position(sensor_index) == cell:
            return sensor_index
    return -1

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1:
            scan_sensor(0)
        KEY_2:
            scan_sensor(1)
        KEY_3:
            scan_sensor(2)
        KEY_4:
            scan_sensor(3)
        KEY_ENTER:
            submit_target()
        KEY_N:
            advance_mission()
        KEY_R:
            restart_campaign()
