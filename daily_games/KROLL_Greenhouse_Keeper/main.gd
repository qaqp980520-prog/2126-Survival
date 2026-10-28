extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var _seed: int = 32
var _plot_buttons: Array[Button] = []
var _header: Label
var _summary: Label
var _details: Label
var _water_button: Button
var _advance_button: Button
var _harvest_button: Button
var _restart_button: Button
var _next_button: Button

func _ready() -> void:
    _build_ui()
    restart_game()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.color = Color(0.035, 0.065, 0.09)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 26)
    margin.add_theme_constant_override("margin_right", 26)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    margin.add_child(column)

    _header = Label.new()
    _header.text = "KROLL // GREENHOUSE KEEPER"
    _header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _header.add_theme_font_size_override("font_size", 28)
    _header.add_theme_color_override("font_color", Color(0.42, 0.95, 0.76))
    column.add_child(_header)

    _summary = Label.new()
    _summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _summary.add_theme_font_size_override("font_size", 17)
    _summary.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
    column.add_child(_summary)

    var plots_row := HBoxContainer.new()
    plots_row.add_theme_constant_override("separation", 12)
    plots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(plots_row)
    for i in range(Rules.CROP_IDS.size()):
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 250)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.size_flags_vertical = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 18)
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_on_plot_pressed.bind(i))
        plots_row.add_child(button)
        _plot_buttons.append(button)

    _details = Label.new()
    _details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details.add_theme_font_size_override("font_size", 16)
    _details.add_theme_color_override("font_color", Color(0.78, 0.86, 0.91))
    column.add_child(_details)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 10)
    column.add_child(actions)

    _water_button = _make_button("WATER PLOT", _on_water_pressed, actions)
    _advance_button = _make_button("ADVANCE DAY", _on_advance_pressed, actions)
    _harvest_button = _make_button("HARVEST", _on_harvest_pressed, actions)
    _restart_button = _make_button("RESTART (R)", _on_restart_pressed, actions)
    _next_button = _make_button("NEXT LAYOUT (N)", _on_next_pressed, actions)

    var help := Label.new()
    help.text = "Select a plot • Water is limited • Each day dries soil • Harvest 5 units by day 7"
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_color_override("font_color", Color(0.5, 0.67, 0.75))
    column.add_child(help)

func _make_button(text_value: String, callback: Callable, parent: Node) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(120, 42)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func select_plot(index: int) -> bool:
    var result: Dictionary = Rules.select_plot(state, index)
    if not bool(result.get("ok", false)):
        return false
    state = result["state"]
    _render()
    return true

func water_selected() -> bool:
    var result: Dictionary = Rules.water_plot(state, int(state.get("selected_plot", 0)))
    return _apply_result(result)

func advance_day() -> bool:
    var result: Dictionary = Rules.advance_day(state)
    return _apply_result(result)

func harvest_selected() -> bool:
    var result: Dictionary = Rules.harvest_plot(state, int(state.get("selected_plot", 0)))
    return _apply_result(result)

func restart_game() -> void:
    state = Rules.new_game(_seed)
    _render()

func next_layout() -> void:
    _seed += 1
    restart_game()

func _apply_result(result: Dictionary) -> bool:
    if not bool(result.get("ok", false)):
        state["message"] = "Unavailable: " + str(result.get("reason", "invalid action"))
        _render()
        return false
    state = result["state"]
    _render()
    return true

func _on_plot_pressed(index: int) -> void:
    select_plot(index)

func _on_water_pressed() -> void:
    water_selected()

func _on_advance_pressed() -> void:
    advance_day()

func _on_harvest_pressed() -> void:
    harvest_selected()

func _on_restart_pressed() -> void:
    restart_game()

func _on_next_pressed() -> void:
    next_layout()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1:
            select_plot(0)
        KEY_2:
            select_plot(1)
        KEY_3:
            select_plot(2)
        KEY_W:
            water_selected()
        KEY_D:
            advance_day()
        KEY_H:
            harvest_selected()
        KEY_R:
            restart_game()
        KEY_N:
            next_layout()
        KEY_LEFT:
            select_plot(posmod(int(state.get("selected_plot", 0)) - 1, _plot_buttons.size()))
        KEY_RIGHT:
            select_plot((int(state.get("selected_plot", 0)) + 1) % _plot_buttons.size())

func _render() -> void:
    if _summary == null:
        return
    var status: String = str(state.get("status", "playing")).to_upper()
    _summary.text = "DAY %d / %d     WATER %d     HARVEST %d / %d     STATUS: %s" % [
        int(state.get("day", 1)), Rules.MAX_DAYS, int(state.get("water_left", 0)),
        int(state.get("harvest_yield", 0)), Rules.TARGET_YIELD, status
    ]
    var plots: Array = state.get("plots", [])
    for i in range(mini(plots.size(), _plot_buttons.size())):
        var plot: Dictionary = plots[i]
        var crop_id: String = str(plot.get("crop_id", "crop")).to_upper()
        var stage: int = int(plot.get("growth_stage", 0))
        var moisture: int = roundi(float(plot.get("moisture", 0.0)))
        var harvested: bool = bool(plot.get("harvested", false))
        var stage_text: String = "HARVESTED" if harvested else "STAGE %d / %d" % [stage, Rules.MAX_STAGE]
        _plot_buttons[i].text = "PLOT %d\n%s\n%s\nMOISTURE %d%%" % [i + 1, crop_id, stage_text, moisture]
        _plot_buttons[i].disabled = status != "PLAYING" or harvested
        _plot_buttons[i].modulate = Color(0.45, 1.0, 0.72) if i == int(state.get("selected_plot", 0)) else Color.WHITE
    var selected_index: int = clampi(int(state.get("selected_plot", 0)), 0, max(0, plots.size() - 1))
    if not plots.is_empty():
        var selected: Dictionary = plots[selected_index]
        _details.text = "Selected: %s • Growth %d/%d • Soil moisture %d%%\n%s" % [
            str(selected.get("crop_id", "crop")).capitalize(),
            int(selected.get("growth_stage", 0)), Rules.MAX_STAGE,
            roundi(float(selected.get("moisture", 0.0))), str(state.get("message", ""))
        ]
        _water_button.disabled = status != "PLAYING" or int(state.get("water_left", 0)) <= 0 or bool(selected.get("harvested", false)) or float(selected.get("moisture", 0.0)) >= 100.0
        _advance_button.disabled = status != "PLAYING"
        _harvest_button.disabled = status != "PLAYING" or bool(selected.get("harvested", false)) or int(selected.get("growth_stage", 0)) < Rules.MAX_STAGE
    _restart_button.disabled = false
    _next_button.disabled = false
