extends Node2D

const Rules = preload("res://rules.gd")
const VIEW_WIDTH: float = 960.0
const VIEW_HEIGHT: float = 640.0
const LANE_COUNT: int = 4
const LANE_WIDTH: float = VIEW_WIDTH / float(LANE_COUNT)
const HIT_LINE_Y: float = 520.0
const NOTE_SPEED: float = 300.0
const LAST_NOTE_TIME: float = 24.0
const CHART: Array[Dictionary] = [
	{"time": 1.25, "lane": 0}, {"time": 2.00, "lane": 1},
	{"time": 2.75, "lane": 2}, {"time": 3.50, "lane": 3},
	{"time": 4.25, "lane": 0}, {"time": 4.75, "lane": 2},
	{"time": 5.50, "lane": 1}, {"time": 6.00, "lane": 3},
	{"time": 6.75, "lane": 0}, {"time": 7.25, "lane": 1},
	{"time": 8.00, "lane": 3}, {"time": 8.50, "lane": 2},
	{"time": 9.25, "lane": 1}, {"time": 10.00, "lane": 0},
	{"time": 10.50, "lane": 2}, {"time": 11.25, "lane": 3},
	{"time": 12.00, "lane": 1}, {"time": 12.50, "lane": 0},
	{"time": 13.25, "lane": 2}, {"time": 14.00, "lane": 3},
	{"time": 15.00, "lane": 0}, {"time": 15.50, "lane": 1},
	{"time": 16.25, "lane": 2}, {"time": 17.00, "lane": 3},
	{"time": 18.00, "lane": 1}, {"time": 18.50, "lane": 3},
	{"time": 19.25, "lane": 0}, {"time": 20.00, "lane": 2},
	{"time": 21.00, "lane": 3}, {"time": 22.00, "lane": 1},
	{"time": 23.00, "lane": 0}, {"time": 24.00, "lane": 2}
]

var notes: Array[Dictionary] = []
var elapsed: float = 0.0
var score: int = 0
var combo: int = 0
var best_combo: int = 0
var lives: int = 5
var playing: bool = true
var status_text: String = "HIT THE PULSE"
var last_judgment: String = "READY"

func _ready() -> void:
	reset_game()

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	for index in range(notes.size()):
		var note: Dictionary = notes[index]
		if not bool(note["resolved"]) and elapsed > float(note["hit_time"]) + Rules.GOOD_WINDOW:
			_resolve_miss(index, "MISSED")
	if lives <= 0:
		playing = false
		status_text = "SYNC FAILED — PRESS R"
	elif _all_notes_resolved() and elapsed > LAST_NOTE_TIME + Rules.GOOD_WINDOW:
		playing = false
		status_text = "SYNC COMPLETE — PRESS R"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_R and not playing:
			reset_game()
			return
		if key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
			_hit_lane(0)
		elif key_event.keycode == KEY_S or key_event.keycode == KEY_DOWN:
			_hit_lane(1)
		elif key_event.keycode == KEY_D or key_event.keycode == KEY_UP:
			_hit_lane(2)
		elif key_event.keycode == KEY_F or key_event.keycode == KEY_RIGHT:
			_hit_lane(3)
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and touch.position.y >= HIT_LINE_Y - 100.0 and playing:
			_hit_lane(Rules.lane_from_x(touch.position.x, VIEW_WIDTH, LANE_COUNT))

func reset_game() -> void:
	elapsed = 0.0
	score = 0
	combo = 0
	best_combo = 0
	lives = 5
	playing = true
	status_text = "HIT THE PULSE"
	last_judgment = "READY"
	notes.clear()
	for chart_note: Dictionary in CHART:
		notes.append({
			"hit_time": float(chart_note["time"]),
			"lane": int(chart_note["lane"]),
			"resolved": false
		})
	queue_redraw()

