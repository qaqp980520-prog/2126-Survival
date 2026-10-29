extends Control

const Rules = preload("res://rules.gd")
const LANE_KEYS: Array[int] = [KEY_A, KEY_S, KEY_D, KEY_F]
const LANE_NAMES: Array[String] = ["A", "S", "D", "F"]
const LANE_COLORS: Array[Color] = [
	Color("#68e7ff"),
	Color("#a4f59b"),
	Color("#ffd36e"),
	Color("#ff8ca8")
]

var rules = Rules.new()
var elapsed_seconds: float = 0.0
var chart_index: int = 0
var lane_buttons: Array[Button] = []
var status_label: Label
var result_label: Label
var chart_label: Label

func _ready() -> void:
	_build_ui()
	restart_chart()

func _process(delta: float) -> void:
	if rules == null:
		return
	elapsed_seconds += delta
	rules.advance(elapsed_seconds)
	_refresh_labels()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		restart_chart()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_N:
		next_chart()
		get_viewport().set_input_as_handled()
		return
	for lane in range(LANE_KEYS.size()):
		if key_event.keycode == LANE_KEYS[lane]:
			press_lane(lane)
			get_viewport().set_input_as_handled()
			return

func press_lane(lane: int) -> Dictionary:
	var result: Dictionary = rules.judge_lane(lane, elapsed_seconds)
	if bool(result.get("ok", false)):
		result_label.text = "CLEAN HIT  +100"
		result_label.add_theme_color_override("font_color", LANE_COLORS[lane])
	elif str(result.get("reason", "")) == "offbeat":
		result_label.text = "OFF BEAT — RESET YOUR GROOVE"
		result_label.add_theme_color_override("font_color", Color("#ff8ca8"))
	elif str(result.get("reason", "")) == "invalid_lane":
		result_label.text = "UNKNOWN LANE"
	else:
		result_label.text = "CHART LOCKED"
	_refresh_labels()
	queue_redraw()
	return result

func restart_chart() -> void:
	elapsed_seconds = 0.0
	rules.start_chart(chart_index)
	if result_label != null:
		result_label.text = "READY — FOLLOW THE FALLING NOTES"
		result_label.add_theme_color_override("font_color", Color("#b5c9d9"))
	_refresh_labels()
	queue_redraw()

func next_chart() -> void:
	chart_index = posmod(chart_index + 1, Rules.LANE_PATTERNS.size())
	restart_chart()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.name = "PageMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var title := Label.new()
	title.name = "Title"
	title.text = "KROLL // BEAT LAB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#79e7ff"))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Original rhythm patterns · 100 BPM · Hit A / S / D / F on the line"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#b5c9d9"))
	page.add_child(subtitle)

	chart_label = Label.new()
	chart_label.name = "ChartLabel"
	chart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chart_label.add_theme_font_size_override("font_size", 18)
	chart_label.add_theme_color_override("font_color", Color("#ffd28b"))
	page.add_child(chart_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("#d8e6f2"))
	page.add_child(status_label)

	var spacer := Control.new()
	spacer.name = "RhythmFieldSpacer"
	spacer.custom_minimum_size = Vector2(0, 250)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)

	var lane_row := HBoxContainer.new()
	lane_row.name = "LaneButtons"
	lane_row.add_theme_constant_override("separation", 8)
	page.add_child(lane_row)
	for lane in range(4):
		var button := Button.new()
		button.name = "LaneButton%d" % lane
		button.text = "%s  /  LANE %d" % [LANE_NAMES[lane], lane + 1]
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_lane_button_pressed.bind(lane))
		lane_row.add_child(button)
		lane_buttons.append(button)

	result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.text = "READY — FOLLOW THE FALLING NOTES"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_color_override("font_color", Color("#b5c9d9"))
	page.add_child(result_label)

	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 12)
	page.add_child(utility_row)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "R  RESTART"
	restart_button.custom_minimum_size = Vector2(160, 38)
	restart_button.pressed.connect(restart_chart)
	utility_row.add_child(restart_button)

	var next_button := Button.new()
	next_button.name = "NextChartButton"
	next_button.text = "N  NEXT CHART"
	next_button.custom_minimum_size = Vector2(160, 38)
	next_button.pressed.connect(next_chart)
	utility_row.add_child(next_button)

func _on_lane_button_pressed(lane: int) -> void:
	press_lane(lane)

func _refresh_labels() -> void:
	if status_label == null or chart_label == null:
		return
	var status: Dictionary = rules.get_status()
	chart_label.text = "CHART %d / %d   •   24 NOTES   •   100 BPM" % [chart_index + 1, Rules.LANE_PATTERNS.size()]
	status_label.text = "SCORE %04d     COMBO %02d     MAX %02d     MISSES %d / %d     LEFT %d" % [
		int(status["score"]), int(status["combo"]), int(status["max_combo"]),
		int(status["misses"]), Rules.MAX_MISSES, int(status["remaining"])
	]
	if bool(status["finished"]):
		result_label.text = "SIGNAL LOCKED — CLEAR!" if bool(status["won"]) else "SIGNAL LOST — TRY AGAIN"
		result_label.add_theme_color_override("font_color", Color("#a4f59b") if bool(status["won"]) else Color("#ff8ca8"))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07111f"), true)
	var lane_width: float = size.x / 4.0
	var hit_y: float = size.y * 0.72
	for lane in range(4):
		var lane_rect := Rect2(Vector2(lane_width * lane + 2.0, 105.0), Vector2(lane_width - 4.0, maxf(40.0, size.y - 225.0)))
		draw_rect(lane_rect, Color("#0d2032") if lane % 2 == 0 else Color("#10263a"), true)
		draw_rect(Rect2(Vector2(lane_width * lane, 105.0), Vector2(1.0, maxf(40.0, size.y - 225.0))), Color("#2a4b62"), true)
		draw_string(ThemeDB.fallback_font, Vector2(lane_width * lane + 8.0, 130.0), LANE_NAMES[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LANE_COLORS[lane])
	draw_rect(Rect2(Vector2(0.0, hit_y), Vector2(size.x, 4.0)), Color("#ffffff"), true)
	draw_rect(Rect2(Vector2(0.0, hit_y - 3.0), Vector2(size.x, 10.0)), Color("#68e7ff", 0.2), true)
	for note in rules.get_notes():
		if bool(note["resolved"]):
			continue
		var note_y: float = hit_y - (float(note["time"]) - elapsed_seconds) * 190.0
		if note_y < 100.0 or note_y > size.y - 145.0:
			continue
		var lane_index: int = int(note["lane"])
		var center := Vector2(lane_width * (float(lane_index) + 0.5), note_y)
		draw_circle(center, 14.0, LANE_COLORS[lane_index])
		draw_circle(center, 19.0, Color(LANE_COLORS[lane_index], 0.18))
