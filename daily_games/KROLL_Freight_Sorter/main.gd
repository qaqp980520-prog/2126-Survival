extends Node2D

const Rules = preload("res://rules.gd")
const FONT_SIZE := 22
const LANES := [
	{"action": "bay_ore", "label": "ORE BAY", "x": 90.0},
	{"action": "bay_medical", "label": "MED BAY", "x": 370.0},
	{"action": "bay_data", "label": "DATA BAY", "x": 650.0}
]
const TYPE_LABELS := {
	"ORE": "RAW ORE",
	"MEDICAL": "MEDICAL",
	"DATA": "DATA CORE",
	"HAZARD": "HAZARD"
}
const TYPE_COLORS := {
	"ORE": Color(0.95, 0.55, 0.16),
	"MEDICAL": Color(0.25, 0.95, 0.65),
	"DATA": Color(0.3, 0.72, 1.0),
	"HAZARD": Color(1.0, 0.22, 0.32)
}

var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var time_left := Rules.ROUND_SECONDS
var score := 0
var lives := Rules.STARTING_LIVES
var combo := 0
var active_crate: Dictionary = {}
var spawn_wait := 0.0
var ended := false
var last_result := "SORT CARGO BEFORE THE TIMER EXPIRES"

func _ready() -> void:
	rng.randomize()
	_spawn_crate()
	queue_redraw()

