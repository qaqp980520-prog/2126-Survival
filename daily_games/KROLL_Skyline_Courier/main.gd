extends Control

const Rules = preload("res://rules.gd")
const ROAD_TOP := 74.0
const PLAYER_Y_OFFSET := 150.0
const VISIBLE_DISTANCE := 38.0

var state: Dictionary = {}
var seed_value: int = 11
var _buttons: Array[Button] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    state = Rules.new_game(seed_value)
    _build_controls()
    queue_redraw()

func _process(delta: float) -> void:
    if str(state.get("status", "")) != "playing":
        return
    var result: Dictionary = Rules.advance(state, clampf(delta, 0.001, Rules.MAX_FRAME_DELTA))
    if bool(result.get("ok", false)):
        state = result["state"]
        _sync_controls()
        queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_A, KEY_LEFT:
            move_lane(-1)
        KEY_D, KEY_RIGHT:
            move_lane(1)
        KEY_R:
            restart_game()
        KEY_N:
            next_route()

func _build_controls() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    _add_button("LEFT", Vector2(24.0, viewport_size.y - 58.0), Vector2(112.0, 42.0), func(): select_lane(0))
    _add_button("CENTER", Vector2(144.0, viewport_size.y - 58.0), Vector2(112.0, 42.0), func(): select_lane(1))
    _add_button("RIGHT", Vector2(264.0, viewport_size.y - 58.0), Vector2(112.0, 42.0), func(): select_lane(2))
    _add_button("RESET", Vector2(viewport_size.x - 224.0, viewport_size.y - 58.0), Vector2(92.0, 42.0), restart_game)
    _add_button("NEXT", Vector2(viewport_size.x - 124.0, viewport_size.y - 58.0), Vector2(100.0, 42.0), next_route)

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

func move_lane(direction: int) -> void:
    var result: Dictionary = Rules.move_lane(state, direction)
    if bool(result.get("ok", false)):
        state = result["state"]
        queue_redraw()

func select_lane(lane: int) -> void:
    var result: Dictionary = Rules.select_lane(state, lane)
    if bool(result.get("ok", false)):
        state = result["state"]
        queue_redraw()

func restart_game() -> void:
    state = Rules.new_game(seed_value)
    _sync_controls()
    queue_redraw()

func next_route() -> void:
    seed_value += 1
    restart_game()

func _sync_controls() -> void:
    var terminal: bool = str(state.get("status", "")) != "playing"
    for button in _buttons:
        if button.name != "ResetButton" and button.name != "NextButton":
            button.disabled = terminal

func _lane_x(lane: int) -> float:
    var road_left: float = size.x * 0.22
    var lane_width: float = size.x * 0.56 / 3.0
    return road_left + lane_width * (float(lane) + 0.5)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#07111e"), true)
    var road_left: float = size.x * 0.22
    var road_width: float = size.x * 0.56
    draw_rect(Rect2(road_left, ROAD_TOP, road_width, size.y - ROAD_TOP - 90.0), Color("#102536"), true)
    draw_rect(Rect2(road_left, ROAD_TOP, road_width, size.y - ROAD_TOP - 90.0), Color("#3b6b7a"), false, 3.0)
    for divider_index in range(1, Rules.LANE_COUNT):
        var x: float = road_left + road_width * float(divider_index) / 3.0
        draw_line(Vector2(x, ROAD_TOP), Vector2(x, size.y - 90.0), Color(0.35, 0.65, 0.72, 0.45), 2.0)
    for stripe_index in range(8):
        var stripe_y: float = fmod(float(stripe_index) * 88.0 + float(state.get("distance", 0.0)) * 8.0, size.y - ROAD_TOP - 90.0) + ROAD_TOP
        draw_line(Vector2(road_left + 12.0, stripe_y), Vector2(road_left + road_width - 12.0, stripe_y), Color(0.2, 0.36, 0.43, 0.35), 1.0)

    var items: Array = state.get("items", [])
    var current_distance: float = float(state.get("distance", 0.0))
    var player_y: float = size.y - PLAYER_Y_OFFSET
    for index in range(int(state.get("next_item", 0)), items.size()):
        var item: Dictionary = items[index]
        var distance_ahead: float = float(item.get("distance", 0.0)) - current_distance
        if distance_ahead < 0.0 or distance_ahead > VISIBLE_DISTANCE:
            continue
        var item_y: float = player_y - distance_ahead * 8.0
        var item_x: float = _lane_x(int(item.get("lane", 1)))
        if str(item.get("kind", "")) == "hazard":
            var triangle := PackedVector2Array([
                Vector2(item_x, item_y - 20.0),
                Vector2(item_x - 24.0, item_y + 18.0),
                Vector2(item_x + 24.0, item_y + 18.0)
            ])
            draw_colored_polygon(triangle, Color("#f0645a"))
            draw_string(ThemeDB.fallback_font, Vector2(item_x - 10.0, item_y + 6.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#ffffff"))
        else:
            draw_circle(Vector2(item_x, item_y), 17.0, Color("#58e6cf"))
            draw_circle(Vector2(item_x, item_y), 9.0, Color("#eafffb"))
            draw_string(ThemeDB.fallback_font, Vector2(item_x - 6.0, item_y + 5.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#07524e"))

    var player_x: float = _lane_x(int(state.get("lane", 1)))
    var player := PackedVector2Array([
        Vector2(player_x, player_y - 22.0),
        Vector2(player_x - 19.0, player_y + 20.0),
        Vector2(player_x + 19.0, player_y + 20.0)
    ])
    draw_colored_polygon(player, Color("#6dd7ff"))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 34.0), "KROLL // SKYLINE COURIER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color("#9af6e8"))
    draw_string(ThemeDB.fallback_font, Vector2(24.0, 58.0), "DIST %05.1f  PACKETS %d/%d  LIVES %d  TIME %04.1f" % [current_distance, int(state.get("packets", 0)), Rules.TARGET_PACKETS, int(state.get("lives", 0)), float(state.get("time_left", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#f1c66b"))
    draw_string(ThemeDB.fallback_font, Vector2(road_left, size.y - 72.0), str(state.get("message", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#dcecf1"))
    if str(state.get("status", "")) != "playing":
        draw_rect(Rect2(size.x * 0.19, size.y * 0.38, size.x * 0.62, 100.0), Color(0.02, 0.06, 0.1, 0.95))
        draw_rect(Rect2(size.x * 0.19, size.y * 0.38, size.x * 0.62, 100.0), Color("#6dd7ff"), false, 2.0)
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.25, size.y * 0.46), str(state.get("status", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color("#ffffff"))
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.25, size.y * 0.51), "R RESET   N NEXT ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#9af6e8"))
