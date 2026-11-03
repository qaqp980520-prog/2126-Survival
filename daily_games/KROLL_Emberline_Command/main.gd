extends Control

const GRID_SIZE: int = 8
var _rules: Variant
var _state: Dictionary = {}
var _cell_buttons: Array[Button] = []
var _action_buttons: Dictionary = {}
var _mission_label: Label
var _briefing_label: Label
var _wind_label: Label
var _resource_label: Label
var _status_label: Label
var _selected_label: Label
var _next_button: Button
var _selected_index: int = 19

func _ready() -> void:
    var attached_script: Script = get_script() as Script
    var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
    var rules_script: Script = load(rules_path) as Script
    if rules_script == null:
        push_error("Emberline Command rules script could not be loaded: " + rules_path)
        return
    _rules = rules_script.new()
    _state = _rules.create_state(0)
    _build_ui()
    _refresh_ui()

func _build_ui() -> void:
    var viewport_width: float = get_viewport_rect().size.x
    var compact: bool = viewport_width > 0.0 and viewport_width <= 560.0
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#071820")
    add_child(background)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left",10 if compact else 24)
    margin.add_theme_constant_override("margin_right",10 if compact else 24)
    margin.add_theme_constant_override("margin_top",12)
    margin.add_theme_constant_override("margin_bottom",12)
    scroll.add_child(margin)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation",8)
    margin.add_child(column)
    var title := Label.new()
    title.text = "KROLL // EMBERLINE COMMAND"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",20 if compact else 30)
    title.add_theme_color_override("font_color",Color("#ffbd77"))
    column.add_child(title)
    _mission_label = Label.new()
    _mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _mission_label.add_theme_font_size_override("font_size",16 if compact else 21)
    _mission_label.add_theme_color_override("font_color",Color("#e7d5a7"))
    column.add_child(_mission_label)
    _briefing_label = Label.new()
    _briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _briefing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _briefing_label.add_theme_color_override("font_color",Color("#b9cbd0"))
    column.add_child(_briefing_label)
    _wind_label = Label.new()
    _wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _wind_label.add_theme_color_override("font_color",Color("#8dd4e5"))
    column.add_child(_wind_label)
    _resource_label = Label.new()
    _resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _resource_label.add_theme_color_override("font_color",Color("#d5c59e"))
    column.add_child(_resource_label)
    var board_panel := PanelContainer.new()
    board_panel.add_theme_stylebox_override("panel",_panel_style())
    column.add_child(board_panel)
    var board_margin := MarginContainer.new()
    board_margin.add_theme_constant_override("margin_left",5)
    board_margin.add_theme_constant_override("margin_right",5)
    board_margin.add_theme_constant_override("margin_top",5)
    board_margin.add_theme_constant_override("margin_bottom",5)
    board_panel.add_child(board_margin)
    var grid := GridContainer.new()
    grid.name = "FireGrid"
    grid.columns = GRID_SIZE
    grid.add_theme_constant_override("h_separation",3)
    grid.add_theme_constant_override("v_separation",3)
    grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    board_margin.add_child(grid)
    var cell_size: float = 38.0 if compact else 54.0
    for index in range(GRID_SIZE*GRID_SIZE):
        var cell_button := Button.new()
        cell_button.custom_minimum_size = Vector2(cell_size,cell_size)
        cell_button.focus_mode = Control.FOCUS_NONE
        cell_button.add_theme_font_size_override("font_size",17 if compact else 22)
        cell_button.pressed.connect(select_cell.bind(index))
        grid.add_child(cell_button)
        _cell_buttons.append(cell_button)
    _selected_label = Label.new()
    _selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _selected_label.add_theme_color_override("font_color",Color("#f3d49c"))
    column.add_child(_selected_label)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation",7)
    column.add_child(actions)
    _add_action_button(actions,"firebreak","FIREBREAK  ·  F")
    _add_action_button(actions,"water","WATER  ·  V")
    var end_button := Button.new()
    end_button.text = "END TURN  ·  ENTER"
    end_button.custom_minimum_size = Vector2(0.0,44.0)
    end_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    end_button.pressed.connect(end_turn)
    actions.add_child(end_button)
    _action_buttons["end_turn"] = end_button
    var navigation := HBoxContainer.new()
    navigation.add_theme_constant_override("separation",7)
    column.add_child(navigation)
    _next_button = Button.new()
    _next_button.text = "NEXT MISSION  ·  N"
    _next_button.custom_minimum_size = Vector2(0.0,42.0)
    _next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _next_button.pressed.connect(advance_mission)
    navigation.add_child(_next_button)
    var restart_button := Button.new()
    restart_button.text = "RESTART  ·  R"
    restart_button.custom_minimum_size = Vector2(0.0,42.0)
    restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    restart_button.pressed.connect(restart_campaign)
    navigation.add_child(restart_button)
    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_color_override("font_color",Color("#ffbd77"))
    column.add_child(_status_label)
    var hint := Label.new()
    hint.text = "ARROWS: SELECT   F: FIREBREAK   V: WATER   ENTER: END TURN   N: NEXT   R: RESTART"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size",11)
    hint.add_theme_color_override("font_color",Color("#7898a2"))
    column.add_child(hint)

