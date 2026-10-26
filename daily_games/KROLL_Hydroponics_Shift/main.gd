extends Node2D

const Rules = preload("res://rules.gd")
const VIEW_WIDTH: float = 960.0
const VIEW_HEIGHT: float = 720.0
const BED_WIDTH: float = 248.0
const BED_GAP: float = 28.0
const BED_TOP: float = 210.0
const BED_HEIGHT: float = 300.0

var beds: Array[Dictionary] = []
var seconds_left: float = Rules.ROUND_SECONDS
var credits: int = 0
var playing: bool = true
var status_text: String = "KEEP THE ROOTS ALIVE"

func _ready() -> void:
	reset_game()

func _process(delta: float) -> void:
	if not playing:
		return
	seconds_left = maxf(0.0, seconds_left - delta)
	for bed in beds:
		Rules.advance_bed(bed, delta)
	if Rules.is_victory(beds):
		playing = false
		status_text = "HARVEST TARGET REACHED — PRESS R"
	elif Rules.is_timeout(seconds_left):
		playing = false
		status_text = "SHIFT OVER — PRESS R"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_R and not playing:
			reset_game()
			return
		if not playing:
			return
		match key:
			KEY_1: _water_bed(0)
			KEY_2: _water_bed(1)
			KEY_3: _water_bed(2)
			KEY_Q: _harvest_bed(0)
			KEY_W: _harvest_bed(1)
			KEY_E: _harvest_bed(2)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch(event.position)

func _handle_touch(position: Vector2) -> void:
	if not playing or position.y < BED_TOP or position.y > BED_TOP + BED_HEIGHT:
		return
	var index: int = clampi(int(floor((position.x - 64.0) / (BED_WIDTH + BED_GAP))), 0, Rules.BED_COUNT - 1)
	var bed_left: float = 64.0 + float(index) * (BED_WIDTH + BED_GAP)
	if position.x < bed_left or position.x > bed_left + BED_WIDTH:
		return
	if position.y < BED_TOP + 150.0:
		_water_bed(index)
	else:
		_harvest_bed(index)

func _water_bed(index: int) -> void:
	if index < 0 or index >= beds.size():
		return
	if Rules.water(beds[index]):
		status_text = "BED %d WATERED" % (index + 1)
	else:
		status_text = "BED %d NEEDS NO WATER" % (index + 1)
	queue_redraw()

func _harvest_bed(index: int) -> void:
	if index < 0 or index >= beds.size():
		return
	if Rules.harvest(beds[index]):
		credits += Rules.HARVEST_REWARD
		status_text = "HARVEST +%d CREDITS" % Rules.HARVEST_REWARD
	else:
		status_text = "BED %d NOT READY" % (index + 1)
	queue_redraw()

func reset_game() -> void:
	beds = Rules.create_beds()
	seconds_left = Rules.ROUND_SECONDS
	credits = 0
	playing = true
	status_text = "KEEP THE ROOTS ALIVE"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_WIDTH, VIEW_HEIGHT)), Color("#07111e"))
	for grid_x in range(0, int(VIEW_WIDTH), 32):
		draw_line(Vector2(grid_x, 0), Vector2(grid_x, VIEW_HEIGHT), Color(0.12, 0.32, 0.42, 0.16), 1.0)
	for grid_y in range(0, int(VIEW_HEIGHT), 32):
		draw_line(Vector2(0, grid_y), Vector2(VIEW_WIDTH, grid_y), Color(0.12, 0.32, 0.42, 0.16), 1.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(54, 58), "KROLL // HYDROPONICS SHIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("#68f2e4"))
	draw_string(font, Vector2(56, 96), "HARVEST 10 CROPS BEFORE THE 90-SECOND SHIFT ENDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a4c6d8"))
	draw_string(font, Vector2(56, 142), "TIME  %05.1f" % seconds_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#f4d879"))
	draw_string(font, Vector2(335, 142), "CREDITS  %03d" % credits, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#68f2e4"))
	draw_string(font, Vector2(655, 142), "HARVESTS  %02d / %02d" % [Rules.total_harvests(beds), Rules.TARGET_HARVESTS], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d4e8f4"))
	for index in range(beds.size()):
		_draw_bed(font, index, beds[index])
	draw_string(font, Vector2(58, 566), "WATER: 1 / 2 / 3     HARVEST: Q / W / E     TOUCH: TOP = WATER, BOTTOM = HARVEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b6cbd8"))
	draw_string(font, Vector2(58, 604), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#68f2e4") if playing else Color("#f4d879"))
	draw_string(font, Vector2(58, 650), "MOISTURE BELOW 12 STOPS GROWTH. WATER EARLY; READY CROPS CAN BE HARVESTED ANYTIME.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8298ad"))

func _draw_bed(font: Font, index: int, bed: Dictionary) -> void:
	var x: float = 64.0 + float(index) * (BED_WIDTH + BED_GAP)
	var rect := Rect2(Vector2(x, BED_TOP), Vector2(BED_WIDTH, BED_HEIGHT))
	draw_rect(rect, Color("#0d2230"), true)
	draw_rect(rect, Color("#2e6572"), false, 2.0)
	draw_string(font, Vector2(x + 18, BED_TOP + 34), "GROW BED %02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#68f2e4"))
	var growth: float = clampf(float(bed["growth"]), 0.0, 100.0)
	var moisture: float = clampf(float(bed["moisture"]), 0.0, 100.0)
	var stem_height: float = 25.0 + growth * 0.95
	var stem_x: float = x + BED_WIDTH * 0.5
	var stem_bottom: float = BED_TOP + 205.0
	draw_line(Vector2(stem_x, stem_bottom), Vector2(stem_x, stem_bottom - stem_height), Color("#6ee7a8"), 5.0)
	draw_line(Vector2(stem_x, stem_bottom - stem_height * 0.6), Vector2(stem_x - 27, stem_bottom - stem_height * 0.72), Color("#6ee7a8"), 4.0)
	draw_line(Vector2(stem_x, stem_bottom - stem_height * 0.75), Vector2(stem_x + 29, stem_bottom - stem_height * 0.88), Color("#6ee7a8"), 4.0)
	draw_circle(Vector2(stem_x, stem_bottom - stem_height), 8.0 + growth * 0.04, Color("#a4ffba"))
	draw_string(font, Vector2(x + 18, BED_TOP + 244), "GROWTH %3.0f%%" % growth, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d4e8f4"))
	draw_rect(Rect2(Vector2(x + 18, BED_TOP + 255), Vector2(BED_WIDTH - 36, 8)), Color("#243847"))
	draw_rect(Rect2(Vector2(x + 18, BED_TOP + 255), Vector2((BED_WIDTH - 36) * growth / 100.0, 8)), Color("#6ee7a8"))
	draw_string(font, Vector2(x + 18, BED_TOP + 286), "MOISTURE %3.0f%%" % moisture, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d4e8f4"))
	draw_rect(Rect2(Vector2(x + 18, BED_TOP + 291), Vector2(BED_WIDTH - 36, 6)), Color("#243847"))
	draw_rect(Rect2(Vector2(x + 18, BED_TOP + 291), Vector2((BED_WIDTH - 36) * moisture / 100.0, 6)), Color("#55b7ff"))
	if growth >= 100.0:
		draw_string(font, Vector2(x + 18, BED_TOP + 70), "READY TO HARVEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f4d879"))
