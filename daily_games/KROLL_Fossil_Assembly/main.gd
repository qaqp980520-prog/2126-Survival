extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Fossil_Assembly/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"

var _rules: Script
var _state: Dictionary = {}
var _selected_piece_id: String = ""
var _selected_rotation: int = 0
var _cursor: Vector2i = Vector2i.ZERO
var _cell_buttons: Array[Button] = []
var _piece_buttons: Dictionary = {}
var _status_label: Label
var _title_label: Label
var _next_button: Button

func _ready() -> void:
    var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
    _rules = load(rules_path) as Script
    if _rules == null:
        push_error("KROLL Fossil Assembly could not load its rules module.")
        return
    _state = _rules.create_state(0)
    _build_ui()
    _refresh_ui()

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_piece_button_count() -> int:
    return _piece_buttons.size()

func get_board_cell_count() -> int:
    return _cell_buttons.size()

func get_title_text() -> String:
    return _title_label.text if is_instance_valid(_title_label) else ""

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

    _title_label = Label.new()
    _title_label.text = "KROLL // FOSSIL ASSEMBLY LAB"
    _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title_label.add_theme_font_size_override("font_size", 25)
    _title_label.add_theme_color_override("font_color", Color("#8fe3dc"))
    column.add_child(_title_label)

    var subtitle := Label.new()
    subtitle.text = "SPECIMEN RECONSTRUCTION / POLYOMINO FITTING"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#a8b7c6"))
    column.add_child(subtitle)

    var board_row := HBoxContainer.new()
    board_row.alignment = BoxContainer.ALIGNMENT_CENTER
    board_row.add_theme_constant_override("separation", 18)
    column.add_child(board_row)

    var board := GridContainer.new()
    board.name = "SpecimenGrid"
    board.columns = 5
    board.add_theme_constant_override("h_separation", 5)
    board.add_theme_constant_override("v_separation", 5)
    board_row.add_child(board)

    for y in range(5):
        for x in range(5):
            var cell := Button.new()
            cell.custom_minimum_size = Vector2(58, 58)
            cell.focus_mode = Control.FOCUS_NONE
            cell.pressed.connect(_on_cell_pressed.bind(Vector2i(x, y)))
            board.add_child(cell)
            _cell_buttons.append(cell)

    var side_panel := VBoxContainer.new()
    side_panel.custom_minimum_size = Vector2(230, 0)
    side_panel.add_theme_constant_override("separation", 8)
    board_row.add_child(side_panel)

    var piece_title := Label.new()
    piece_title.text = "FRAGMENTS"
    piece_title.add_theme_color_override("font_color", Color("#8fe3dc"))
    side_panel.add_child(piece_title)

    var definition: Dictionary = _rules.get_level_definition(int(_state["level_index"]))
    for piece in definition["pieces"]:
        var piece_id: String = str(piece["id"])
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 46)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_on_piece_pressed.bind(piece_id))
        side_panel.add_child(button)
        _piece_buttons[piece_id] = button

    var controls := HBoxContainer.new()
    controls.alignment = BoxContainer.ALIGNMENT_CENTER
    controls.add_theme_constant_override("separation", 8)
    column.add_child(controls)
    _add_control_button(controls, "ROTATE Q", _rotate_left)
    _add_control_button(controls, "ROTATE E", _rotate_right)
    _add_control_button(controls, "PLACE SPACE", _place_at_cursor)
    _add_control_button(controls, "UNDO X", _undo_last)
    _add_control_button(controls, "RESET R", _reset_level)
    _next_button = _add_control_button(controls, "NEXT N", _next_level)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color", Color("#f0c879"))
    column.add_child(_status_label)

    var hint := Label.new()
    hint.text = "選擇碎片後點擊目標格放置；Q/E 旋轉、Space 放置、X 撤回。每個碎片必須完整落在化石輪廓內。"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_color_override("font_color", Color("#93a6b8"))
    column.add_child(hint)