func _add_action_button(parent: HBoxContainer, action: String, label_text: String) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(0.0,44.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(perform_action.bind(action))
    parent.add_child(button)
    _action_buttons[action] = button

func select_cell(cell_index: int) -> void:
    if cell_index < 0 or cell_index >= GRID_SIZE*GRID_SIZE:
        return
    _selected_index = cell_index
    _refresh_ui()

func perform_action(action: String) -> Dictionary:
    if _rules == null or _state.is_empty():
        return {"ok":false,"reason":"rules_unavailable"}
    var result: Dictionary = _rules.apply_action(_state,action,_selected_index)
    if bool(result.get("ok",false)):
        _state = result["state"]
    else:
        _status_label.text = "COMMAND REJECTED: " + str(result.get("reason","unknown"))
    _refresh_ui()
    return result

func end_turn() -> Dictionary:
    if _rules == null:
        return {"ok":false,"reason":"rules_unavailable"}
    var result: Dictionary = _rules.end_turn(_state)
    if bool(result.get("ok",false)):
        _state = result["state"]
        _selected_index = -1
    _refresh_ui()
    return result

func advance_mission() -> Dictionary:
    if _rules == null:
        return {"ok":false,"reason":"rules_unavailable"}
    var result: Dictionary = _rules.advance_mission(_state)
    if bool(result.get("ok",false)):
        _state = result["state"]
        _selected_index = 19
    _refresh_ui()
    return result

func restart_campaign() -> void:
    if _rules == null:
        return
    var result: Dictionary = _rules.restart_campaign()
    if bool(result.get("ok",false)):
        _state = result["state"]
        _selected_index = 19
    _refresh_ui()

func get_title_text() -> String:
    return "KROLL // EMBERLINE COMMAND"

func get_mission_count() -> int:
    return int(_rules.get_mission_count()) if _rules != null else 0

func get_cell_button_count() -> int:
    return _cell_buttons.size()

func get_action_button_count() -> int:
    return 2

func get_control_button_count() -> int:
    return _action_buttons.size()+2

func get_current_state() -> Dictionary:
    return _state.duplicate(true)

func get_selected_cell() -> int:
    return _selected_index

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    var x: int = _selected_index % GRID_SIZE if _selected_index >= 0 else 0
    var y: int = int(_selected_index/GRID_SIZE) if _selected_index >= 0 else 0
    match event.keycode:
        KEY_LEFT,KEY_A:
            x = maxi(0,x-1)
            select_cell(y*GRID_SIZE+x)
        KEY_RIGHT,KEY_D:
            x = mini(GRID_SIZE-1,x+1)
            select_cell(y*GRID_SIZE+x)
        KEY_UP,KEY_W:
            y = maxi(0,y-1)
            select_cell(y*GRID_SIZE+x)
        KEY_DOWN,KEY_S:
            y = mini(GRID_SIZE-1,y+1)
            select_cell(y*GRID_SIZE+x)
        KEY_F:
            perform_action("firebreak")
        KEY_V:
            perform_action("water")
        KEY_ENTER,KEY_KP_ENTER:
            end_turn()
        KEY_N:
            advance_mission()
        KEY_R:
            restart_campaign()

func _refresh_ui() -> void:
    if _rules == null or _state.is_empty():
        return
    var mission_index: int = int(_state.get("mission_index",0))
    var mission: Dictionary = _rules.get_mission_definition(mission_index)
    var status: String = str(_state.get("status","playing"))
    _mission_label.text = "MISSION %d / 3  ·  %s" % [mission_index+1,str(mission.get("title",""))]
    _briefing_label.text = str(mission.get("briefing",""))
    _wind_label.text = "WIND: %s   ·   TURN %d / %d" % [str(_rules.get_wind_direction(_state)).to_upper(),int(_state.get("turn",0)),int(mission.get("max_turns",0))]
    _resource_label.text = "ACTIONS %d   ·   FIREBREAKS %d   ·   WATER DROPS %d   ·   ACTIVE FIRES %d   ·   RELAYS %d" % [int(_state.get("actions_left",0)),int(_state.get("firebreaks_remaining",0)),int(_state.get("water_drops",0)),int(_rules.get_active_fire_count(_state)),int(_rules.get_relay_count(_state))]
    var selected: Dictionary = _rules.get_cell_state(_state,_selected_index)
    _selected_label.text = "SELECTED: %s  ·  CELL %d" % [str(selected.get("terrain","none")).to_upper(),_selected_index]
    _status_label.text = _status_text(status)
    _next_button.disabled = status != "passed"
    _action_buttons["firebreak"].disabled = status != "playing" or int(_state.get("actions_left",0)) <= 0 or int(_state.get("firebreaks_remaining",0)) <= 0
    _action_buttons["water"].disabled = status != "playing" or int(_state.get("actions_left",0)) <= 0 or int(_state.get("water_drops",0)) <= 0
    _action_buttons["end_turn"].disabled = status != "playing"
    var cells: Array = _state.get("cells",[])
    for index in range(mini(cells.size(),_cell_buttons.size())):
        var cell: Dictionary = cells[index]
        var button: Button = _cell_buttons[index]
        button.text = _cell_text(cell)
        button.add_theme_color_override("font_color",Color("#fff4d8"))
        var selected_cell: bool = index == _selected_index
        var style := _cell_style(_cell_color(cell),selected_cell)
        button.add_theme_stylebox_override("normal",style)
        button.add_theme_stylebox_override("hover",_cell_style(_cell_color(cell).lightened(0.12),selected_cell))
        button.add_theme_stylebox_override("pressed",_cell_style(_cell_color(cell).darkened(0.12),selected_cell))
        button.disabled = status != "playing"

func _cell_text(cell: Dictionary) -> String:
    if bool(cell.get("burning",false)): return "F"
    if bool(cell.get("firebreak",false)): return "B"
    if bool(cell.get("relay",false)): return "R"
    if bool(cell.get("burned",false)): return "x"
    if int(cell.get("wet",0)) > 0: return "W"
    match str(cell.get("terrain","")):
        "forest": return "T"
        "water": return "~"
        "rock": return "■"
        _: return "·"

func _cell_color(cell: Dictionary) -> Color:
    if bool(cell.get("burning",false)): return Color("#dc5638")
    if bool(cell.get("firebreak",false)): return Color("#b28b55")
    if bool(cell.get("relay",false)): return Color("#278f82")
    if bool(cell.get("burned",false)): return Color("#292f34")
    if int(cell.get("wet",0)) > 0: return Color("#34728d")
    match str(cell.get("terrain","")):
        "forest": return Color("#315b45")
        "water": return Color("#214d70")
        "rock": return Color("#58636a")
        _: return Color("#667d4d")

func _cell_style(color: Color, selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_width_left = 3 if selected else 1
    style.border_width_right = 3 if selected else 1
    style.border_width_top = 3 if selected else 1
    style.border_width_bottom = 3 if selected else 1
    style.border_color = Color("#ffe2a1") if selected else Color("#1a2b32")
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    return style

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#10252d")
    style.border_color = Color("#38545c")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    return style

func _status_text(status: String) -> String:
    match status:
        "passed": return "FIRE CONTAINED — RELAY NETWORK SECURE. PRESS N FOR THE NEXT MISSION."
        "failed": return "MISSION FAILED — A RELAY WAS LOST OR THE FIRE OUTRAN THE RESPONSE. PRESS R TO RESTART."
        "campaign_complete": return "CAMPAIGN COMPLETE — ALL THREE RELAY NETWORKS SURVIVED."
        _: return "SELECT A CELL. F BUILDS A FIREBREAK, V DROPS WATER, ENTER ADVANCES THE FIRE FRONT."