func _hit_lane(lane: int) -> void:
	if not playing or lane < 0 or lane >= LANE_COUNT:
		return
	var best_index: int = -1
	var best_error: float = 999.0
	for index in range(notes.size()):
		var note: Dictionary = notes[index]
		if bool(note["resolved"]) or int(note["lane"]) != lane:
			continue
		var error_value: float = absf(float(note["hit_time"]) - elapsed)
		if error_value < best_error:
			best_error = error_value
			best_index = index
	if best_index < 0 or best_error > 0.22:
		status_text = "NO PULSE IN THIS LANE"
		combo = 0
		last_judgment = "EARLY"
		queue_redraw()
		return
	var judgment: String = Rules.judge_timing(best_error)
	if judgment == "MISS":
		_resolve_miss(best_index, "OFF BEAT")
	else:
		notes[best_index]["resolved"] = true
		score += Rules.score_for(judgment)
		combo += 1
		best_combo = maxi(best_combo, combo)
		last_judgment = judgment
		status_text = judgment + "  +" + str(Rules.score_for(judgment))
	queue_redraw()

func _resolve_miss(index: int, reason: String) -> void:
	notes[index]["resolved"] = true
	lives = maxi(0, lives - 1)
	combo = 0
	last_judgment = "MISS"
	status_text = reason + "  -1 CORE"

func _all_notes_resolved() -> bool:
	for note: Dictionary in notes:
		if not bool(note["resolved"]):
			return false
	return true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_WIDTH, VIEW_HEIGHT)), Color("#06101f"))
	for grid_x in range(0, int(VIEW_WIDTH) + 1, 40):
		draw_line(Vector2(grid_x, 80), Vector2(grid_x, VIEW_HEIGHT), Color(0.12, 0.28, 0.38, 0.28), 1.0)
	for grid_y in range(80, int(VIEW_HEIGHT) + 1, 40):
		draw_line(Vector2(0, grid_y), Vector2(VIEW_WIDTH, grid_y), Color(0.12, 0.28, 0.38, 0.22), 1.0)
	var lane_colors: Array[Color] = [Color("#38d9ff"), Color("#8bffb7"), Color("#ffca5c"), Color("#c19bff")]
	for lane in range(LANE_COUNT):
		var lane_x: float = float(lane) * LANE_WIDTH
		draw_rect(Rect2(lane_x + 4.0, 92.0, LANE_WIDTH - 8.0, 490.0), Color(0.05, 0.12, 0.20, 0.75))
		draw_line(Vector2(lane_x, 92.0), Vector2(lane_x, 582.0), lane_colors[lane] * Color(1, 1, 1, 0.35), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(lane_x + 22.0, 612.0), ["A / ←", "S / ↓", "D / ↑", "F / →"][lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lane_colors[lane])
	draw_line(Vector2(0, HIT_LINE_Y), Vector2(VIEW_WIDTH, HIT_LINE_Y), Color("#ffffff"), 3.0)
	for note: Dictionary in notes:
		if bool(note["resolved"]):
			continue
		var lane: int = int(note["lane"])
		var y_position: float = HIT_LINE_Y - (float(note["hit_time"]) - elapsed) * NOTE_SPEED
		if y_position < 80.0 or y_position > 590.0:
			continue
		var x_position: float = float(lane) * LANE_WIDTH + 28.0
		draw_rect(Rect2(x_position, y_position - 9.0, LANE_WIDTH - 56.0, 18.0), lane_colors[lane])
	draw_string(ThemeDB.fallback_font, Vector2(24, 42), "KROLL // PULSE RHYTHM", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#d9f8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 72), "SCORE %05d   COMBO %02d   BEST %02d   CORE %d" % [score, combo, best_combo, lives], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#8fdcff"))
	draw_string(ThemeDB.fallback_font, Vector2(620, 42), "TIME %05.2f / 24.00" % elapsed, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 560), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 590), "TAP A LANE NEAR THE HIT LINE ON TOUCH DEVICES", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#86aabd"))
