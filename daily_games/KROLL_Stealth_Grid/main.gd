extends Control

var rules: Variant
const BOARD_SIZE := 9

var state: Dictionary = {}
var board_grid: GridContainer
var board_cells: Array[Button] = []
var mission_label: Label
var stats_label: Label
var status_label: Label
var next_button: Button
var action_buttons: Array[Button] = []

func _ready() -> void:
    var rules_path := "res://daily_games/KROLL_Stealth_Grid/rules.gd"
    if not ResourceLoader.exists(rules_path):
        rules_path = "res://rules.gd"
    var rules_script := load(rules_path) as Script
    if rules_script == null:
        push_error("KROLL Stealth Grid could not load its rules script.")
        return
    rules = rules_script.new()
    state = rules.create_state()
    _build_ui()
    _refresh()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color(0.025, 0.045, 0.07)
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620.0, 0.0)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 9)
    margin.add_child(column)

    var title := Label.new()
    title.name = "GameTitle"
    title.text = "KROLL // STEALTH GRID"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 27)
    title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
    column.add_child(title)

    mission_label = Label.new()
    mission_label.name = "MissionLabel"
    mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_label.add_theme_font_size_override("font_size", 18)
    column.add_child(mission_label)

    stats_label = Label.new()
    stats_label.name = "StatsLabel"
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.88))
    column.add_child(stats_label)

    var board_center := CenterContainer.new()
    column.add_child(board_center)

    board_grid = GridContainer.new()
    board_grid.name = "StealthBoard"
    board_grid.columns = BOARD_SIZE
    board_grid.add_theme_constant_override("h_separation", 3)
    board_grid.add_theme_constant_override("v_separation", 3)
    board_center.add_child(board_grid)

    for index in range(BOARD_SIZE * BOARD_SIZE):
        var cell := Button.new()
        cell.custom_minimum_size = Vector2(48.0, 48.0)
        cell.focus_mode = Control.FOCUS_NONE
        cell.disabled = true
        cell.add_theme_font_size_override("font_size", 18)
        board_grid.add_child(cell)
        board_cells.append(cell)

    status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.custom_minimum_size = Vector2(0.0, 38.0)
    column.add_child(status_label)

    var directions := GridContainer.new()
    directions.columns = 3
    directions.add_theme_constant_override("h_separation", 6)
    directions.add_theme_constant_override("v_separation", 6)
    column.add_child(directions)
    _add_spacer(directions)
    _add_direction_button(directions, "UP", Vector2i(0, -1))
    _add_spacer(directions)
    _add_direction_button(directions, "LEFT", Vector2i(-1, 0))
    _add_direction_button(directions, "WAIT", Vector2i.ZERO)
    _add_direction_button(directions, "RIGHT", Vector2i(1, 0))
    _add_spacer(directions)
    _add_direction_button(directions, "DOWN", Vector2i(0, 1))
    _add_spacer(directions)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 6)
    column.add_child(actions)
    var restart_button := _add_action_button(actions, "RESTART")
    restart_button.pressed.connect(_restart_level)
    var campaign_button := _add_action_button(actions, "RESET CAMPAIGN")
    campaign_button.pressed.connect(_restart_campaign)
    next_button = _add_action_button(actions, "NEXT")
    next_button.pressed.connect(_next_level)

    var hint := Label.new()
    hint.text = "WASD / arrows move · Space wait · R retry · N next · C reset campaign"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.62, 0.72, 0.78))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(hint)

func _add_spacer(parent: GridContainer) -> void:
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(78.0, 38.0)
    parent.add_child(spacer)

func _add_direction_button(parent: GridContainer, label_text: String, direction: Vector2i) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(78.0, 38.0)
    button.pressed.connect(_attempt_move.bind(direction))
    parent.add_child(button)
    action_buttons.append(button)

func _add_action_button(parent: HBoxContainer, label_text: String) -> Button:
    var button := Button.new()
    button.text = label_text
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(0.0, 38.0)
    parent.add_child(button)
    action_buttons.append(button)
    return button

