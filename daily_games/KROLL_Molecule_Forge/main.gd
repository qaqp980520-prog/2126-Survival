extends Node2D

const RULES_PATH: String = "res://daily_games/KROLL_Molecule_Forge/rules.gd"
const ELEMENTS: Array[String] = ["H", "O", "N", "C"]
const GRID_ORIGIN: Vector2 = Vector2(300.0, 168.0)
const CELL_SIZE: Vector2 = Vector2(72.0, 72.0)
const GRID_RECT: Rect2 = Rect2(300.0, 168.0, 360.0, 360.0)

var rules: Variant
var level_index: int = 0
var state: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var selected_element: String = "H"
var cursor: Vector2i = Vector2i(2, 2)
var campaign_complete: bool = false

func _ready() -> void:
    var path: String = RULES_PATH
    if not ResourceLoader.exists(path):
        path = "res://rules.gd"
    rules = load(path)
    if rules == null:
        push_error("KROLL Molecule Forge could not load its rules module.")
        set_process(false)
        return
    reset_level()
    queue_redraw()

func get_current_level() -> Dictionary:
    return rules.get_level(level_index)

func get_state() -> Dictionary:
    return state.duplicate(true)

func _select_element(element: String) -> bool:
    if not ELEMENTS.has(element):
        return false
    selected_element = element
    state["selected_element"] = element
    queue_redraw()
    return true

func _move_cursor(delta: Vector2i) -> void:
    cursor = Vector2i(
        clampi(cursor.x + delta.x, 0, 4),
        clampi(cursor.y + delta.y, 0, 4)
    )
    state["cursor"] = cursor
    queue_redraw()

func _place_at(cell: Vector2i) -> bool:
    if rules == null or state.is_empty():
        return false
    var result: Dictionary = rules.place_atom(state, selected_element, cell)
    if not bool(result.get("ok", false)):
        state["status"] = "REJECTED · %s" % str(result.get("reason", "invalid"))
        queue_redraw()
        return false
    undo_stack.append(state.duplicate(true))
    state = result.get("state", state)
    cursor = cell
    state["cursor"] = cursor
    state["selected_element"] = selected_element
    queue_redraw()
    return true

func _remove_at(cell: Vector2i) -> bool:
    if rules == null or state.is_empty():
        return false
    var result: Dictionary = rules.remove_atom(state, cell)
    if not bool(result.get("ok", false)):
        return false
    undo_stack.append(state.duplicate(true))
    state = result.get("state", state)
    queue_redraw()
    return true

func _undo() -> bool:
    if undo_stack.is_empty():
        return false
    state = undo_stack.pop_back()
    selected_element = str(state.get("selected_element", "H"))
    cursor = state.get("cursor", Vector2i(2, 2))
    queue_redraw()
    return true

func reset_level() -> void:
    if rules == null:
        return
    state = rules.new_state(level_index)
    selected_element = "H"
    cursor = Vector2i(2, 2)
    undo_stack.clear()
    campaign_complete = false
    queue_redraw()

func next_level() -> bool:
    if not bool(state.get("complete", false)):
        return false
    if level_index >= rules.LEVEL_COUNT - 1:
        campaign_complete = true
        state["status"] = "ALL THREE MOLECULES VERIFIED"
        queue_redraw()
        return true
    level_index += 1
    reset_level()
    return true

func _element_button_rect(element: String) -> Rect2:
    var index: int = ELEMENTS.find(element)
    if index < 0:
        return Rect2()
    return Rect2(42.0, 208.0 + float(index) * 68.0, 204.0, 52.0)

func _cell_rect(cell: Vector2i) -> Rect2:
    return Rect2(GRID_ORIGIN + Vector2(cell) * CELL_SIZE, CELL_SIZE)

func _action_button_rect(button_id: String) -> Rect2:
    match button_id:
        "undo":
            return Rect2(300.0, 630.0, 110.0, 52.0)
        "reset":
            return Rect2(425.0, 630.0, 110.0, 52.0)
        "next":
            return Rect2(550.0, 630.0, 110.0, 52.0)
    return Rect2()

