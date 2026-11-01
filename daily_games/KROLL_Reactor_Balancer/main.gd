extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Reactor_Balancer/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"
const ACTION_LABELS: Dictionary = {
    "acid": "ADD ACID  (A)",
    "base": "ADD BASE  (D)",
    "heat": "HEAT  (W)",
    "cool": "COOL  (S)",
    "vent": "VENT  (V)",
    "stir": "STIR  (SPACE)"
}

var _rules: RefCounted
var _state: Dictionary = {}
var _readout_labels: Dictionary = {}
var _status_label: Label
var _progress_bar: ProgressBar
var _action_buttons: Array[Button] = []
var _reset_button: Button
var _next_button: Button

func _ready() -> void:
    var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
    var rules_script: Script = load(rules_path) as Script
    if rules_script == null:
        push_error("KROLL Reactor Balancer could not load its rules.")
        return
    _rules = rules_script.new() as RefCounted
    if _rules == null:
        push_error("KROLL Reactor Balancer could not instantiate its process model.")
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
    panel.custom_minimum_size = Vector2(1040, 680)
    center.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)

    var title := Label.new()
    title.text = "KROLL // REACTOR BALANCER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color("#f0bd68"))
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "PROCESS CONTROL // THREE BATCHES // FOUR STABLE CYCLES"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#9eb2c2"))
    column.add_child(subtitle)

    var content := HBoxContainer.new()
    content.add_theme_constant_override("separation", 16)
    column.add_child(content)

    var readout_panel := PanelContainer.new()
    readout_panel.custom_minimum_size = Vector2(420, 400)
    readout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(readout_panel)

    var readouts := VBoxContainer.new()
    readouts.add_theme_constant_override("separation", 14)
    readout_panel.add_child(readouts)

    _add_readout(readouts, "SCENARIO", "scenario")
    _add_readout(readouts, "pH", "ph")
    _add_readout(readouts, "TEMPERATURE", "temperature")
    _add_readout(readouts, "PRESSURE", "pressure")
    _add_readout(readouts, "TURN", "turn")
    _add_readout(readouts, "STABLE CYCLES", "streak")

    var progress_title := Label.new()
    progress_title.text = "STABILIZATION PROGRESS"
    progress_title.add_theme_color_override("font_color", Color("#a8bac9"))
    readouts.add_child(progress_title)
    _progress_bar = ProgressBar.new()
    _progress_bar.min_value = 0
    _progress_bar.max_value = 100
    _progress_bar.custom_minimum_size = Vector2(0, 28)
    readouts.add_child(_progress_bar)

    var action_panel := PanelContainer.new()
    action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(action_panel)
    var action_grid := GridContainer.new()
    action_grid.columns = 2
    action_grid.add_theme_constant_override("h_separation", 10)
    action_grid.add_theme_constant_override("v_separation", 10)
    action_panel.add_child(action_grid)

    for action in ["acid", "base", "heat", "cool", "vent", "stir"]:
        var button := Button.new()
        button.text = str(ACTION_LABELS[action])
        button.custom_minimum_size = Vector2(220, 74)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_perform_action.bind(action))
        action_grid.add_child(button)
        _action_buttons.append(button)

    var footer := HBoxContainer.new()
    footer.alignment = BoxContainer.ALIGNMENT_CENTER
    footer.add_theme_constant_override("separation", 12)
    column.add_child(footer)
    _reset_button = Button.new()
    _reset_button.text = "RESET / R"
    _reset_button.custom_minimum_size = Vector2(180, 48)
    _reset_button.pressed.connect(_reset_scenario)
    footer.add_child(_reset_button)
    _next_button = Button.new()
    _next_button.text = "NEXT BATCH / N"
    _next_button.custom_minimum_size = Vector2(220, 48)
    _next_button.pressed.connect(_advance_scenario)
    footer.add_child(_next_button)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color", Color("#e6c47c"))
    column.add_child(_status_label)

    var hint := Label.new()
    hint.text = "A/D: acid/base  |  W/S: heat/cool  |  V: vent  |  SPACE: stir  |  R: reset  |  N: next batch"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_color_override("font_color", Color("#8ea5b8"))
    column.add_child(hint)

func _add_readout(parent: VBoxContainer, title_text: String, key: String) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)
    var title := Label.new()
    title.text = title_text
    title.custom_minimum_size = Vector2(150, 0)
    title.add_theme_color_override("font_color", Color("#a8bac9"))
    row.add_child(title)
    var value := Label.new()
    value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value.add_theme_color_override("font_color", Color("#edf3f7"))
    row.add_child(value)
    _readout_labels[key] = value

func _perform_action(action: String) -> void:
    perform_action(action)

func perform_action(action: String) -> bool:
    if _rules == null:
        return false
    var result: Dictionary = _rules.call("apply_action", _state, action)
    if not bool(result.get("ok", false)):
        _state = result.get("state", _state)
        _status_label.text = "ACTION REJECTED: %s" % str(result.get("reason", "unknown"))
        _refresh_ui()
        return false
    _state = result["state"]
    _refresh_ui()
    return true

func _reset_scenario() -> void:
    if _rules == null:
        return
    var result: Dictionary = _rules.call("reset_scenario", _state)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh_ui()

func _advance_scenario() -> void:
    if _rules == null:
        return
    var result: Dictionary = _rules.call("advance_scenario", _state)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh_ui()

func _refresh_ui() -> void:
    if _state.is_empty():
        return
    var scenario_index: int = int(_state.get("scenario_index", 0))
    var definition: Dictionary = _rules.call("get_scenario_definition", scenario_index)
    var target: Dictionary = definition.get("target", {})
    _readout_labels["scenario"].text = "%s  (%d/3)" % [str(_state.get("title", "")), scenario_index + 1]
    _readout_labels["ph"].text = "%.1f  /  %.1f ± 0.5" % [float(_state.get("ph", 0.0)), float(target.get("ph", 0.0))]
    _readout_labels["temperature"].text = "%.1f °C  /  %.1f ± 10" % [float(_state.get("temperature", 0.0)), float(target.get("temperature", 0.0))]
    _readout_labels["pressure"].text = "%.2f bar  /  %.2f ± 0.35" % [float(_state.get("pressure", 0.0)), float(target.get("pressure", 0.0))]
    _readout_labels["turn"].text = "%d / %d" % [int(_state.get("turn", 0)), int(_state.get("max_turns", 0))]
    _readout_labels["streak"].text = "%d / 4" % int(_state.get("stable_streak", 0))
    _progress_bar.value = float(_state.get("progress", 0))
    _status_label.text = str(_state.get("last_message", ""))
    var active: bool = str(_state.get("status", "")) == "active"
    for button in _action_buttons:
        button.disabled = not active
    _reset_button.disabled = str(_state.get("status", "")) in ["complete", "campaign_complete"]
    _next_button.disabled = str(_state.get("status", "")) != "complete"
    if str(_state.get("status", "")) == "campaign_complete":
        _next_button.disabled = true
        _next_button.text = "CAMPAIGN COMPLETE"

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_action_button_count() -> int:
    return _action_buttons.size()

func get_title_text() -> String:
    return "KROLL // REACTOR BALANCER"

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_A: perform_action("acid")
        KEY_D: perform_action("base")
        KEY_W: perform_action("heat")
        KEY_S: perform_action("cool")
        KEY_V: perform_action("vent")
        KEY_SPACE: perform_action("stir")
        KEY_R: _reset_scenario()
        KEY_N: _advance_scenario()
