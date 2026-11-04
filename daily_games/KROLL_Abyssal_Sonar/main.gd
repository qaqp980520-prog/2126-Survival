extends Node2D

const Rules = preload("res://rules.gd")

const GRID_ORIGIN: Vector2 = Vector2(28.0, 156.0)
const CELL_SIZE: float = 48.0

var _state: Dictionary = {}
var _message: String = "Sweep the trench with SONAR. Follow the bearing and return the beacon to the submersible."
var _touch_pressed: String = ""

func _ready() -> void:
    _state = Rules.new_state()
    queue_redraw()

func get_game_state() -> Dictionary:
    return _state.duplicate(true)

func apply_action(action: String) -> bool:
    var accepted: bool = false
    match action:
        "move_up", "move_right", "move_down", "move_left":
            var direction: String = action.trim_prefix("move_")
            var result: Dictionary = Rules.move(_state, direction)
            _state = result["state"]
            accepted = bool(result["accepted"])
            _message = _message_for_reason(str(result["reason"]))
        "ping":
            var ping_result: Dictionary = Rules.ping(_state)
            _state = ping_result["state"]
            accepted = bool(ping_result["accepted"])
            _message = _message_for_reason(str(ping_result["reason"]))
            if accepted:
                var clue: Dictionary = ping_result["clue"]
                _message = "ECHO %s / %s. Use another position to narrow the beacon." % [str(clue["band"]), str(clue["bearing"])]
        "interact":
            var interact_result: Dictionary = Rules.interact(_state)
            _state = interact_result["state"]
            accepted = bool(interact_result["accepted"])
            _message = _message_for_reason(str(interact_result["reason"]))
        "restart":
            _state = Rules.restart_mission(_state)
            _message = "MISSION RESET. Previously recovered mission rewards remain recorded."
            accepted = true
        "next":
            var next_result: Dictionary = Rules.next_mission(_state)
            _state = next_result["state"]
            accepted = bool(next_result["accepted"])
            _message = _message_for_reason(str(next_result["reason"]))
        "campaign":
            _state = Rules.restart_campaign()
            _message = "NEW SONAR CAMPAIGN INITIALIZED."
            accepted = true
        _:
            _message = "UNKNOWN CONTROL."
    queue_redraw()
    return accepted

func touch_action_at(position: Vector2) -> String:
    if Rect2(690.0, 300.0, 70.0, 48.0).has_point(position):
        return "move_up"
    if Rect2(610.0, 355.0, 70.0, 48.0).has_point(position):
        return "move_left"
    if Rect2(690.0, 355.0, 70.0, 48.0).has_point(position):
        return "move_down"
    if Rect2(770.0, 355.0, 70.0, 48.0).has_point(position):
        return "move_right"
    if Rect2(610.0, 430.0, 110.0, 48.0).has_point(position):
        return "ping"
    if Rect2(730.0, 430.0, 120.0, 48.0).has_point(position):
        return "interact"
    if Rect2(610.0, 495.0, 110.0, 42.0).has_point(position):
        return "restart"
    if Rect2(730.0, 495.0, 120.0, 42.0).has_point(position):
        return "next"
    if Rect2(610.0, 550.0, 240.0, 42.0).has_point(position):
        return "campaign"
    return ""