func _process(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	time_left = maxf(0.0, Rules.ROUND_SECONDS - elapsed)
	if time_left <= 0.0:
		ended = true
		active_crate.clear()
		last_result = "SHIFT COMPLETE"
		queue_redraw()
		return

	if not active_crate.is_empty():
		active_crate["time_left"] = float(active_crate["time_left"]) - delta
		if float(active_crate["time_left"]) <= 0.0:
			_miss_crate("CRATE MISSED")
	else:
		spawn_wait -= delta
		if spawn_wait <= 0.0:
			_spawn_crate()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if ended:
		if event.keycode == KEY_R:
			restart_game()
		return
	match event.keycode:
		KEY_1, KEY_A:
			_submit_action("bay_ore")
		KEY_2, KEY_S:
			_submit_action("bay_medical")
		KEY_3, KEY_D:
			_submit_action("bay_data")
		KEY_SPACE:
			_submit_action("quarantine")

func _spawn_crate() -> void:
	var types: Array[String] = ["ORE", "MEDICAL", "DATA", "HAZARD"]
	var kind := types[rng.randi_range(0, types.size() - 1)]
	active_crate = {"type": kind, "time_left": Rules.CRATE_SECONDS}
	last_result = "INCOMING: " + str(TYPE_LABELS[kind])

func _submit_action(action: String) -> void:
	if ended or active_crate.is_empty():
		return
	var kind := str(active_crate.get("type", ""))
	var outcome: Dictionary = Rules.resolve(kind, action, combo)
	if bool(outcome["correct"]):
		score += int(outcome["score_delta"])
		combo = int(outcome["next_combo"])
		last_result = "ACCEPTED  +" + str(outcome["score_delta"]) + "  COMBO x" + str(combo)
	else:
		lives -= 1
		combo = 0
		last_result = "REJECTED  " + str(outcome["reason"]).to_upper()
	active_crate.clear()
	spawn_wait = 0.42
	if lives <= 0:
		ended = true
		last_result = "SHIFT FAILED — PRESS R"
	queue_redraw()

func _miss_crate(message: String) -> void:
	lives -= 1
	combo = 0
	active_crate.clear()
	spawn_wait = 0.42
	last_result = message
	if lives <= 0:
		ended = true
		last_result = "SHIFT FAILED — PRESS R"
	queue_redraw()

func restart_game() -> void:
	elapsed = 0.0
	time_left = Rules.ROUND_SECONDS
	score = 0
	lives = Rules.STARTING_LIVES
	combo = 0
	active_crate.clear()
	spawn_wait = 0.0
	ended = false
	last_result = "NEW SHIFT STARTED"
	_spawn_crate()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 640)), Color(0.015, 0.025, 0.05), true)
	for y in range(0, 641, 32):
		draw_line(Vector2(0, y), Vector2(960, y), Color(0.05, 0.15, 0.22, 0.55), 1.0)
	for x in range(0, 961, 32):
		draw_line(Vector2(x, 0), Vector2(x, 640), Color(0.05, 0.15, 0.22, 0.55), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(32, 42), "KROLL // FREIGHT SORTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.35, 0.92, 1.0))
	draw_string(font, Vector2(32, 78), "SCORE %04d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.92, 0.97, 1.0))
	draw_string(font, Vector2(330, 78), "TIME %02d" % int(ceil(time_left)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.86, 0.35))
	draw_string(font, Vector2(550, 78), "LIVES " + "◆".repeat(maxi(lives, 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.35, 0.42))
	draw_string(font, Vector2(780, 78), "COMBO x%d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 1.0, 0.68))

	for i in range(LANES.size()):
		var lane: Dictionary = LANES[i]
		var box := Rect2(Vector2(float(lane["x"]), 425), Vector2(220, 145))
		draw_rect(box, Color(0.04, 0.10, 0.16), true)
		draw_rect(box, Color(0.15, 0.62, 0.72), false, 2.0)
		draw_string(font, Vector2(float(lane["x"]) + 18, 463), str(lane["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.45, 0.92, 1.0))
		draw_string(font, Vector2(float(lane["x"]) + 18, 515), "KEY %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.92, 1.0))
		draw_string(font, Vector2(float(lane["x"]) + 18, 548), ["A / 1", "S / 2", "D / 3"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.6, 0.72, 0.82))

	draw_rect(Rect2(Vector2(32, 112), Vector2(896, 276)), Color(0.025, 0.055, 0.09), true)
	draw_rect(Rect2(Vector2(32, 112), Vector2(896, 276)), Color(0.12, 0.35, 0.45), false, 2.0)
	draw_string(font, Vector2(56, 150), "CONVEYOR SCANNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.92, 1.0))
	if not active_crate.is_empty():
		var kind := str(active_crate["type"])
		var tint: Color = TYPE_COLORS[kind]
		var card := Rect2(Vector2(335, 185), Vector2(290, 155))
		draw_rect(card, Color(0.08, 0.13, 0.19), true)
		draw_rect(card, tint, false, 4.0)
		draw_string(font, Vector2(365, 230), "CARGO DETECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.9, 1.0))
		draw_string(font, Vector2(365, 272), str(TYPE_LABELS[kind]), HORIZONTAL_ALIGNMENT_LEFT, -1, 27, tint)
		var remaining := clampf(float(active_crate["time_left"]) / Rules.CRATE_SECONDS, 0.0, 1.0)
		draw_rect(Rect2(Vector2(365, 300), Vector2(230, 12)), Color(0.15, 0.2, 0.25), true)
		draw_rect(Rect2(Vector2(365, 300), Vector2(230 * remaining, 12)), tint, true)
	else:
		draw_string(font, Vector2(365, 250), "SCANNER WAITING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.75, 0.85))
	draw_string(font, Vector2(32, 610), last_result + "  |  SPACE = QUARANTINE HAZARD  |  R = RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.72, 0.82, 0.9))
	if ended:
		draw_rect(Rect2(Vector2(240, 220), Vector2(480, 120)), Color(0.02, 0.03, 0.06, 0.94), true)
		draw_rect(Rect2(Vector2(240, 220), Vector2(480, 120)), Color(0.35, 0.92, 1.0), false, 2.0)
		draw_string(font, Vector2(300, 270), last_result, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.88, 0.4))
		draw_string(font, Vector2(300, 310), "FINAL SCORE: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 1.0))
