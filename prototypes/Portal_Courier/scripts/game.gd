extends Node2D

const SCREEN := Vector2(960, 540)
const GRAVITY := 1250.0
const MOVE_SPEED := 285.0
const JUMP_SPEED := -470.0
const ROUND_TIME := 90.0

var player: CharacterBody2D
var hud: Label
var help_label: Label
var message_label: Label
var platforms: Array[Dictionary] = []
var shards: Array[Dictionary] = []
var drones: Array[Dictionary] = []
var portal_pos := Vector2(900, 454)
var elapsed := 0.0
var lives := 3
var collected := 0
var game_state := "playing"
var jump_was_down := false
var hurt_lock := 0.0

func _ready() -> void:
	_build_level()
	_build_player()
	_build_ui()
	_update_hud()
	queue_redraw()

func _build_level() -> void:
	platforms = [
		{"rect": Rect2(0, 490, 960, 50), "color": Color("55534c")},
		{"rect": Rect2(95, 410, 160, 18), "color": Color("77715b")},
		{"rect": Rect2(310, 340, 145, 18), "color": Color("77715b")},
		{"rect": Rect2(515, 275, 145, 18), "color": Color("77715b")},
		{"rect": Rect2(710, 350, 135, 18), "color": Color("77715b")},
	]
	shards = [
		{"pos": Vector2(175, 378), "taken": false},
		{"pos": Vector2(382, 308), "taken": false},
		{"pos": Vector2(587, 243), "taken": false},
		{"pos": Vector2(777, 318), "taken": false},
		{"pos": Vector2(500, 458), "taken": false},
	]
	drones = [
		{"pos": Vector2(330, 470), "start": 275.0, "end": 440.0, "dir": 1.0, "speed": 105.0, "disabled": 0.0},
		{"pos": Vector2(650, 470), "start": 565.0, "end": 740.0, "dir": -1.0, "speed": 125.0, "disabled": 0.0},
		{"pos": Vector2(770, 330), "start": 715.0, "end": 830.0, "dir": -1.0, "speed": 80.0, "disabled": 0.0},
	]
	for platform in platforms:
		var body := StaticBody2D.new()
		body.position = platform["rect"].position + platform["rect"].size * 0.5
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = platform["rect"].size
		shape_node.shape = shape
		body.add_child(shape_node)
		add_child(body)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Courier"
	player.position = Vector2(50, 455)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 30)
	collision.shape = shape
	player.add_child(collision)
	var body_visual := Polygon2D.new()
	body_visual.polygon = PackedVector2Array([Vector2(-11,-14), Vector2(11,-14), Vector2(12,9), Vector2(5,15), Vector2(-8,15), Vector2(-12,6)])
	body_visual.color = Color("4bd4e8")
	player.add_child(body_visual)
	var visor := Polygon2D.new()
	visor.polygon = PackedVector2Array([Vector2(1,-9), Vector2(9,-7), Vector2(8,-2), Vector2(0,-3)])
	visor.color = Color("eaffff")
	player.add_child(visor)
	add_child(player)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18, 12)
	hud.size = Vector2(700, 34)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", Color("f3f0d8"))
	layer.add_child(hud)
	help_label = Label.new()
	help_label.position = Vector2(18, 510)
	help_label.size = Vector2(900, 24)
	help_label.text = "A/D 或 ←/→ 移動　Space 跳躍　E EMP 脈衝　R 重新開始"
	help_label.add_theme_font_size_override("font_size", 15)
	help_label.add_theme_color_override("font_color", Color("e6e2d2"))
	layer.add_child(help_label)
	message_label = Label.new()
	message_label.position = Vector2(250, 95)
	message_label.size = Vector2(500, 130)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 28)
	message_label.add_theme_color_override("font_color", Color("ffffff"))
	layer.add_child(message_label)

