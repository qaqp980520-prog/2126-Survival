extends Control

const Rules = preload("res://rules.gd")
const BLOCK_HEIGHT := 34.0
const BASE_Y_OFFSET := 116.0

var state: Dictionary = {}
var seed_value: int = 7
var _move_direction: int = 0
var _buttons: Array[Button] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    state = Rules.new_game(seed_value)
    _build_controls()
    queue_redraw()

func _process(delta: float) -> void:
    if str(state.get("status", "")) != "playing":
        return
    var direction := 0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction = -1
    elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction = 1
    if direction != 0:
        var result: Dictionary = Rules.move_hook(state, direction, 260.0 * delta)
        if bool(result.get("ok", false)):
            state = result["state"]
            queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_SPACE:
            drop_load()
        KEY_R:
            restart_game()
        KEY_N:
            next_manifest()

func _build_controls() -> void:
    _add_button("LEFT", Vector2(22, 570), Vector2(86, 46), _nudge_left)
    _add_button("RIGHT", Vector2(116, 570), Vector2(86, 46), _nudge_right)
    _add_button("DROP", Vector2(210, 570), Vector2(112, 46), drop_load)
    _add_button("RESET", Vector2(754, 570), Vector2(86, 46), restart_game)
    _add_button("NEXT", Vector2(848, 570), Vector2(86, 46), next_manifest)

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

func _nudge_left() -> void:
    _move_once(-1)

func _nudge_right() -> void:
    _move_once(1)

func _move_once(direction: int) -> void:
    var result: Dictionary = Rules.move_hook(state, direction)
    if bool(result.get("ok", false)):
        state = result["state"]
        queue_redraw()

func drop_load() -> bool:
    var result: Dictionary = Rules.drop_load(state)
    if not bool(result.get("ok", false)):
        return false
    state = result["state"]
    _sync_controls()
    queue_redraw()
    return true

func restart_game() -> void:
    state = Rules.new_game(seed_value)
    _sync_controls()
    queue_redraw()

func next_manifest() -> void:
    seed_value += 1
    restart_game()

func _sync_controls() -> void:
    var terminal := str(state.get("status", "")) != "playing"
    for button in _buttons:
        if button.name != "ResetButton" and button.name != "NextButton":
            button.disabled = terminal

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#071520"), true)
    for x in range(32, int(size.x), 40):
        draw_line(Vector2(x, 76), Vector2(x, size.y - 80), Color(0.11, 0.22, 0.28, 0.38), 1.0)
    for y in range(100, int(size.y) - 80, 40):
        draw_line(Vector2(24, y), Vector2(size.x - 24, y), Color(0.11, 0.22, 0.28, 0.38), 1.0)

    var font = ThemeDB.fallback_font
    draw_string(font, Vector2(24, 38), "KROLL // CARGO CRANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#79e6df"))
    draw_string(font, Vector2(24, 64), "ALIGN THE LOAD. OVERLAP THE STACK. SIX CONTAINERS TO WIN.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a6c3cc"))
    draw_string(font, Vector2(24, 104), "LOAD %d/%d    MOVES %d    STATUS %s" % [int(state.get("level", 0)), Rules.MAX_LOADS, int(state.get("moves", 0)), str(state.get("status", "")).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f3bd62"))
    draw_string(font, Vector2(24, 130), str(state.get("message", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#dce8ed"))

    var base_y := size.y - BASE_Y_OFFSET
    var base_left := float(state.get("base_left", Rules.BASE_LEFT))
    var base_width := float(state.get("base_width", Rules.BASE_WIDTH))
    var base_center := base_left + base_width * 0.5
    draw_line(Vector2(base_center, 142), Vector2(base_center, base_y + 12), Color(0.23, 0.72, 0.73, 0.24), 2.0)
    draw_rect(Rect2(base_left - 22, base_y + 16, base_width + 44, 14), Color("#243b48"), true)
    draw_rect(Rect2(base_left, base_y, base_width, 16), Color("#8b9ca4"), true)

    var placed: Array = state.get("placed", [])
    for index in range(placed.size()):
        var block: Dictionary = placed[index]
        var block_y := base_y - float(index + 1) * BLOCK_HEIGHT
        draw_rect(Rect2(float(block["left"]), block_y, float(block["width"]), BLOCK_HEIGHT - 3), _block_color(int(block.get("color_index", index))))
        draw_rect(Rect2(float(block["left"]), block_y, float(block["width"]), 3), Color(0.9, 0.96, 1.0, 0.68), true)

    if str(state.get("status", "")) == "playing":
        var hook_x := float(state.get("hook_x", base_center))
        var load_width := float(state.get("load_width", 100.0))
        var load_y := base_y - float(placed.size() + 1) * BLOCK_HEIGHT - 40.0
        draw_line(Vector2(40, 82), Vector2(size.x - 40, 82), Color("#526b76"), 7.0)
        draw_rect(Rect2(hook_x - 18, 80, 36, 18), Color("#79e6df"), true)
        draw_line(Vector2(hook_x, 98), Vector2(hook_x, load_y), Color("#e2e9e8"), 3.0)
        draw_rect(Rect2(hook_x - load_width * 0.5, load_y, load_width, BLOCK_HEIGHT - 3), _block_color(int(state.get("seed", 0)) + int(state.get("level", 0))))
        draw_rect(Rect2(hook_x - load_width * 0.5, load_y, load_width, 3), Color("#f3bd62"), true)

    draw_string(font, Vector2(350, size.y - 22), "A / ← LEFT     D / → RIGHT     SPACE DROP     R RESET     N NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a6c3cc"))

func _block_color(index: int) -> Color:
    var colors := [Color("#1c9a91"), Color("#327db2"), Color("#d58d3f"), Color("#8d70b8"), Color("#5f9b64")]
    return colors[posmod(index, colors.size())]