func _handle_press(position: Vector2) -> void:
    for element in ELEMENTS:
        if _element_button_rect(element).has_point(position):
            _select_element(element)
            return
    if _action_button_rect("undo").has_point(position):
        _undo()
        return
    if _action_button_rect("reset").has_point(position):
        reset_level()
        return
    if _action_button_rect("next").has_point(position):
        next_level()
        return
    if GRID_RECT.has_point(position):
        var cell := Vector2i(
            floori((position.x - GRID_ORIGIN.x) / CELL_SIZE.x),
            floori((position.y - GRID_ORIGIN.y) / CELL_SIZE.y)
        )
        cursor = cell
        _place_at(cell)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if not key_event.pressed or key_event.echo:
            return
        match key_event.keycode:
            KEY_1:
                _select_element("H")
            KEY_2:
                _select_element("O")
            KEY_3:
                _select_element("N")
            KEY_4:
                _select_element("C")
            KEY_LEFT, KEY_A:
                _move_cursor(Vector2i(-1, 0))
            KEY_RIGHT, KEY_D:
                _move_cursor(Vector2i(1, 0))
            KEY_UP, KEY_W:
                _move_cursor(Vector2i(0, -1))
            KEY_DOWN, KEY_S:
                _move_cursor(Vector2i(0, 1))
            KEY_SPACE:
                _place_at(cursor)
            KEY_BACKSPACE, KEY_DELETE:
                _remove_at(cursor)
            KEY_U:
                _undo()
            KEY_R:
                reset_level()
            KEY_N:
                next_level()
    elif event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.pressed:
            if mouse_event.button_index == MOUSE_BUTTON_LEFT:
                _handle_press(mouse_event.position)
            elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and GRID_RECT.has_point(mouse_event.position):
                var remove_cell := Vector2i(
                    floori((mouse_event.position.x - GRID_ORIGIN.x) / CELL_SIZE.x),
                    floori((mouse_event.position.y - GRID_ORIGIN.y) / CELL_SIZE.y)
                )
                _remove_at(remove_cell)
    elif event is InputEventScreenTouch:
        var touch_event := event as InputEventScreenTouch
        if touch_event.pressed:
            _handle_press(touch_event.position)

