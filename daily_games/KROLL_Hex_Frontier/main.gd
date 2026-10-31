extends Control

const RulesScript = preload("res://rules.gd")
const HEX_SIZE: float = 48.0
const HEX_SQRT3: float = 1.7320508

var _rules: RefCounted = RulesScript.new()
var _state: Dictionary = {}
var _scenario: int = 0
var _selected_action: String = "claim"
var _status_label: Label
var _detail_label: Label
var _action_buttons: Dictionary = {}

func _ready() -> void:
    _state = _rules.call("new_game", _scenario)
    _build_ui()
    _refresh()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#07111d"))
    draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(size.x, 6.0)), Color("#39d9cf"))
    for coord in _rules.call("get_cells"):
        var tile: Dictionary = _rules.call("get_tile", _state, coord)
        var center: Vector2 = _hex_center(coord)
        var points: PackedVector2Array = _hex_points(center)
        draw_colored_polygon(points, _tile_color(tile))
        var outline := PackedVector2Array()
        for point in points:
            outline.append(point)
        outline.append(points[0])
        var legal_cells: Array = _rules.call("get_legal_claims", _state, 1) if _selected_action == "claim" else _rules.call("get_legal_upgrades", _state, 1)
        var outline_color: Color = Color("#f4d36f") if legal_cells.has(coord) else Color("#9bb3c6")
        var outline_width: float = 4.0 if legal_cells.has(coord) else 2.0
        draw_polyline(outline, outline_color, outline_width, true)
        var owner: int = int(tile.get("owner", 0))
        var label: String = "HQ" if bool(tile.get("base", false)) else "+%d" % int(tile.get("yield", 0))
        var label_color: Color = Color("#f7fbff") if owner != 0 else Color("#d8e5ed")
        draw_string(ThemeDB.fallback_font, center + Vector2(-25.0, 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, 50.0, 16, label_color)
        if int(tile.get("upgrades", 0)) > 0:
            draw_string(ThemeDB.fallback_font, center + Vector2(-8.0, 25.0), "▲%d" % int(tile.get("upgrades", 0)), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 10, Color("#ffe08a"))

func _build_ui() -> void:
    _status_label = Label.new()
    _status_label.position = Vector2(20.0, 16.0)
    _status_label.size = Vector2(1050.0, 34.0)
    _status_label.add_theme_font_size_override("font_size", 20)
    _status_label.add_theme_color_override("font_color", Color("#e8f6ff"))
    add_child(_status_label)

    _detail_label = Label.new()
    _detail_label.position = Vector2(20.0, 52.0)
    _detail_label.size = Vector2(1050.0, 42.0)
    _detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detail_label.add_theme_font_size_override("font_size", 14)
    _detail_label.add_theme_color_override("font_color", Color("#9fc0d1"))
    add_child(_detail_label)

    var bar := HBoxContainer.new()
    bar.name = "ActionBar"
    bar.anchor_left = 0.5
    bar.anchor_right = 0.5
    bar.anchor_top = 1.0
    bar.anchor_bottom = 1.0
    bar.offset_left = -390.0
    bar.offset_right = 390.0
    bar.offset_top = -72.0
    bar.offset_bottom = -16.0
    bar.add_theme_constant_override("separation", 10)
    add_child(bar)
    _add_button(bar, "CLAIM", "claim", Callable(self, "_select_claim"))
    _add_button(bar, "UPGRADE", "upgrade", Callable(self, "_select_upgrade"))
    _add_button(bar, "END TURN", "turn", Callable(self, "end_player_turn"))
    _add_button(bar, "RESET", "reset", Callable(self, "reset_game"))
    _add_button(bar, "NEXT MAP", "next", Callable(self, "next_scenario"))

func _add_button(parent: HBoxContainer, label_text: String, key: String, callback: Callable) -> void:
    var button := Button.new()
    button.name = "Action_" + key
    button.text = label_text
    button.custom_minimum_size = Vector2(132.0, 48.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(callback)
    parent.add_child(button)
    _action_buttons[key] = button

func _select_claim() -> void:
    set_action("claim")

func _select_upgrade() -> void:
    set_action("upgrade")

func set_action(action: String) -> bool:
    if action != "claim" and action != "upgrade":
        return false
    _selected_action = action
    _refresh()
    return true

func perform_action_at(coord: Vector2i) -> Dictionary:
    var result: Dictionary
    if _selected_action == "claim":
        result = _rules.call("apply_claim", _state, coord)
    else:
        result = _rules.call("apply_upgrade", _state, coord)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh()
    return result

func end_player_turn() -> Dictionary:
    var result: Dictionary = _rules.call("advance_round", _state)
    if bool(result.get("ok", false)):
        _state = result["state"]
    _refresh()
    return result

func reset_game() -> void:
    _state = _rules.call("new_game", _scenario)
    _selected_action = "claim"
    _refresh()

func next_scenario() -> void:
    _scenario = posmod(_scenario + 1, 3)
    reset_game()

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_current_scenario() -> int:
    return _scenario

func get_selected_action() -> String:
    return _selected_action

func _refresh() -> void:
    if _status_label == null:
        queue_redraw()
        return
    var player_count: int = int(_rules.call("territory_count", _state, 1))
    var ai_count: int = int(_rules.call("territory_count", _state, 2))
    var player_energy: int = int(_rules.call("get_energy", _state, 1))
    var ai_energy: int = int(_rules.call("get_energy", _state, 2))
    var winner: int = int(_state.get("winner", 0))
    _status_label.text = "KROLL HEX FRONTIER  |  %s  |  TURN %02d  |  YOU %02d/10  |  AI %02d/10  |  ENERGY %d / %d" % [
        str(_rules.call("get_scenario_name", _scenario)).to_upper(),
        int(_state.get("turn", 1)),
        player_count,
        ai_count,
        player_energy,
        ai_energy
    ]
    if winner == 1:
        _detail_label.text = "OUTPOST NETWORK SECURED. YOU CONTROL TEN HEXES."
    elif winner == 2:
        _detail_label.text = "KROLL AI CONTROLLED TEN HEXES. RESET OR TRY ANOTHER MAP."
    else:
        _detail_label.text = "%s  |  Selected action: %s. Click a highlighted adjacent hex; upgrades improve future energy income." % [
            str(_state.get("last_action", "")),
            _selected_action.to_upper()
        ]
    var game_over: bool = winner != 0
    for key in _action_buttons.keys():
        var button: Button = _action_buttons[key] as Button
        if key == "claim":
            button.disabled = game_over or _rules.call("get_legal_claims", _state, 1).is_empty()
        elif key == "upgrade":
            button.disabled = game_over or _rules.call("get_legal_upgrades", _state, 1).is_empty()
        elif key == "turn":
            button.disabled = game_over
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_board_press(event.position)
        accept_event()
    elif event is InputEventScreenTouch and event.pressed:
        _handle_board_press(event.position)
        accept_event()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_C:
            set_action("claim")
        KEY_U:
            set_action("upgrade")
        KEY_ENTER, KEY_KP_ENTER:
            end_player_turn()
        KEY_R:
            reset_game()
        KEY_N:
            next_scenario()

func _handle_board_press(position: Vector2) -> void:
    var coord: Vector2i = _cell_at(position)
    if coord.x == 999:
        return
    perform_action_at(coord)

func _cell_at(position: Vector2) -> Vector2i:
    var best := Vector2i(999, 999)
    var best_distance: float = HEX_SIZE * 0.88
    for coord in _rules.call("get_cells"):
        var distance: float = position.distance_to(_hex_center(coord))
        if distance <= best_distance:
            best = coord
            best_distance = distance
    return best

func _board_center() -> Vector2:
    return Vector2(size.x * 0.5, size.y * 0.51)

func _hex_center(coord: Vector2i) -> Vector2:
    var offset := Vector2(
        HEX_SQRT3 * HEX_SIZE * (float(coord.x) + float(coord.y) * 0.5),
        1.5 * HEX_SIZE * float(coord.y)
    )
    return _board_center() + offset

func _hex_points(center: Vector2) -> PackedVector2Array:
    var points := PackedVector2Array()
    for index in range(6):
        var angle: float = deg_to_rad(30.0 + 60.0 * float(index))
        points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE)
    return points

func _tile_color(tile: Dictionary) -> Color:
    match int(tile.get("owner", 0)):
        1:
            return Color("#176f91")
        2:
            return Color("#8f3c4c")
        _:
            var yield_value: int = int(tile.get("yield", 0))
            return Color("#263b48") if yield_value <= 1 else (Color("#31545a") if yield_value == 2 else Color("#45665b"))