func _physics_process(delta: float) -> void:
	if Input.is_key_just_pressed(KEY_R) and game_state != "playing":
		_restart()
		return
	if game_state != "playing":
		return
	elapsed += delta
	hurt_lock = maxf(0.0, hurt_lock - delta)
	if elapsed >= ROUND_TIME:
		_end_game(false, "訊號窗口關閉！\n任務失敗，按 R 再試一次")
		return
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis += 1.0
	player.velocity.x = axis * MOVE_SPEED
	player.velocity.y += GRAVITY * delta
	var jump_down := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	if jump_down and not jump_was_down and player.is_on_floor():
		player.velocity.y = JUMP_SPEED
	jump_was_down = jump_down
	player.move_and_slide()
	player.position.x = clampf(player.position.x, 12.0, 948.0)
	if player.position.y > 560.0:
		_lose_life("跌出平台")
	for drone in drones:
		if drone["disabled"] > 0.0:
			drone["disabled"] = maxf(0.0, float(drone["disabled"]) - delta)
		else:
			var p: Vector2 = drone["pos"]
			p.x += float(drone["dir"]) * float(drone["speed"]) * delta
			if p.x < float(drone["start"]): p.x = float(drone["start"]); drone["dir"] = 1.0
			if p.x > float(drone["end"]): p.x = float(drone["end"]); drone["dir"] = -1.0
			drone["pos"] = p
		if float(drone["disabled"]) <= 0.0 and hurt_lock <= 0.0 and player.position.distance_to(drone["pos"]) < 25.0:
			_lose_life("撞到巡邏無人機")
	for shard in shards:
		if not bool(shard["taken"]) and player.position.distance_to(shard["pos"]) < 30.0:
			shard["taken"] = true
			collected += 1
			message_label.text = "取得訊號核心 %d/5" % collected
			get_tree().create_timer(1.1).timeout.connect(func(): _clear_message())
	if Input.is_key_just_pressed(KEY_E):
		_emp_pulse()
	if player.position.distance_to(portal_pos) < 38.0:
		if collected >= shards.size():
			_end_game(true, "撤離成功！\n5 枚訊號核心已回收。\n按 R 再玩一次")
		else:
			message_label.text = "傳送門尚未穩定：還差 %d 枚核心" % (shards.size() - collected)
	_update_hud()
	queue_redraw()

func _emp_pulse() -> void:
	for drone in drones:
		if player.position.distance_to(drone["pos"]) < 170.0:
			drone["disabled"] = 2.5
	message_label.text = "EMP 脈衝已發射！"
	get_tree().create_timer(0.8).timeout.connect(func(): _clear_message())

func _lose_life(reason: String) -> void:
	if hurt_lock > 0.0: return
	lives -= 1
	hurt_lock = 1.2
	player.position = Vector2(50, 455)
	player.velocity = Vector2.ZERO
	message_label.text = reason + "！剩餘生命：%d" % lives
	if lives <= 0:
		_end_game(false, "任務失敗！\n按 R 重新開始")

func _end_game(won: bool, text: String) -> void:
	game_state = "won" if won else "lost"
	message_label.text = text
	_update_hud()

func _clear_message() -> void:
	if is_instance_valid(message_label) and game_state == "playing": message_label.text = ""

func _restart() -> void:
	get_tree().reload_current_scene()

func _update_hud() -> void:
	if is_instance_valid(hud):
		hud.text = "KROLL PORTAL COURIER   核心 %d/5   生命 %d   時間 %02d" % [collected, lives, maxi(0, int(ROUND_TIME - elapsed))]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("171c27"))
	# Backrooms-style distant light panels.
	for i in range(8):
		var x := 25.0 + i * 125.0
		draw_rect(Rect2(x, 70, 72, 5), Color(0.65, 0.72, 0.46, 0.22))
		draw_rect(Rect2(x, 75, 2, 190), Color(0.55, 0.62, 0.44, 0.08))
	for platform in platforms:
		var rect: Rect2 = platform["rect"]
		draw_rect(rect, platform["color"])
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 4), Color("d4cba6"))
	for shard in shards:
		if not bool(shard["taken"]):
			var p: Vector2 = shard["pos"]
			draw_circle(p, 10, Color("f8d95a"))
			draw_circle(p, 5, Color("fff7b2"))
	for drone in drones:
		var p: Vector2 = drone["pos"]
		if float(drone["disabled"]) > 0.0:
			draw_circle(p, 17, Color(0.2, 0.85, 1.0, 0.24))
			draw_rect(Rect2(p.x-12, p.y-8, 24, 16), Color("68e5f2"))
		else:
			draw_circle(p, 16, Color("d74752"))
			draw_circle(p + Vector2(4,-2), 4, Color("fff1d2"))
			draw_line(p + Vector2(-18, 0), p + Vector2(-10, 0), Color("ff8b83"), 3)
			draw_line(p + Vector2(10, 0), p + Vector2(18, 0), Color("ff8b83"), 3)
	var portal_color := Color("3a899b") if collected < shards.size() else Color("65f0d0")
	draw_arc(portal_pos, 29, 0.0, TAU, 48, portal_color, 7.0, true)
	draw_arc(portal_pos, 20, 0.0, TAU, 48, Color(portal_color.r, portal_color.g, portal_color.b, 0.45), 3.0, true)
	draw_line(portal_pos + Vector2(0,-17), portal_pos + Vector2(0,17), portal_color, 2)
	draw_line(portal_pos + Vector2(-13,0), portal_pos + Vector2(13,0), portal_color, 2)
	if hurt_lock > 0.0 and int(Time.get_ticks_msec() / 100) % 2 == 0:
		draw_circle(player.position, 24, Color(1, 1, 1, 0.2))