func _attempt_move(direction: Vector2i) -> void:
    var result: Dictionary = rules.attempt_move(state, direction)
    if not bool(result.get("ok", false)):
        state["message"] = "Blocked: that tile cannot be entered."
    _refresh()

func _restart_level() -> void:
    state = rules.restart_level(state)
    _refresh()

func _restart_campaign() -> void:
    state = rules.restart_campaign()
    _refresh()

func _next_level() -> void:
    if rules.can_advance(state):
        state = rules.next_level(state)
        _refresh()

func _unhandled_input(event: InputEvent) -> void:
    var key_event := event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_W, KEY_UP:
            _attempt_move(Vector2i(0, -1))
        KEY_S, KEY_DOWN:
            _attempt_move(Vector2i(0, 1))
        KEY_A, KEY_LEFT:
            _attempt_move(Vector2i(-1, 0))
        KEY_D, KEY_RIGHT:
            _attempt_move(Vector2i(1, 0))
        KEY_SPACE:
            _attempt_move(Vector2i.ZERO)
        KEY_R:
            _restart_level()
        KEY_C:
            _restart_campaign()
        KEY_N:
            _next_level()

func _refresh() -> void:
    var level: Dictionary = state["level"]
    mission_label.text = "SECTOR %d / %d — %s" % [
        int(state["level_index"]) + 1,
        rules.get_level_count(),
        rules.get_level_name(state)
    ]
    stats_label.text = "TURN %d    KEYS %d/%d    SCORE %d / 300" % [
        int(state["turn"]),
        rules.get_collected_key_count(state),
        level["keys"].size(),
        int(state["score"])
    ]
    status_label.text = str(state["message"])
    for index in range(board_cells.size()):
        var position := Vector2i(index % BOARD_SIZE, floori(float(index) / BOARD_SIZE))
        var tile: String = rules.render_tile(state, position)
        var cell: Button = board_cells[index]
        cell.text = tile
        var style := StyleBoxFlat.new()
        style.bg_color = _tile_color(tile)
        style.border_width_left = 1
        style.border_width_right = 1
        style.border_width_top = 1
        style.border_width_bottom = 1
        style.border_color = Color(0.16, 0.25, 0.31)
        cell.add_theme_stylebox_override("disabled", style)
        cell.add_theme_color_override("font_disabled_color", _tile_text_color(tile))
    var terminal: bool = bool(state["failed"]) or bool(state["complete"])
    for button in action_buttons:
        if button.text != "RESTART" and button.text != "RESET CAMPAIGN" and button.text != "NEXT":
            button.disabled = terminal
    next_button.disabled = not rules.can_advance(state)

func _tile_color(tile: String) -> Color:
    match tile:
        "#":
            return Color(0.055, 0.075, 0.10)
        "P":
            return Color(0.06, 0.34, 0.43)
        "G":
            return Color(0.48, 0.12, 0.16)
        "K":
            return Color(0.46, 0.34, 0.08)
        "E":
            return Color(0.08, 0.38, 0.23)
        _:
            return Color(0.12, 0.17, 0.22)

func _tile_text_color(tile: String) -> Color:
    match tile:
        "P":
            return Color(0.45, 0.96, 1.0)
        "G":
            return Color(1.0, 0.58, 0.55)
        "K":
            return Color(1.0, 0.87, 0.42)
        "E":
            return Color(0.55, 1.0, 0.69)
        "#":
            return Color(0.22, 0.28, 0.33)
        _:
            return Color(0.72, 0.81, 0.86)

func get_title_text() -> String:
    return "KROLL // STEALTH GRID"

func get_mission_count() -> int:
    return rules.get_level_count()

func get_board_cell_count() -> int:
    return board_cells.size()

func get_control_button_count() -> int:
    return action_buttons.size()

func get_current_mission_index() -> int:
    return int(state.get("level_index", -1))
