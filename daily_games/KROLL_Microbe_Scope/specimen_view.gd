extends Control
class_name KROLLMicrobeScopeView

var _specimen_id: String = "diatom"
var _focus: int = 50
var _magnification: int = 2
var _illumination: int = 50
var _stain: int = 0
var _clarity: int = 0

func set_specimen_data(specimen_id: String, focus: int, magnification: int, illumination: int, stain: int, clarity: int) -> void:
    _specimen_id = specimen_id
    _focus = focus
    _magnification = magnification
    _illumination = illumination
    _stain = stain
    _clarity = clarity
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1720"))
    var center: Vector2 = size * 0.5
    var grid_color := Color("#23404b")
    for index in range(1, 8):
        var x: float = size.x * float(index) / 8.0
        var y: float = size.y * float(index) / 8.0
        draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
        draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
    var brightness: float = 0.35 + 0.65 * float(_illumination) / 100.0
    var stain_color: Color = _stain_color()
    var sample_color: Color = Color(stain_color.r * brightness, stain_color.g * brightness, stain_color.b * brightness, 1.0)
    var magnification_scale: float = 0.72 + float(_magnification) * 0.22
    var blur_radius: float = float(100 - _clarity) / 24.0
    if _clarity < 100:
        for offset in [Vector2(blur_radius, 0), Vector2(-blur_radius, 0), Vector2(0, blur_radius), Vector2(0, -blur_radius)]:
            _draw_specimen(center + offset, magnification_scale, Color(sample_color.r, sample_color.g, sample_color.b, 0.14))
    _draw_specimen(center, magnification_scale, sample_color)
    var reticle := Color("#a4d7d0", 0.48)
    draw_line(center + Vector2(-16, 0), center + Vector2(-5, 0), reticle, 1.0)
    draw_line(center + Vector2(5, 0), center + Vector2(16, 0), reticle, 1.0)
    draw_line(center + Vector2(0, -16), center + Vector2(0, -5), reticle, 1.0)
    draw_line(center + Vector2(0, 5), center + Vector2(0, 16), reticle, 1.0)
    draw_rect(Rect2(Vector2(10, 10), size - Vector2(20, 20)), Color("#55727a"), false, 1.5)
    draw_line(Vector2(size.x - 115, size.y - 22), Vector2(size.x - 55, size.y - 22), Color("#c4d9d5"), 3.0)
    draw_line(Vector2(size.x - 115, size.y - 27), Vector2(size.x - 115, size.y - 17), Color("#c4d9d5"), 2.0)
    draw_line(Vector2(size.x - 55, size.y - 27), Vector2(size.x - 55, size.y - 17), Color("#c4d9d5"), 2.0)

func _stain_color() -> Color:
    match _stain:
        0: return Color("#77d4cc")
        1: return Color("#d78fe8")
        2: return Color("#edbd69")
        _: return Color("#9bdf8d")

func _draw_specimen(center: Vector2, scale_factor: float, color: Color) -> void:
    match _specimen_id:
        "diatom":
            _draw_diatom(center, scale_factor, color)
        "pollen":
            _draw_pollen(center, scale_factor, color)
        _:
            _draw_tardigrade(center, scale_factor, color)

func _draw_diatom(center: Vector2, scale_factor: float, color: Color) -> void:
    var radius: float = 76.0 * scale_factor
    draw_arc(center, radius, 0.0, TAU, 64, color, 3.0, true)
    draw_arc(center, radius * 0.72, 0.0, TAU, 64, color, 2.0, true)
    draw_arc(center, radius * 0.34, 0.0, TAU, 48, color, 2.0, true)
    for index in range(16):
        var angle: float = TAU * float(index) / 16.0
        var outer := center + Vector2(cos(angle), sin(angle)) * radius * 0.88
        var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.38
        draw_line(inner, outer, color, 2.0, true)
        draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.78, 3.0 * scale_factor, color)
    draw_circle(center, 9.0 * scale_factor, color)

func _draw_pollen(center: Vector2, scale_factor: float, color: Color) -> void:
    var radius: float = 64.0 * scale_factor
    draw_circle(center, radius, Color(color.r, color.g, color.b, 0.12))
    draw_arc(center, radius, 0.0, TAU, 64, color, 3.0, true)
    draw_arc(center, radius * 0.72, 0.0, TAU, 64, color, 2.0, true)
    for index in range(12):
        var angle: float = TAU * float(index) / 12.0
        var start := center + Vector2(cos(angle), sin(angle)) * radius * 0.92
        var finish := center + Vector2(cos(angle), sin(angle)) * radius * 1.25
        draw_line(start, finish, color, 3.0, true)
        draw_circle(finish, 4.0 * scale_factor, color)
    for index in range(6):
        var angle: float = TAU * float(index) / 6.0 + 0.25
        draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.43, 5.0 * scale_factor, color)

func _draw_tardigrade(center: Vector2, scale_factor: float, color: Color) -> void:
    var body_length: float = 148.0 * scale_factor
    var body_height: float = 48.0 * scale_factor
    var start_x: float = center.x - body_length * 0.5
    for index in range(5):
        var segment_center := Vector2(start_x + (float(index) + 0.5) * body_length / 5.0, center.y)
        draw_circle(segment_center, body_height * 0.46, Color(color.r, color.g, color.b, 0.16))
        draw_arc(segment_center, body_height * 0.46, 0.0, TAU, 36, color, 2.5, true)
    for index in range(4):
        var leg_x: float = start_x + (float(index) + 0.5) * body_length / 4.0
        var direction: float = -1.0 if index % 2 == 0 else 1.0
        for side in [-1.0, 1.0]:
            var hip := Vector2(leg_x, center.y + side * body_height * 0.25)
            var knee := hip + Vector2(direction * 10.0 * scale_factor, side * 24.0 * scale_factor)
            var foot := knee + Vector2(direction * 9.0 * scale_factor, side * 14.0 * scale_factor)
            draw_line(hip, knee, color, 3.0, true)
            draw_line(knee, foot, color, 2.5, true)
            draw_circle(foot, 3.5 * scale_factor, color)
