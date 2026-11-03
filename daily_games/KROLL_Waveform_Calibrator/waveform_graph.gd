extends Control

const Rules = preload("res://rules.gd")

var _current: Dictionary = {}
var _target: Dictionary = {}

func set_waveforms(current: Dictionary, target: Dictionary) -> void:
	_current = current.duplicate(true)
	_target = target.duplicate(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1b2b"), true)
	if size.x < 80.0 or size.y < 80.0 or _current.is_empty() or _target.is_empty():
		return
	var center_y := size.y * 0.5
	for division in range(1, 4):
		var y := size.y * float(division) / 4.0
		draw_line(Vector2(18.0, y), Vector2(size.x - 18.0, y), Color("#24384b"), 1.0)
	draw_line(Vector2(18.0, center_y), Vector2(size.x - 18.0, center_y), Color("#52677c"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(22.0, 20.0), "TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#f59e0b"))
	draw_string(ThemeDB.fallback_font, Vector2(100.0, 20.0), "YOUR SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#38bdf8"))
	draw_polyline(_build_curve(_target), Color("#f59e0b"), 2.5, true)
	draw_polyline(_build_curve(_current), Color("#38bdf8"), 2.5, true)

func _build_curve(settings: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var plot_width := maxf(1.0, size.x - 44.0)
	var plot_height := maxf(1.0, size.y - 52.0)
	for sample_index in range(97):
		var x := float(sample_index) / 96.0
		var value := Rules.waveform_value(settings, x)
		var screen_x := 22.0 + x * plot_width
		var screen_y := size.y * 0.5 - value * plot_height / 8.0
		points.append(Vector2(screen_x, screen_y))
	return points
