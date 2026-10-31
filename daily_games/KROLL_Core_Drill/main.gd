extends Node2D

const MISSION_COUNT: int = 3
const GRID_ORIGIN: Vector2 = Vector2(210.0, 158.0)
const CELL_SIZE: Vector2 = Vector2(108.0, 54.0)
const GRID_RECT: Rect2 = Rect2(210.0, 158.0, 540.0, 432.0)

var rules: Variant
var mission_index: int = 0
var state: Dictionary = {}
var selected_lane: int = 2
var campaign_complete: bool = false
var status_text: String = "SELECT A SAFE LANE, THEN DRILL DOWN"

func _ready() -> void:
    var rules_path: String = "res://rules.gd"
    if not ResourceLoader.exists(rules_path):
        rules_path = "res://daily_games/KROLL_Core_Drill/rules.gd"
    rules = load(rules_path)
    if rules == null:
        push_error("KROLL Core Drill could not load its rules module.")
        set_process(false)
        return
    restart_sector()
    queue_redraw()

func get_current_mission() -> Dictionary:
    return rules.get_mission(mission_index)

func get_state() -> Dictionary:
    return state.duplicate(true)

func _set_selected_lane(value: int) -> void:
    if state.is_empty():
        return
    var current_lane: int = int(state.get("lane", 2))
    selected_lane = clampi(value, maxi(0, current_lane - 1), mini(4, current_lane + 1))
    queue_redraw()

func _drill_selected() -> bool:
    if rules == null or state.is_empty():
        return false
    var result: Dictionary = rules.apply_drill(state, selected_lane)
    state = result.get("state", state)
    selected_lane = int(state.get("lane", selected_lane))
    status_text = str(state.get("status", result.get("reason", "DRILL ACTION FAILED")))
    if bool(state.get("complete", false)) and mission_index == MISSION_COUNT - 1:
        campaign_complete = true
    queue_redraw()
    return bool(result.get("ok", false))

func _vent() -> bool:
    if rules == null or state.is_empty():
        return false
    var result: Dictionary = rules.vent(state)
    state = result.get("state", state)
    status_text = str(state.get("status", result.get("reason", "VENT FAILED")))
    queue_redraw()
    return bool(result.get("ok", false))

func restart_sector() -> void:
    if rules == null:
        return
    state = rules.new_state(mission_index)
    selected_lane = int(state.get("lane", 2))
    campaign_complete = false
    status_text = str(state.get("status", "READY"))
    queue_redraw()

func next_sector() -> bool:
    if not bool(state.get("complete", false)):
        return false
    if mission_index >= MISSION_COUNT - 1:
        campaign_complete = true
        status_text = "ALL THREE CORE SAMPLES SECURED"
        queue_redraw()
        return true
    mission_index += 1
    restart_sector()
    return true

func _button_rect(button_id: String) -> Rect2:
    const BUTTON_Y: float = 645.0
    match button_id:
        "left":
            return Rect2(44.0, BUTTON_Y, 100.0, 54.0)
        "right":
            return Rect2(154.0, BUTTON_Y, 100.0, 54.0)
        "vent":
            return Rect2(264.0, BUTTON_Y, 100.0, 54.0)
        "drill":
            return Rect2(374.0, BUTTON_Y, 120.0, 54.0)
        "restart":
            return Rect2(504.0, BUTTON_Y, 120.0, 54.0)
        "next":
            return Rect2(634.0, BUTTON_Y, 120.0, 54.0)
    return Rect2()

func _handle_press(position: Vector2) -> void:
    if _button_rect("left").has_point(position):
        _set_selected_lane(selected_lane - 1)
    elif _button_rect("right").has_point(position):
        _set_selected_lane(selected_lane + 1)
    elif _button_rect("vent").has_point(position):
        _vent()
    elif _button_rect("drill").has_point(position):
        _drill_selected()
    elif _button_rect("restart").has_point(position):
        restart_sector()
    elif _button_rect("next").has_point(position):
        next_sector()
    elif GRID_RECT.has_point(position):
        var lane: int = int(floor((position.x - GRID_ORIGIN.x) / CELL_SIZE.x))
        _set_selected_lane(lane)
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if not key_event.pressed or key_event.echo:
            return
        match key_event.keycode:
            KEY_A, KEY_LEFT:
                _set_selected_lane(selected_lane - 1)
            KEY_D, KEY_RIGHT:
                _set_selected_lane(selected_lane + 1)
            KEY_SPACE:
                _drill_selected()
            KEY_V:
                _vent()
            KEY_R:
                restart_sector()
            KEY_N:
                next_sector()
    elif event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
            _handle_press(mouse_event.position)
    elif event is InputEventScreenTouch:
        var touch_event := event as InputEventScreenTouch
        if touch_event.pressed:
            _handle_press(touch_event.position)
    elif event is InputEventScreenDrag:
        var drag_event := event as InputEventScreenDrag
        if GRID_RECT.has_point(drag_event.position):
            var lane: int = int(floor((drag_event.position.x - GRID_ORIGIN.x) / CELL_SIZE.x))
            _set_selected_lane(lane)

