extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Faultline_Cartographer/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"
const PROBE_KEYS: Dictionary = {"NW": "1", "NE": "2", "SW": "3"}

var _rules: RefCounted
var _state: Dictionary = {}
var _cell_buttons: Array[Button] = []
var _probe_buttons: Dictionary = {}
var _reading_labels: Dictionary = {}
var _scenario_label: Label
var _candidate_label: Label
var _selected_label: Label
var _score_label: Label
var _status_label: Label
var _submit_button: Button
var _reset_button: Button
var _next_button: Button

func _ready() -> void:
    var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
    var rules_script: Script = load(rules_path) as Script
    if rules_script == null:
        push_error("KROLL Faultline Cartographer could not load its rules.")
        return
    _rules = rules_script.new() as RefCounted
    if _rules == null:
        push_error("KROLL Faultline Cartographer could not instantiate its survey model.")
        return
    _state = _rules.call("create_state", 0)
    _build_ui()
    _refresh_ui()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#101a24")
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(1080, 700)
    center.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    panel.add_child(column)

    var title := Label.new()
    title.text = "KROLL // FAULTLINE CARTOGRAPHER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color("#e8bd72"))
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "SUBSURFACE SURVEY // THREE PULSES // TRIANGULATE THE DEPOSIT"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#9eb2c2"))
    column.add_child(subtitle)

    var content := HBoxContainer.new()
    content.add_theme_constant_override("separation", 16)
    column.add_child(content)

    var map_panel := PanelContainer.new()
    map_panel.custom_minimum_size = Vector2(540, 500)
    map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(map_panel)

    var map_column := VBoxContainer.new()
    map_column.add_theme_constant_override("separation", 6)
    map_panel.add_child(map_column)
    var map_hint := Label.new()
    map_hint.text = "GRID COORDINATES // X → EAST // Y → SOUTH"
    map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_hint.add_theme_color_override("font_color", Color("#9eb2c2"))
    map_column.add_child(map_hint)

    var grid := GridContainer.new()
    grid.columns = 7
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    map_column.add_child(grid)
    for y in range(7):
        for x in range(7):
            var cell := Button.new()
            cell.text = "?"
            cell.custom_minimum_size = Vector2(68, 58)
            cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            cell.pressed.connect(_select_cell.bind(Vector2i(x, y)))
            grid.add_child(cell)
            _cell_buttons.append(cell)

    var controls_panel := PanelContainer.new()
    controls_panel.custom_minimum_size = Vector2(450, 500)
    content.add_child(controls_panel)
    var controls := VBoxContainer.new()
    controls.add_theme_constant_override("separation", 10)
    controls_panel.add_child(controls)

    _scenario_label = Label.new()
    _scenario_label.add_theme_font_size_override("font_size", 20)
    _scenario_label.add_theme_color_override("font_color", Color("#f0c77c"))
    controls.add_child(_scenario_label)

    var score_row := HBoxContainer.new()
    controls.add_child(score_row)
    var score_caption := Label.new()
    score_caption.text = "CAMPAIGN SCORE"
    score_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    score_row.add_child(score_caption)
    _score_label = Label.new()
    score_row.add_child(_score_label)

    var probe_title := Label.new()
    probe_title.text = "SEISMIC PROBES"
    probe_title.add_theme_color_override("font_color", Color("#a8bac9"))
    controls.add_child(probe_title)

    for probe in _rules.call("get_probe_definitions"):
        var probe_id: String = str(probe["id"])
        var probe_button := Button.new()
        probe_button.text = "%s // PULSE %s" % [str(probe["label"]), PROBE_KEYS[probe_id]]
        probe_button.custom_minimum_size = Vector2(0, 52)
        probe_button.pressed.connect(_activate_probe.bind(probe_id))
        controls.add_child(probe_button)
        _probe_buttons[probe_id] = probe_button
        var reading := Label.new()
        reading.text = "%s: --" % probe_id
        reading.add_theme_color_override("font_color", Color("#91c6d5"))
        controls.add_child(reading)
        _reading_labels[probe_id] = reading

    _candidate_label = Label.new()
    _candidate_label.add_theme_color_override("font_color", Color("#9ed9bd"))
    controls.add_child(_candidate_label)
    _selected_label = Label.new()
    _selected_label.add_theme_color_override("font_color", Color("#e8bd72"))
    controls.add_child(_selected_label)

    _submit_button = Button.new()
    _submit_button.text = "CONFIRM LOCATION  (SPACE)"
    _submit_button.custom_minimum_size = Vector2(0, 50)
    _submit_button.pressed.connect(_submit_guess)
    controls.add_child(_submit_button)

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 8)
    controls.add_child(footer)
    _reset_button = Button.new()
    _reset_button.text = "RESET / R"
    _reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _reset_button.pressed.connect(_reset_survey)
    footer.add_child(_reset_button)
    _next_button = Button.new()
    _next_button.text = "NEXT / N"
    _next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _next_button.pressed.connect(_advance_survey)
    footer.add_child(_next_button)

    _status_label = Label.new()
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color", Color("#e4c07a"))
    controls.add_child(_status_label)

    var hint := Label.new()
    hint.text = "1 / 2 / 3: pulse probes  |  click a remaining cell  |  SPACE: confirm  |  R: reset  |  N: next survey"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_color_override("font_color", Color("#8298aa"))
    controls.add_child(hint)