func _message_for_reason(reason: String) -> String:
    match reason:
        "moved":
            return "MOVE COMPLETE. Battery draw: 1 unit."
        "blocked":
            return "SOLID ROCK. Choose another passage."
        "battery_depleted":
            return "BATTERY DEPLETED. Restart this mission."
        "echo_received":
            return "SONAR ECHO RECEIVED."
        "no_pings_left":
            return "NO SONAR PINGS LEFT. Navigate using the saved echo log."
        "insufficient_battery":
            return "INSUFFICIENT BATTERY FOR SONAR."
        "beacon_not_here":
            return "NO BEACON AT THIS CELL. Follow the echo."
        "beacon_secured":
            return "BEACON SECURED. Return to the SUB tile and extract."
        "return_to_sub":
            return "BEACON SECURED. Return to the SUB tile to extract."
        "mission_complete":
            return "BEACON EXTRACTED. Press NEXT for the next trench."
        "mission_not_complete":
            return "RECOVER THE BEACON AND RETURN TO THE SUB FIRST."
        "next_mission":
            return "NEXT TRENCH LOADED. New beacon signature detected."
        "campaign_complete":
            return "CAMPAIGN COMPLETE. All three abyssal beacons recovered."
        "mission_not_active":
            return "MISSION INACTIVE. Restart or advance the campaign."
        "invalid_direction":
            return "INVALID MOVEMENT."
        _:
            return "SONAR SYSTEM READY."

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_W, KEY_UP:
            apply_action("move_up")
        KEY_D, KEY_RIGHT:
            apply_action("move_right")
        KEY_S, KEY_DOWN:
            apply_action("move_down")
        KEY_A, KEY_LEFT:
            apply_action("move_left")
        KEY_SPACE:
            apply_action("ping")
        KEY_E:
            apply_action("interact")
        KEY_R:
            apply_action("restart")
        KEY_N:
            apply_action("next")
        KEY_C:
            apply_action("campaign")

