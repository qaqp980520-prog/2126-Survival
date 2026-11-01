extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Microbe_Scope/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"
const ROOT_VIEW_PATH: String = "res://daily_games/KROLL_Microbe_Scope/specimen_view.gd"
const LOCAL_VIEW_PATH: String = "res://specimen_view.gd"

var _rules: RefCounted
var _state: Dictionary = {}
var _view: Control
var _parameter_labels: Dictionary = {}
var _specimen_label: Label
var _attempts_label: Label
var _score_label: Label
var _clarity_label: Label
var _status_label: Label
var _capture_button: Button
var _next_button: Button
var _reset_button: Button

func _ready() -> void:
    var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
    var view_path: String = ROOT_VIEW_PATH if ResourceLoader.exists(ROOT_VIEW_PATH) else LOCAL_VIEW_PATH
    var rules_script: Script = load(rules_path) as Script
    var view_script: Script = load(view_path) as Script
    if rules_script == null or view_script == null:
        push_error("KROLL Microbe Scope could not load its rules or specimen view.")
        return
    _rules = rules_script.new() as RefCounted
    _view = view_script.new() as Control
    if _rules == null or _view == null:
        push_error("KROLL Microbe Scope could not instantiate its game models.")
        return
    _state = _rules.call("create_state", 0)
    _build_ui()
    _refresh_ui()

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_parameter_control_count() -> int:
    return _parameter_labels.size()

func get_action_button_count() -> int:
    return 3

func get_title_text() -> String:
    return "KROLL // MICROBE SCOPE"

func set_parameter_value(parameter: String, value: int) -> bool:
    var result: Dictionary = _rules.call("set_parameter", _state, parameter, value)
    if not bool(result.get("ok", false)):
        return false
    _state = result["state"]
    _refresh_ui()
    return true

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#101923")
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

    var title := Label.new()
    title.text = "KROLL // MICROBE SCOPE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color("#8fe3dc"))
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "OPTICAL CALIBRATION / LIVE SPECIMEN ANALYSIS"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#a8b7c6"))
    column.add_child(subtitle)

    var content := HBoxContainer.new()
    content.add_theme_constant_override("separation", 18)
    column.add_child(content)

    var view_frame := PanelContainer.new()
    view_frame.custom_minimum_size = Vector2(610, 420)
    view_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(view_frame)
    _view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    view_frame.add_child(_view)

    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(330, 0)
    panel.add_theme_constant_override("separation", 10)
    content.add_child(panel)

    _specimen_label = Label.new()
    _specimen_label.add_theme_font_size_override("font_size", 20)
    _specimen_label.add_theme_color_override("font_color", Color("#edbd69"))
    panel.add_child(_specimen_label)

    _attempts_label = Label.new()
    panel.add_child(_attempts_label)
    _score_label = Label.new()
    panel.add_child(_score_label)
    _clarity_label = Label.new()
    panel.add_child(_clarity_label)

    _add_parameter_row(panel, "FOCUS", "focus", 2)
    _add_parameter_row(panel, "MAGNIFICATION", "magnification", 1)
    _add_parameter_row(panel, "ILLUMINATION", "illumination", 5)
    _add_parameter_row(panel, "STAIN FILTER", "stain", 1)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 10)
    column.add_child(actions)
    _capture_button = _add_action_button(actions, "CAPTURE / SPACE", _capture_sample)
    _reset_button = _add_action_button(actions, "RESET / R", _reset_specimen)
    _next_button = _add_action_button(actions, "NEXT / N", _next_specimen)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color", Color("#f0c879"))
    column.add_child(_status_label)

    var hint := Label.new()
    hint.text = "A/D: focus  |  W/S: magnification  |  Q/E: illumination  |  Z/X: stain  |  Space: capture. Tune all four settings until the live clarity reaches a valid calibration."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_color_override("font_color", Color("#93a6b8"))
    column.add_child(hint)

func _add_parameter_row(parent: VBoxContainer, title_text: String, parameter: String, step: int) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    var title := Label.new()
    title.text = title_text
    title.custom_minimum_size = Vector2(116, 0)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    var value := Label.new()
    value.custom_minimum_size = Vector2(38, 0)
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(value)
    _parameter_labels[parameter] = value
    var minus := Button.new()
    minus.text = "−"
    minus.custom_minimum_size = Vector2(42, 40)
    minus.pressed.connect(_adjust_parameter.bind(parameter, -step))
    row.add_child(minus)
    var plus := Button.new()
    plus.text = "+"
    plus.custom_minimum_size = Vector2(42, 40)
    plus.pressed.connect(_adjust_parameter.bind(parameter, step))
    row.add_child(plus)