func _draw() -> void:
    var size: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.022, 0.035))
    draw_rect(Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0)), Color(0.025, 0.048, 0.066), false, 2.0)
    var mission: Dictionary = get_current_mission() if rules != null else {}
    var quota: int = int(mission.get("quota", 0))
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 46.0), "KROLL // CORE DRILL", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.48, 0.91, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 76.0), str(mission.get("name", "INITIALIZING")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.94, 0.97, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 101.0), str(mission.get("region", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.72, 0.82))
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 130.0), "SITE %d / %d   DEPTH %d / %d   ORE %d / %d" % [mission_index + 1, MISSION_COUNT, int(state.get("row", 0)), rules.ROW_COUNT if rules != null else 8, int(state.get("ore", 0)), quota], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.88, 0.95))
    _draw_resource_bar(Vector2(590.0, 38.0), "ENERGY", int(state.get("energy", 0)), 28, Color(0.30, 0.78, 0.93))
    _draw_resource_bar(Vector2(590.0, 78.0), "HEAT", int(state.get("heat", 0)), 100, Color(1.0, 0.47, 0.24))
    _draw_resource_bar(Vector2(590.0, 118.0), "HULL", int(state.get("hull", 0)), 5, Color(0.40, 0.86, 0.62))
    var layout: Array = mission.get("layout", [])
    var mined_cells: Array = state.get("mined_cells", [])
    for row in range(8):
        for lane in range(5):
            var cell_rect := Rect2(GRID_ORIGIN + Vector2(float(lane) * CELL_SIZE.x, float(row) * CELL_SIZE.y), CELL_SIZE - Vector2(4.0, 4.0))
            var tile: String = rules.get_cell(mission, row, lane)
            var info: Dictionary = rules.get_tile_info(tile)
            var fill: Color = info.get("color", Color(0.2, 0.25, 0.3))
            if row < int(state.get("row", 0)):
                fill = fill.lightened(0.16)
            draw_rect(cell_rect, fill)
            draw_rect(cell_rect, Color(0.72, 0.86, 0.92, 0.55), false, 1.0)
            var label: String = str(info.get("label", tile))
            draw_string(ThemeDB.fallback_font, cell_rect.position + Vector2(8.0, 31.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 0.98, 1.0))
            if mined_cells.has(Vector2i(row, lane)):
                draw_string(ThemeDB.fallback_font, cell_rect.position + Vector2(78.0, 30.0), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.78, 1.0, 0.82))
    var lane_rect := Rect2(GRID_ORIGIN + Vector2(float(selected_lane) * CELL_SIZE.x, 0.0), Vector2(CELL_SIZE.x - 4.0, CELL_SIZE.y * 8.0 - 4.0))
    draw_rect(lane_rect, Color(0.20, 0.84, 0.94, 0.09))
    draw_rect(lane_rect, Color(0.40, 0.92, 1.0, 0.88), false, 2.0)
    var current_row: int = int(state.get("row", 0))
    if current_row < 8 and not bool(state.get("failed", false)) and not bool(state.get("complete", false)):
        var drill_center := GRID_ORIGIN + Vector2((float(selected_lane) + 0.5) * CELL_SIZE.x, (float(current_row) + 0.5) * CELL_SIZE.y)
        draw_circle(drill_center, 10.0, Color(0.98, 0.82, 0.38))
        draw_arc(drill_center, 17.0, 0.0, TAU, 24, Color(1.0, 0.88, 0.56), 2.0)
    var status_color: Color = Color(0.94, 0.78, 0.42)
    if bool(state.get("failed", false)):
        status_color = Color(1.0, 0.42, 0.35)
    elif bool(state.get("complete", false)):
        status_color = Color(0.42, 0.94, 0.68)
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 614.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, status_color)
    draw_string(ThemeDB.fallback_font, Vector2(34.0, 632.0), "A/D OR ARROWS: LANE · SPACE: DRILL · V: VENT · R: RETRY · N: NEXT SITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.56, 0.72, 0.82))
    _draw_button("left", "LEFT", false)
    _draw_button("right", "RIGHT", false)
    _draw_button("vent", "VENT", false)
    _draw_button("drill", "DRILL", false)
    _draw_button("restart", "RESTART", false)
    _draw_button("next", "NEXT", not bool(state.get("complete", false)))

func _draw_resource_bar(position: Vector2, label: String, value: int, maximum: int, color: Color) -> void:
    var ratio: float = clampf(float(value) / float(maximum), 0.0, 1.0) if maximum > 0 else 0.0
    draw_string(ThemeDB.fallback_font, position, "%s %d / %d" % [label, value, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.91, 0.96))
    var bar_rect := Rect2(position + Vector2(0.0, 8.0), Vector2(300.0, 9.0))
    draw_rect(bar_rect, Color(0.08, 0.13, 0.17))
    draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), color)

func _draw_button(button_id: String, label: String, disabled: bool) -> void:
    var rect: Rect2 = _button_rect(button_id)
    var fill: Color = Color(0.05, 0.20, 0.27) if not disabled else Color(0.08, 0.11, 0.14)
    var outline: Color = Color(0.32, 0.80, 0.88) if not disabled else Color(0.24, 0.31, 0.35)
    var text_color: Color = Color(0.84, 0.96, 1.0) if not disabled else Color(0.43, 0.52, 0.57)
    draw_rect(rect, fill)
    draw_rect(rect, outline, false, 2.0)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 34.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_color)