func perform_probe(probe_id: String) -> bool:
    if _rules == null:
        return false
    var result: Dictionary = _rules.call("activate_probe", _state, probe_id)
    if not bool(result.get("ok", false)):
        _status_label.text = "PROBE REJECTED: %s" % str(result.get("reason", "unknown"))
        return false
    _state = result["state"]
    _refresh_ui()
    return true

func select_cell(cell: Vector2i) -> bool:
    if _rules == null:
        return false
    var result: Dictionary = _rules.call("select_cell", _state, cell)
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _refresh_ui()
    return true

func submit_guess() -> bool:
    if _rules == null:
        return false
    var result: Dictionary = _rules.call("submit_guess", _state)
    if not bool(result.get("ok", false)):
        _status_label.text = "CONFIRM REJECTED: %s" % str(result.get("reason", "unknown"))
        return false
    _state = result["state"]
    _refresh_ui()
    return true

func _activate_probe(probe_id: String) -> void:
    perform_probe(probe_id)

func _select_cell(cell: Vector2i) -> void:
    select_cell(cell)

func _submit_guess() -> void:
    submit_guess()

func _reset_survey() -> void:
    var result: Dictionary = _rules.call("reset_survey", _state)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh_ui()

func _advance_survey() -> void:
    var result: Dictionary = _rules.call("advance_survey", _state)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh_ui()

func _refresh_ui() -> void:
    if _state.is_empty():
        return
    var index: int = int(_state.get("survey_index", 0))
    var definition: Dictionary = _rules.call("get_survey_definition", index)
    _scenario_label.text = "%s  (%d/3)" % [str(_state.get("title", "")), index + 1]
    _score_label.text = str(int(_state.get("score", 0)))
    var readings: Dictionary = _state.get("readings", {})
    for probe_id in _probe_buttons.keys():
        var button: Button = _probe_buttons[probe_id]
        var reading_label: Label = _reading_labels[probe_id]
        button.disabled = str(_state.get("status", "")) != "scanning" or readings.has(probe_id)
        reading_label.text = "%s: %s" % [probe_id, str(readings.get(probe_id, "--")) + (" units" if readings.has(probe_id) else "")]
    var candidates: Array[Vector2i] = _rules.call("get_candidate_cells", _state)
    _candidate_label.text = "REMAINING CANDIDATES: %d" % candidates.size()
    var selected: Vector2i = _state.get("selected_cell", Vector2i(-1, -1))
    _selected_label.text = "SELECTED: %s" % ("(%d, %d)" % [selected.x, selected.y] if selected.x >= 0 else "--")
    var locate_mode: bool = str(_state.get("status", "")) == "locate"
    for index_in_grid in range(_cell_buttons.size()):
        var cell := Vector2i(index_in_grid % 7, int(index_in_grid / 7))
        var button: Button = _cell_buttons[index_in_grid]
        var is_candidate: bool = candidates.has(cell)
        button.disabled = not locate_mode or not is_candidate
        if selected == cell:
            button.text = "O"
        elif is_candidate and locate_mode:
            button.text = "+"
        elif is_candidate:
            button.text = "?"
        else:
            button.text = "X"
    var status: String = str(_state.get("status", ""))
    _submit_button.disabled = not locate_mode or selected.x < 0
    _reset_button.disabled = status in ["complete", "campaign_complete"]
    _next_button.disabled = status != "complete"
    if status == "campaign_complete":
        _next_button.disabled = true
        _next_button.text = "CAMPAIGN COMPLETE"
    _status_label.text = str(_state.get("last_message", ""))

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_probe_button_count() -> int:
    return _probe_buttons.size()

func get_grid_button_count() -> int:
    return _cell_buttons.size()

func get_title_text() -> String:
    return "KROLL // FAULTLINE CARTOGRAPHER"

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_1: perform_probe("NW")
        KEY_2: perform_probe("NE")
        KEY_3: perform_probe("SW")
        KEY_SPACE: submit_guess()
        KEY_R: _reset_survey()
        KEY_N: _advance_survey()