func _input(event: InputEvent) -> void:
    var action: String = ""
    var pressed: bool = false
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if mouse_event.button_index != MOUSE_BUTTON_LEFT:
            return
        action = touch_action_at(mouse_event.position)
        pressed = mouse_event.pressed
    elif event is InputEventScreenTouch:
        var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
        action = touch_action_at(touch_event.position)
        pressed = touch_event.pressed
    if not action.is_empty() and pressed:
        apply_action(action)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(1120.0, 720.0)), Color(0.012, 0.025, 0.052), true)
    for index in range(48):
        var x: float = float((index * 173) % 1090) + 8.0
        var y: float = float((index * 97) % 690) + 8.0
        draw_circle(Vector2(x, y), 1.2, Color(0.18, 0.38, 0.54, 0.55))

    var mission_index: int = int(_state.get("mission_index", 0))
    var mission: Dictionary = Rules.mission_at(mission_index)
    draw_string(ThemeDB.fallback_font, Vector2(28.0, 38.0), "KROLL  /  ABYSSAL SONAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.44, 0.88, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(28.0, 66.0), "BEACON TRIANGULATION  •  BATTERY MANAGEMENT  •  DEEP-TRENCH EXTRACTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.58, 0.75, 0.88))
    draw_string(ThemeDB.fallback_font, Vector2(28.0, 105.0), "MISSION %d / %d   %s" % [mission_index + 1, Rules.mission_count(), str(mission["name"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.78, 0.4))
    draw_string(ThemeDB.fallback_font, Vector2(28.0, 128.0), "BATTERY %d / %d    PINGS %d    MOVES %d    SCORE %d / 300" % [int(_state["battery"]), int(_state["battery_limit"]), int(_state["pings_left"]), int(_state["moves"]), int(_state["campaign_score"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.92, 0.82))

    var walls: Array = _state["walls"]
    var start: Vector2i = _state["start"]
    var player: Vector2i = _state["player"]
    for y in range(Rules.GRID_SIZE):
        for x in range(Rules.GRID_SIZE):
            var cell := Vector2i(x, y)
            var rect := Rect2(GRID_ORIGIN + Vector2(float(x) * CELL_SIZE, float(y) * CELL_SIZE), Vector2(CELL_SIZE - 2.0, CELL_SIZE - 2.0))
            draw_rect(rect, Color(0.035, 0.11, 0.16), true)
            draw_rect(rect, Color(0.12, 0.3, 0.38), false, 1.0)
            if walls.has(cell):
                draw_rect(rect, Color(0.16, 0.23, 0.3), true)
                draw_line(rect.position + Vector2(7.0, 7.0), rect.position + rect.size - Vector2(7.0, 7.0), Color(0.29, 0.4, 0.48), 2.0)
                draw_line(rect.position + Vector2(rect.size.x - 7.0, 7.0), rect.position + Vector2(7.0, rect.size.y - 7.0), Color(0.29, 0.4, 0.48), 2.0)
            if cell == start:
                draw_rect(rect.grow(-5.0), Color(0.12, 0.45, 0.36), true)
                draw_string(ThemeDB.fallback_font, rect.position + Vector2(10.0, 29.0), "SUB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 1.0, 0.9))
            if cell == player:
                draw_circle(rect.get_center(), 13.0, Color(0.32, 0.86, 1.0))
                draw_circle(rect.get_center(), 5.0, Color(0.02, 0.14, 0.22))
                if bool(_state["carrying"]):
                    draw_circle(rect.get_center() + Vector2(13.0, -13.0), 5.0, Color(1.0, 0.68, 0.28))

    draw_string(ThemeDB.fallback_font, Vector2(520.0, 180.0), "SONAR CONTACT LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.46, 0.88, 1.0))
    var log: Array = _state["ping_log"]
    if log.is_empty():
        draw_string(ThemeDB.fallback_font, Vector2(520.0, 212.0), "No echoes recorded. Press SPACE / PING.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.58, 0.72, 0.82))
    else:
        for i in range(log.size()):
            var clue: Dictionary = log[i]
            var row_y: float = 214.0 + float(i) * 27.0
            draw_string(ThemeDB.fallback_font, Vector2(520.0, row_y), "PING %d   %s   /   %s" % [int(clue["ping_number"]), str(clue["band"]), str(clue["bearing"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.91, 0.95))

    var carrying_text: String = "BEACON SECURED" if bool(_state["carrying"]) else "BEACON HIDDEN"
    draw_string(ThemeDB.fallback_font, Vector2(520.0, 284.0), carrying_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.78, 0.4))
    draw_string(ThemeDB.fallback_font, Vector2(520.0, 620.0), _message, HORIZONTAL_ALIGNMENT_LEFT, 570, 13, Color(0.82, 0.9, 0.95))
    draw_string(ThemeDB.fallback_font, Vector2(520.0, 655.0), "WASD / ARROWS: MOVE    SPACE: SONAR    E: INTERACT    R: RESET    N: NEXT    C: CAMPAIGN", HORIZONTAL_ALIGNMENT_LEFT, 570, 11, Color(0.48, 0.65, 0.77))

    _draw_button(Rect2(690.0, 300.0, 70.0, 48.0), "UP", _touch_pressed == "move_up")
    _draw_button(Rect2(610.0, 355.0, 70.0, 48.0), "LEFT", _touch_pressed == "move_left")
    _draw_button(Rect2(690.0, 355.0, 70.0, 48.0), "DOWN", _touch_pressed == "move_down")
    _draw_button(Rect2(770.0, 355.0, 70.0, 48.0), "RIGHT", _touch_pressed == "move_right")
    _draw_button(Rect2(610.0, 430.0, 110.0, 48.0), "PING", false)
    _draw_button(Rect2(730.0, 430.0, 120.0, 48.0), "INTERACT", false)
    _draw_button(Rect2(610.0, 495.0, 110.0, 42.0), "RESTART", false)
    _draw_button(Rect2(730.0, 495.0, 120.0, 42.0), "NEXT", false)
    _draw_button(Rect2(610.0, 550.0, 240.0, 42.0), "NEW CAMPAIGN", false)

func _draw_button(rect: Rect2, label: String, active: bool) -> void:
    var fill: Color = Color(0.1, 0.35, 0.46) if active else Color(0.055, 0.16, 0.23)
    draw_rect(rect, fill, true)
    draw_rect(rect, Color(0.24, 0.62, 0.72), false, 1.5)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(10.0, rect.size.y * 0.66), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 13, Color(0.8, 0.94, 1.0))