func _add_control_button(parent: HBoxContainer, text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(112, 42)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _on_cell_pressed(cell: Vector2i) -> void:
    _cursor = cell
    if _selected_piece_id.is_empty():
        _refresh_ui()
        return
    _place_piece(_selected_piece_id, _cursor, _selected_rotation)

func _on_piece_pressed(piece_id: String) -> void:
    var piece_state: Dictionary = _state.get("pieces", {}).get(piece_id, {})
    if bool(piece_state.get("placed", false)):
        var removed: Dictionary = _rules.remove_piece(_state, piece_id)
        if bool(removed.get("ok", false)):
            _state = removed["state"]
            _selected_piece_id = piece_id
            _selected_rotation = 0
            _status_label.text = "FRAGMENT REMOVED / SELECT A NEW POSITION"
    else:
        _selected_piece_id = piece_id
        _selected_rotation = 0
        _status_label.text = "SELECTED %s / ROTATION %d" % [piece_id.to_upper(), _selected_rotation]
    _refresh_ui()

func _place_piece(piece_id: String, origin: Vector2i, rotation: int) -> void:
    var result: Dictionary = _rules.place_piece(_state, piece_id, origin, rotation)
    if bool(result.get("ok", false)):
        _state = result["state"]
        _selected_piece_id = ""
        if str(_state.get("status", "")) == "won":
            _status_label.text = "SPECIMEN COMPLETE / ALL FRAGMENTS FITTED"
        else:
            _status_label.text = "FRAGMENT PLACED / %d CELLS RESTORED" % int(result["cells"].size())
    else:
        _status_label.text = "INVALID FIT / %s" % str(result.get("reason", "unknown")).to_upper()
    _refresh_ui()

func _rotate_left() -> void:
    if not _selected_piece_id.is_empty():
        _selected_rotation = posmod(_selected_rotation - 1, 4)
        _status_label.text = "ROTATION %d" % _selected_rotation
        _refresh_ui()

func _rotate_right() -> void:
    if not _selected_piece_id.is_empty():
        _selected_rotation = posmod(_selected_rotation + 1, 4)
        _status_label.text = "ROTATION %d" % _selected_rotation
        _refresh_ui()

func _place_at_cursor() -> void:
    if not _selected_piece_id.is_empty():
        _place_piece(_selected_piece_id, _cursor, _selected_rotation)

func _undo_last() -> void:
    for piece in _rules.get_level_definition(int(_state["level_index"]))["pieces"]:
        var piece_id: String = str(piece["id"])
        if bool(_state["pieces"][piece_id].get("placed", false)):
            var result: Dictionary = _rules.remove_piece(_state, piece_id)
            if bool(result.get("ok", false)):
                _state = result["state"]
                _selected_piece_id = piece_id
                _selected_rotation = 0
                _status_label.text = "LAST FRAGMENT REMOVED"
            _refresh_ui()
            return
    _status_label.text = "NO FRAGMENT TO UNDO"
    _refresh_ui()

func _reset_level() -> void:
    _state = _rules.create_state(int(_state.get("level_index", 0)))
    _selected_piece_id = ""
    _selected_rotation = 0
    _cursor = Vector2i.ZERO
    _status_label.text = "SPECIMEN RESET"
    _refresh_ui()

func _next_level() -> void:
    if str(_state.get("status", "")) != "won":
        return
    var next_index: int = int(_state["level_index"]) + 1
    if next_index >= _rules.level_count():
        next_index = 0
    _state = _rules.create_state(next_index)
    _selected_piece_id = ""
    _selected_rotation = 0
    _cursor = Vector2i.ZERO
    _status_label.text = "NEXT SPECIMEN / %s" % str(_state["title"])
    _refresh_ui()

func _refresh_ui() -> void:
    if _state.is_empty():
        return
    var target_cells: Array = _state.get("target_cells", [])
    var occupied: Dictionary = _state.get("occupied", {})
    for index in range(_cell_buttons.size()):
        var x: int = index % 5
        var y: int = int(index / 5)
        var cell := Vector2i(x, y)
        var button: Button = _cell_buttons[index]
        var piece_id: String = str(occupied.get(cell, ""))
        if not piece_id.is_empty():
            button.text = piece_id.substr(0, 1).to_upper()
            button.modulate = Color("#73c8ad")
        elif target_cells.has(cell):
            button.text = "·"
            button.modulate = Color("#314c57")
        else:
            button.text = ""
            button.modulate = Color("#18242d")
        if cell == _cursor:
            button.modulate = Color("#e4b65e")
    for piece_id in _piece_buttons.keys():
        var piece_state: Dictionary = _state["pieces"].get(piece_id, {})
        var button: Button = _piece_buttons[piece_id]
        var prefix: String = "✓ " if bool(piece_state.get("placed", false)) else "○ "
        var selected: String = "  ◀" if _selected_piece_id == piece_id else ""
        button.text = prefix + piece_id.to_upper() + selected
        button.disabled = str(_state.get("status", "")) == "won"
    _next_button.disabled = str(_state.get("status", "")) != "won"
    if _status_label.text.is_empty():
        _status_label.text = "%s / SELECT A FRAGMENT" % str(_state["title"])

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_W, KEY_UP:
                _cursor.y = maxi(0, _cursor.y - 1)
            KEY_S, KEY_DOWN:
                _cursor.y = mini(4, _cursor.y + 1)
            KEY_A, KEY_LEFT:
                _cursor.x = maxi(0, _cursor.x - 1)
            KEY_D, KEY_RIGHT:
                _cursor.x = mini(4, _cursor.x + 1)
            KEY_Q:
                _rotate_left()
            KEY_E:
                _rotate_right()
            KEY_SPACE:
                _place_at_cursor()
            KEY_X:
                _undo_last()
            KEY_R:
                _reset_level()
            KEY_N:
                _next_level()
        _refresh_ui()