func _draw() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#07121d"))
    draw_rect(Rect2(Vector2(14.0, 14.0), viewport_size - Vector2(28.0, 28.0)), Color("#0b1c2a"), false, 2.0)
    var level: Dictionary = get_current_level() if rules != null else {}
    var analysis: Dictionary = rules.analyze_atoms(state.get("atoms", [])) if rules != null else {}
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 48.0), "KROLL // MOLECULE FORGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("#72e6ed"))
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 80.0), "ATOM ASSEMBLY LAB  ·  SECTOR %d / %d" % [level_index + 1, rules.LEVEL_COUNT], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8da9bc"))
    draw_string(ThemeDB.fallback_font, Vector2(42.0, 164.0), "ATOM BANK  ·  1–4", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d5e5ef"))
    for element in ELEMENTS:
        _draw_element_button(element)
    for y in range(5):
        for x in range(5):
            var cell := Vector2i(x, y)
            var rect: Rect2 = _cell_rect(cell)
            draw_rect(rect, Color("#10283a"))
            draw_rect(rect, Color("#2b5268"), false, 1.5)
    var atoms: Array = state.get("atoms", [])
    var edges: Array = analysis.get("edges", [])
    for edge_value in edges:
        var edge: Vector2i = edge_value
        var atom_a: Dictionary = atoms[edge.x] as Dictionary
        var atom_b: Dictionary = atoms[edge.y] as Dictionary
        var cell_a: Vector2i = atom_a.get("cell", Vector2i.ZERO)
        var cell_b: Vector2i = atom_b.get("cell", Vector2i.ZERO)
        draw_line(_cell_rect(cell_a).get_center(), _cell_rect(cell_b).get_center(), Color("#f1d78b"), 8.0, true)
    for atom_value in atoms:
        var atom: Dictionary = atom_value as Dictionary
        var element: String = str(atom.get("element", ""))
        var cell: Vector2i = atom.get("cell", Vector2i.ZERO)
        var center: Vector2 = _cell_rect(cell).get_center()
        draw_circle(center, 25.0, rules.get_element_color(element))
        draw_arc(center, 25.0, 0.0, TAU, 36, Color("#f2f7fa"), 2.0)
        var text_color: Color = Color("#15212b") if element == "H" or element == "O" else Color("#f5f8fb")
        draw_string(ThemeDB.fallback_font, center + Vector2(-9.0, 7.0), element, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, text_color)
    draw_rect(_cell_rect(cursor).grow(-3.0), Color("#8de9f0"), false, 3.0)
    var formula_text: String = str(level.get("formula_text", ""))
    var bond_count: int = edges.size()
    var atom_count: int = atoms.size()
    draw_string(ThemeDB.fallback_font, Vector2(704.0, 192.0), "TARGET MOLECULE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#91aebf"))
    draw_string(ThemeDB.fallback_font, Vector2(704.0, 234.0), formula_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#f4d88b"))
    draw_string(ThemeDB.fallback_font, Vector2(704.0, 270.0), str(level.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#e4eef4"))
    draw_string(ThemeDB.fallback_font, Vector2(704.0, 312.0), "ATOMS  %d / %d" % [atom_count, _target_atom_count(level)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8d0df"))
    draw_string(ThemeDB.fallback_font, Vector2(704.0, 340.0), "BONDS  %d / %d" % [bond_count, int(level.get("target_bonds", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8d0df"))
    draw_string(ThemeDB.fallback_font, Vector2(704.0, 368.0), "MOVES  %d" % int(state.get("moves", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8d0df"))
    var brief: String = str(level.get("brief", ""))
    draw_multiline_string(ThemeDB.fallback_font, Vector2(704.0, 414.0), brief, HORIZONTAL_ALIGNMENT_LEFT, 210.0, 13, HORIZONTAL_ALIGNMENT_LEFT, Color("#8da9bc"))
    var status_color: Color = Color("#f1d78b")
    if bool(state.get("complete", false)):
        status_color = Color("#83e6a8")
    elif str(state.get("status", "")).begins_with("REJECTED"):
        status_color = Color("#f28a82")
    draw_string(ThemeDB.fallback_font, Vector2(42.0, 604.0), str(state.get("status", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, status_color)
    draw_string(ThemeDB.fallback_font, Vector2(42.0, 623.0), "ARROWS: CURSOR · 1–4: ELEMENT · SPACE: PLACE · BACKSPACE: REMOVE · U: UNDO · R: RESET · N: NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#7797aa"))
    _draw_action_button("undo", "UNDO", undo_stack.is_empty())
    _draw_action_button("reset", "RESET", false)
    _draw_action_button("next", "NEXT", not bool(state.get("complete", false)))

func _draw_element_button(element: String) -> void:
    var rect: Rect2 = _element_button_rect(element)
    var selected: bool = selected_element == element
    draw_rect(rect, Color("#1d4656") if selected else Color("#102b3c"))
    draw_rect(rect, Color("#8de9f0") if selected else Color("#345a6c"), false, 2.0)
    draw_circle(rect.position + Vector2(25.0, 26.0), 14.0, rules.get_element_color(element))
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(52.0, 34.0), "%s  VALENCE %d" % [element, rules.get_valence(element)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e2eef4"))

func _draw_action_button(button_id: String, label: String, disabled: bool) -> void:
    var rect: Rect2 = _action_button_rect(button_id)
    draw_rect(rect, Color("#123b49") if not disabled else Color("#111f2b"))
    draw_rect(rect, Color("#67d7df") if not disabled else Color("#354653"), false, 2.0)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(20.0, 33.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e4f4f8") if not disabled else Color("#738391"))

func _target_atom_count(level: Dictionary) -> int:
    var formula: Dictionary = level.get("formula", {})
    var total: int = 0
    for value in formula.values():
        total += int(value)
    return total
