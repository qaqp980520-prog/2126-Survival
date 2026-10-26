extends Control

const Rules = preload("res://scripts/rules.gd")
const GRID_W: int = 5
const GRID_H: int = 5
const CELL: float = 88.0
const GAP: float = 8.0
const BOARD_X: float = 56.0
const BOARD_Y: float = 132.0
const SOURCE := Vector2i(0, 2)
const RECEIVER := Vector2i(4, 2)

var grid: Array = []
var time_left: float = 45.0
var moves: int = 0
var finished: bool = false
var status_text: String = "Rotate conduits to route the signal."

func _ready() -> void:
    _reset_game()

func _process(delta: float) -> void:
    if finished:
        return
    time_left = maxf(0.0, time_left - delta)
    if time_left <= 0.0:
        finished = true
        status_text = "TIME EXPIRED — press R to retry."
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and finished:
        _reset_game()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_point(event.position)
        accept_event()
    elif event is InputEventScreenTouch and event.pressed:
        _handle_point(event.position)
        accept_event()

func _handle_point(point: Vector2) -> void:
    if finished:
        return
    var local := point - Vector2(BOARD_X, BOARD_Y)
    if local.x < 0.0 or local.y < 0.0:
        return
    var stride := CELL + GAP
    var x := floori(local.x / stride)
    var y := floori(local.y / stride)
    if x < 0 or y < 0 or x >= GRID_W or y >= GRID_H:
        return
    if fposmod(local.x, stride) >= CELL or fposmod(local.y, stride) >= CELL:
        return
    var idx := Rules.index_of(Vector2i(x, y), GRID_W)
    var cell: Dictionary = grid[idx]
    if bool(cell.get("fixed", false)):
        status_text = "Source and receiver are fixed."
        queue_redraw()
        return
    cell["rotation"] = (int(cell.get("rotation", 0)) + 1) % 4
    grid[idx] = cell
    moves += 1
    if Rules.is_connected(grid, GRID_W, GRID_H, SOURCE, RECEIVER):
        finished = true
        status_text = "SIGNAL RESTORED — press R to replay."
    else:
        status_text = "Signal not connected yet."
    queue_redraw()

func _reset_game() -> void:
    grid = Rules.make_puzzle(GRID_W, GRID_H)
    time_left = 45.0
    moves = 0
    finished = false
    status_text = "Rotate conduits to route the signal."
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.04, 0.065))
    var font := get_theme_default_font()
    draw_string(font, Vector2(56, 56), "KROLL // SIGNAL SIPHON", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.45, 0.95, 1.0))
    draw_string(font, Vector2(56, 88), "Rotate the conduits. Connect SOURCE to RECEIVER.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.78, 0.86, 0.91))
    draw_string(font, Vector2(570, 155), "TIME  %04.1f s" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.45, 0.95, 1.0))
    draw_string(font, Vector2(570, 200), "MOVES  %d" % moves, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.83, 0.9, 0.94))
    draw_string(font, Vector2(570, 264), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.78, 0.35))
    draw_string(font, Vector2(570, 294), "Click / tap a pipe", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.83, 0.9, 0.94))
    draw_string(font, Vector2(570, 318), "to rotate clockwise.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.83, 0.9, 0.94))
    draw_string(font, Vector2(570, 362), "Fixed terminals cannot", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.83, 0.9, 0.94))
    draw_string(font, Vector2(570, 386), "be rotated.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.83, 0.9, 0.94))
    draw_string(font, Vector2(570, 450), status_text, HORIZONTAL_ALIGNMENT_LEFT, 330, 15, Color(0.4, 1.0, 0.68) if finished and time_left > 0.0 else Color(0.83, 0.9, 0.94))
    draw_string(font, Vector2(570, 512), "Target: restore signal", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.52, 0.65, 0.72))
    draw_string(font, Vector2(570, 534), "before the timer ends.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.52, 0.65, 0.72))

    for y in range(GRID_H):
        for x in range(GRID_W):
            var idx := Rules.index_of(Vector2i(x, y), GRID_W)
            var cell_rect := Rect2(BOARD_X + x * (CELL + GAP), BOARD_Y + y * (CELL + GAP), CELL, CELL)
            var cell: Dictionary = grid[idx]
            var kind := str(cell.get("kind", "pipe"))
            var fill := Color(0.06, 0.12, 0.17)
            if kind == "source":
                fill = Color(0.07, 0.22, 0.19)
            elif kind == "receiver":
                fill = Color(0.22, 0.16, 0.06)
            draw_rect(cell_rect, fill, true, 8.0)
            draw_rect(cell_rect, Color(0.22, 0.35, 0.42), false, 1.5, true)
            _draw_pipe(cell_rect, cell)

func _draw_pipe(rect: Rect2, cell: Dictionary) -> void:
    var ports := Rules.ports_for(cell)
    var center := rect.position + rect.size * 0.5
    var half := CELL * 0.5 - 12.0
    var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
    var bits: Array[int] = [Rules.PORT_N, Rules.PORT_E, Rules.PORT_S, Rules.PORT_W]
    var color := Color(0.25, 0.82, 0.9)
    if str(cell.get("kind", "")) == "source":
        color = Color(0.25, 1.0, 0.62)
    elif str(cell.get("kind", "")) == "receiver":
        color = Color(1.0, 0.72, 0.25)
    for i in range(4):
        if (ports & bits[i]) != 0:
            var endpoint := center + Vector2(directions[i].x, directions[i].y) * half
            draw_line(center, endpoint, color, 8.0, true)
    draw_circle(center, 6.0, color)