func _add_action_button(parent: HBoxContainer, title_text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = title_text
    button.custom_minimum_size = Vector2(180, 48)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _adjust_parameter(parameter: String, delta: int) -> void:
    var result: Dictionary = _rules.call("adjust_parameter", _state, parameter, delta)
    if bool(result.get("ok", false)):
        _state = result["state"]
        _status_label.text = "CALIBRATION ADJUSTED / %s" % parameter.to_upper()
    _refresh_ui()

func _capture_sample() -> void:
    var result: Dictionary = _rules.call("capture", _state)
    if not bool(result.get("ok", false)):
        _status_label.text = "CAPTURE LOCKED / " + str(result.get("reason", "unknown")).to_upper()
        _refresh_ui()
        return
    _state = result["state"]
    if bool(result.get("captured", false)):
        _status_label.text = "SPECIMEN CAPTURED / CLARITY %d%%" % int(result["evaluation"]["clarity"])
    else:
        var errors: Array = result["evaluation"].get("errors", [])
        var error_text: String = ""
        for error in errors:
            if not error_text.is_empty():
                error_text += ", "
            error_text += str(error).to_upper()
        _status_label.text = "CALIBRATION MISS / %s / %d ATTEMPTS LEFT" % [error_text, int(_state["attempts_left"])]
        if str(_state["status"]) == "failed":
            _status_label.text = "SPECIMEN LOST / RESET TO RETRY"
    _refresh_ui()

func _reset_specimen() -> void:
    var previous_status: String = str(_state.get("status", ""))
    var result: Dictionary = _rules.call("reset_specimen", _state)
    if not bool(result.get("ok", false)):
        _status_label.text = "CAMPAIGN COMPLETE / RESET DISABLED" if str(result.get("reason", "")) == "campaign_complete" else "RESET UNAVAILABLE"
        _refresh_ui()
        return
    _state = result["state"]
    _status_label.text = "CAPTURE CREDIT REVERSED / SPECIMEN RESET" if previous_status == "captured" else "CURRENT SPECIMEN RESET"
    _refresh_ui()

func _next_specimen() -> void:
    var result: Dictionary = _rules.call("next_specimen", _state)
    if not bool(result.get("ok", false)):
        _status_label.text = "CAPTURE THE CURRENT SPECIMEN FIRST"
        _refresh_ui()
        return
    _state = result["state"]
    _status_label.text = "CAMPAIGN COMPLETE / %d SPECIMENS CAPTURED" % int(_state.get("captures", 0)) if bool(result.get("complete", false)) else "NEXT SPECIMEN LOADED"
    _refresh_ui()

func _refresh_ui() -> void:
    if _state.is_empty() or _view == null:
        return
    var definition: Dictionary = _rules.call("get_specimen_definition", int(_state["specimen_index"]))
    var evaluation: Dictionary = _rules.call("evaluate", _state)
    _specimen_label.text = str(definition.get("title", "UNKNOWN SPECIMEN"))
    _attempts_label.text = "CAPTURES REMAINING: %d" % int(_state.get("attempts_left", 0))
    _score_label.text = "CAMPAIGN SCORE: %d" % int(_state.get("score", 0))
    _clarity_label.text = "LIVE CLARITY: %d%%" % int(evaluation.get("clarity", 0))
    for parameter in _parameter_labels.keys():
        var label: Label = _parameter_labels[parameter]
        label.text = str(_state.get(parameter, 0))
    _view.call(
        "set_specimen_data",
        str(_state.get("specimen_id", "")),
        int(_state.get("magnification", 1)),
        int(_state.get("illumination", 0)),
        int(_state.get("stain", 0)),
        int(evaluation.get("clarity", 0))
    )
    var active: bool = str(_state.get("status", "")) == "active"
    _capture_button.disabled = not active
    _reset_button.disabled = str(_state.get("status", "")) == "complete"
    _next_button.disabled = str(_state.get("status", "")) != "captured"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_A:
                _adjust_parameter("focus", -2)
            KEY_D:
                _adjust_parameter("focus", 2)
            KEY_W:
                _adjust_parameter("magnification", 1)
            KEY_S:
                _adjust_parameter("magnification", -1)
            KEY_Q:
                _adjust_parameter("illumination", -5)
            KEY_E:
                _adjust_parameter("illumination", 5)
            KEY_Z:
                _adjust_parameter("stain", -1)
            KEY_X:
                _adjust_parameter("stain", 1)
            KEY_SPACE:
                _capture_sample()
            KEY_R:
                _reset_specimen()
            KEY_N:
                _next_specimen()
