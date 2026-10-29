extends Control

const Rules = preload("res://rules.gd")
const CELL_SIZE := 52.0
const GRID_PIXELS := CELL_SIZE * Rules.GRID_SIZE

var seed_value: int = 11
var state: Dictionary = {}
var _buttons: Array[Button] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    state = Rules.new_game(seed_value)
    _build_controls()
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_W, KEY_UP:
            move_player(0, -1)
        KEY_S, KEY_DOWN:
            move_player(0, 1)
        KEY_A, KEY_LEFT:
            move_player(-1, 0)
        KEY_D, KEY_RIGHT:
            move_player(1, 0)
        KEY_P:
            ping_sonar()
        KEY_R:
            restart_game()
        KEY_N:
            next_layout()

func _build_controls() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var center_x: float = viewport_size.x * 0.5
    var controls_y: float = viewport_size.y - 170.0
    _add_button("UP", Vector2(center_x - 56.0, controls_y), Vector2(112.0, 40.0), func(): move_player(0, -1))
    _add_button("LEFT", Vector2(center_x - 180.0, controls_y + 44.0), Vector2(112.0, 40.0), func(): move_player(-1, 0))
    _add_button("DOWN", Vector2(center_x - 56.0, controls_y + 44.0), Vector2(112.0, 40.0), func(): move_player(0, 1))
    _add_button("RIGHT", Vector2(center_x + 68.0, controls_y + 44.0), Vector2(112.0, 40.0), func(): move_player(1, 0))
    _add_button("PING", Vector2(center_x - 180.0, controls_y + 92.0), Vector2(112.0, 40.0), ping_sonar)
    _add_button("RESET", Vector2(center_x - 56.0, controls_y + 92.0), Vector2(112.0, 40.0), restart_game)
    _add_button("NEXT", Vector2(center_x + 68.0, controls_y + 92.0), Vector2(112.0, 40.0), next_layout)

func _add_button(label: String, position_value: Vector2, size_value: Vector2, callback: Callable) -> void:
    var button := Button.new()
    button.name = label.capitalize() + "Button"
    button.text = label
    button.position = position_value
    button.size = size_value
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(callback)
    add_child(button)
    _buttons.append(button)

func move_player(dx: int, dy: int) -> void:
    _apply_result(Rules.move(state, dx, dy))

func ping_sonar() -> void:
    _apply_result(Rules.ping(state))

func restart_game() -> void:
    state = Rules.new_game(seed_value)
    _sync_controls()
    queue_redraw()

func next_layout() -> void:
    seed_value = Rules.next_seed(seed_value)
    restart_game()

func _apply_result(result: Dictionary) -> void:
    if bool(result.get("ok", false)):
        state = result["state"]
        _sync_controls()
        queue_redraw()

func _sync_controls() -> void:
    var terminal: bool = str(state.get("status", "")) != "playing"
    for button in _buttons:
        if button.name not in ["ResetButton", "NextButton"]:
            button.disabled = terminal
    var ping_button: Button = get_node_or_null("PingButton") as Button
    if ping_button != null and not terminal:
        ping_button.disabled = int(state.get("battery", 0)) < Rules.PING_BATTERY_COST

func _grid_origin() -> Vector2:
    return Vector2((size.x - GRID_PIXELS) * 0.5, 104.0)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#07111e"), true)
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 36.0), "KROLL // ECHO SURVEY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color("#8ce9f5"))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 66.0), "Ping to map hidden sectors · recover 3 caches · return to S", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#9fb8c8"))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 92.0), "BATTERY %02d    OXYGEN %02d    CACHES %d/%d    MOVES %d" % [int(state.get("battery", 0)), int(state.get("oxygen", 0)), int(state.get("caches_found", 0)), Rules.TARGET_CACHES, int(state.get("moves", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color("#e6f6ff"))
    var origin: Vector2 = _grid_origin()
    for y in range(Rules.GRID_SIZE):
        for x in range(Rules.GRID_SIZE):
            var rect := Rect2(origin + Vector2(float(x), float(y)) * CELL_SIZE, Vector2(CELL_SIZE - 2.0, CELL_SIZE - 2.0))
            var tile: String = Rules.display_tile(state, x, y)
            var fill := Color("#101f30")
            var ink := Color("#52697b")
            match tile:
                "?":
                    fill = Color("#0b1523")
                    ink = Color("#40576a")
                "#":
                    fill = Color("#394a59")
                    ink = Color("#d2dde6")
                "S":
                    fill = Color("#174e50")
                    ink = Color("#9bfff1")
                "C":
                    fill = Color("#17415a")
                    ink = Color("#76e8ff")
                "✓":
                    fill = Color("#1f403d")
                    ink = Color("#a6f4cf")
                ".":
                    fill = Color("#102536")
                    ink = Color("#7894a6")
            draw_rect(rect, fill, true)
            draw_rect(rect, Color("#294354"), false, 1.0)
            if tile != "." and tile != "?":
                draw_string(ThemeDB.fallback_font, rect.position + Vector2(17.0, 33.0), tile, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, ink)
    var player_cell := Rect2(origin + Vector2(float(state.get("x", 0)), float(state.get("y", 0))) * CELL_SIZE + Vector2(14.0, 14.0), Vector2(22.0, 22.0))
    draw_circle(player_cell.position + player_cell.size * 0.5, 10.0, Color("#ffd36a"))
    draw_circle(player_cell.position + player_cell.size * 0.5, 4.0, Color("#6b4a11"))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, size.y - 28.0), str(state.get("message", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 48.0, 16, Color("#bcecf5"))
