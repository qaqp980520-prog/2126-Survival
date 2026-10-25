extends Node2D

const MAP_SIZE := Vector2(1100.0, 720.0)
const PLAYER_RADIUS := 15.0
const NORMAL_SPEED := 245.0
const BOOST_SPEED := 390.0
const RESCUE_GOAL := 4

var player_pos := Vector2(100, 610)
var battery := 100.0
var rescued := 0
var elapsed := 0.0
var game_over := false
var victory := false
var message := "找到 4 名倖存者，再飛到右上角撤離區！"
var survivors: Array[Vector2] = [Vector2(260, 170), Vector2(470, 520), Vector2(735, 260), Vector2(875, 540)]
var batteries: Array[Vector2] = [Vector2(330, 390), Vector2(640, 120), Vector2(930, 370)]
var hazards: Array[Dictionary] = [
	{"pos": Vector2(350, 250), "radius": 48.0},
	{"pos": Vector2(590, 380), "radius": 62.0},
	{"pos": Vector2(825, 160), "radius": 44.0},
	{"pos": Vector2(180, 390), "radius": 38.0}
]
var extraction := Rect2(900, 45, 145, 95)

func _process(delta: float) -> void:
	if game_over:
		if Input.is_key_pressed(KEY_R): _restart()
		queue_redraw()
		return
	elapsed += delta
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1.0
	var boosting := Input.is_key_pressed(KEY_SHIFT) and battery > 1.0 and move.length() > 0.0
	if move.length() > 0.0:
		player_pos += move.normalized() * (BOOST_SPEED if boosting else NORMAL_SPEED) * delta
		battery -= delta * (4.2 if boosting else 1.35)
	else:
		battery -= delta * 0.45
	player_pos.x = clampf(player_pos.x, 30.0, MAP_SIZE.x - 30.0)
	player_pos.y = clampf(player_pos.y, 85.0, MAP_SIZE.y - 35.0)
	battery = clampf(battery, 0.0, 100.0)
	for i in range(survivors.size() - 1, -1, -1):
		if player_pos.distance_to(survivors[i]) < 28.0:
			survivors.remove_at(i)
			rescued += 1
			message = "救援成功！目前已救出 %d / %d 名倖存者。" % [rescued, RESCUE_GOAL]
	for i in range(batteries.size() - 1, -1, -1):
		if player_pos.distance_to(batteries[i]) < 25.0:
			batteries.remove_at(i)
			battery = minf(100.0, battery + 32.0)
			message = "取得電池補給，電量恢復。"
	for hazard in hazards:
		if player_pos.distance_to(hazard["pos"]) < float(hazard["radius"]) + PLAYER_RADIUS * 0.55:
			battery = maxf(0.0, battery - delta * 22.0)
			message = "警告：進入電磁干擾區，電量快速下降！"
	if extraction.has_point(player_pos):
		if rescued >= RESCUE_GOAL:
			victory = true
			game_over = true
			message = "任務完成！所有倖存者已撤離。按 R 重新開始。"
		else:
			message = "撤離區尚未開放：還需要救出 %d 名倖存者。" % (RESCUE_GOAL - rescued)
	if battery <= 0.0:
		game_over = true
		victory = false
		message = "無人機電量耗盡，任務失敗。按 R 重新開始。"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#101923"), true)
	for x in range(0, int(MAP_SIZE.x), 40):
		draw_line(Vector2(x, 60), Vector2(x, MAP_SIZE.y), Color(0.16, 0.28, 0.33, 0.42), 1.0)
	for y in range(60, int(MAP_SIZE.y), 40):
		draw_line(Vector2(0, y), Vector2(MAP_SIZE.x, y), Color(0.16, 0.28, 0.33, 0.42), 1.0)
	for hazard in hazards:
		var hp: Vector2 = hazard["pos"]
		var radius: float = hazard["radius"]
		draw_circle(hp, radius, Color(0.75, 0.20, 0.16, 0.20))
		draw_arc(hp, radius, 0.0, TAU, 48, Color("#f06d55"), 2.0)
		draw_string(ThemeDB.fallback_font, hp + Vector2(-34, 4), "EMI", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ff9c8b"))
	draw_rect(extraction, Color(0.10, 0.48, 0.46, 0.22), true)
	draw_rect(extraction, Color("#52e3cf"), false, 3.0)
	draw_string(ThemeDB.fallback_font, extraction.position + Vector2(10, 28), "KROLL EXTRACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8cfff0"))
	for pos in survivors:
		draw_circle(pos, 13.0, Color("#f6d36b"))
		draw_circle(pos + Vector2(0, -6), 5.0, Color("#3b2d13"))
		draw_line(pos + Vector2(-8, 7), pos + Vector2(8, 7), Color("#3b2d13"), 3.0)
	for pos in batteries:
		draw_rect(Rect2(pos - Vector2(10, 13), Vector2(20, 26)), Color("#70e68a"), true)
		draw_rect(Rect2(pos - Vector2(10, 13), Vector2(20, 26)), Color("#c5ffd1"), false, 2.0)
		draw_line(pos + Vector2(-4, 0), pos + Vector2(4, 0), Color("#133d24"), 3.0)
	draw_line(player_pos + Vector2(-22, -17), player_pos + Vector2(22, 17), Color("#69dcf3"), 3.0)
	draw_line(player_pos + Vector2(22, -17), player_pos + Vector2(-22, 17), Color("#69dcf3"), 3.0)
	for offset in [Vector2(-22, -17), Vector2(22, -17), Vector2(-22, 17), Vector2(22, 17)]:
		draw_circle(player_pos + offset, 7.0, Color("#183b4a"))
		draw_arc(player_pos + offset, 8.0, 0.0, TAU, 24, Color("#8ff0ff"), 2.0)
	draw_circle(player_pos, 9.0, Color("#c6f7ff"))
	draw_rect(Rect2(0, 0, MAP_SIZE.x, 60), Color("#091018"), true)
	draw_string(ThemeDB.fallback_font, Vector2(22, 25), "KROLL // DRONE RESCUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#7eeaff"))
	draw_string(ThemeDB.fallback_font, Vector2(22, 48), "WASD／方向鍵移動｜Shift 加速｜靠近黃點救人｜綠色電池補給｜R 重來", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d5e5e9"))
	draw_string(ThemeDB.fallback_font, Vector2(660, 26), "RESCUED %d / %d" % [rescued, RESCUE_GOAL], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f6d36b"))
	draw_rect(Rect2(660, 35, 190, 14), Color("#26343e"), true)
	draw_rect(Rect2(660, 35, 190.0 * battery / 100.0, 14), Color("#70e68a") if battery > 25.0 else Color("#ff665c"), true)
	draw_string(ThemeDB.fallback_font, Vector2(865, 47), "BAT %d%%" % int(battery), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e7f4f7"))
	draw_string(ThemeDB.fallback_font, Vector2(22, 692), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f5f7"))
	if game_over:
		draw_rect(Rect2(300, 270, 500, 150), Color(0.02, 0.05, 0.08, 0.92), true)
		draw_rect(Rect2(300, 270, 500, 150), Color("#7eeaff") if victory else Color("#ff665c"), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(345, 320), "MISSION COMPLETE" if victory else "MISSION FAILED", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#8cfff0") if victory else Color("#ff8b83"))
		draw_string(ThemeDB.fallback_font, Vector2(345, 365), "按 R 重新開始任務", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e8f5f7"))

func _restart() -> void:
	player_pos = Vector2(100, 610)
	battery = 100.0
	rescued = 0
	elapsed = 0.0
	game_over = false
	victory = false
	message = "找到 4 名倖存者，再飛到右上角撤離區！"
	survivors = [Vector2(260, 170), Vector2(470, 520), Vector2(735, 260), Vector2(875, 540)]
	batteries = [Vector2(330, 390), Vector2(640, 120), Vector2(930, 370)]
