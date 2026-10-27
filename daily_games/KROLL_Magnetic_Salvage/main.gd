extends Node2D

const Rules = preload("res://rules.gd")
const ARENA := Vector2(960.0, 600.0)
const START_POSITION := Vector2(70.0, 300.0)
const DOCK_POSITION := Vector2(880.0, 300.0)
const MOVE_SPEED: float = 220.0
const MAGNET_RANGE: float = 175.0
const MAGNET_PULL: float = 72.0
const TARGET_PARTS: int = 6
const MAX_CHARGE: int = 6
const ROUND_SECONDS: float = 75.0

var player_position: Vector2 = START_POSITION
var scraps: Array[Vector2] = []
var hazards: Array[Vector2] = []
var parts_collected: int = 0
var charge: int = MAX_CHARGE
var time_left: float = ROUND_SECONDS
var state: String = "playing"
var pulse_cooldown: float = 0.0
var charge_regen_timer: float = 0.0
var hazard_lockout: float = 0.0
var message: String = "Collect six metal parts, then return to the dock."
var _touch_layer: CanvasLayer

func _ready() -> void:
	restart_game()
	_build_touch_controls()

func restart_game() -> void:
	player_position = START_POSITION
	scraps = [
		Vector2(190, 160), Vector2(220, 440), Vector2(330, 250),
		Vector2(430, 410), Vector2(540, 170), Vector2(610, 350),
		Vector2(720, 440), Vector2(760, 220)
	]
	hazards = [Vector2(290, 340), Vector2(490, 300), Vector2(690, 330)]
	parts_collected = 0
	charge = MAX_CHARGE
	time_left = ROUND_SECONDS
	state = "playing"
	pulse_cooldown = 0.0
	charge_regen_timer = 0.0
	hazard_lockout = 0.0
	message = "Collect six metal parts, then return to the dock."
	queue_redraw()

func _process(delta: float) -> void:
	if state != "playing":
		queue_redraw()
		return
	time_left = maxf(0.0, time_left - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	hazard_lockout = maxf(0.0, hazard_lockout - delta)
	charge_regen_timer += delta
	while charge_regen_timer >= 2.5 and charge < MAX_CHARGE:
		charge += 1
		charge_regen_timer -= 2.5
	if time_left <= 0.0:
		state = "lost"
		message = "Shift expired. Press R to retry."
		queue_redraw()
		return

	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction.length_squared() > 0.0:
		player_position = Rules.clamp_to_arena(player_position + direction.normalized() * MOVE_SPEED * delta, ARENA, 28.0)

	if hazard_lockout <= 0.0:
		for hazard in hazards:
			if player_position.distance_to(hazard) < 25.0:
				charge = maxi(0, charge - 1)
				hazard_lockout = 1.0
				player_position = START_POSITION
				message = "Debris impact: one charge lost."
				break
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			restart_game()
		elif event.keycode == KEY_SPACE:
			try_extract()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		apply_magnet_pulse()

func apply_magnet_pulse() -> bool:
	if not Rules.can_pulse(charge, pulse_cooldown, state):
		return false
	charge -= 1
	pulse_cooldown = 0.35
	var collected_now := 0
	for i in range(scraps.size() - 1, -1, -1):
		var before: Vector2 = scraps[i]
		var after: Vector2 = Rules.pulled_position(before, player_position, MAGNET_RANGE, MAGNET_PULL)
		if Rules.is_collected(after, player_position):
			scraps.remove_at(i)
			parts_collected += 1
			collected_now += 1
			charge = mini(MAX_CHARGE, charge + 1)
		else:
			scraps[i] = after
	if collected_now > 0:
		message = "Recovered %d part(s). Return to the extraction dock." % collected_now
	else:
		message = "Magnetic pulse sent. Move closer to loose metal."
	queue_redraw()
	return true

func try_extract() -> bool:
	if Rules.can_extract(parts_collected, player_position, DOCK_POSITION, 54.0, state):
		state = "won"
		message = "SALVAGE SECURED — press R for another shift."
		queue_redraw()
		return true
	if parts_collected < TARGET_PARTS:
		message = "Need %d more part(s) before docking." % (TARGET_PARTS - parts_collected)
	else:
		message = "Move into the glowing dock ring to extract."
	queue_redraw()
	return false

func nudge_player(direction: Vector2) -> void:
	if state != "playing":
		return
	player_position = Rules.clamp_to_arena(player_position + direction.normalized() * 42.0, ARENA, 28.0)
	queue_redraw()

func get_state_snapshot() -> Dictionary:
	return {
		"state": state,
		"parts_collected": parts_collected,
		"parts_remaining": scraps.size(),
		"charge": charge,
		"time_left": time_left,
		"player_position": player_position,
		"message": message
	}

func _build_touch_controls() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_touch_layer = CanvasLayer.new()
	_touch_layer.name = "TouchControls"
	add_child(_touch_layer)
	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12.0
	panel.offset_right = -12.0
	panel.offset_top = -66.0
	panel.offset_bottom = -6.0
	_touch_layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_add_touch_button(row, "↑", Vector2(52, 44), func(): nudge_player(Vector2.UP))
	_add_touch_button(row, "←", Vector2(52, 44), func(): nudge_player(Vector2.LEFT))
	_add_touch_button(row, "↓", Vector2(52, 44), func(): nudge_player(Vector2.DOWN))
	_add_touch_button(row, "→", Vector2(52, 44), func(): nudge_player(Vector2.RIGHT))
	_add_touch_button(row, "PULSE", Vector2(110, 44), func(): apply_magnet_pulse())
	_add_touch_button(row, "DOCK", Vector2(90, 44), func(): try_extract())
	_add_touch_button(row, "RESET", Vector2(90, 44), func(): restart_game())

func _add_touch_button(parent: HBoxContainer, label_text: String, button_size: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = button_size
	button.pressed.connect(action)
	parent.add_child(button)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color("#07131e"), true)
	for x in range(30, 960, 30):
		draw_line(Vector2(x, 0), Vector2(x, 600), Color(0.10, 0.22, 0.29, 0.35), 1.0)
	for y in range(30, 600, 30):
		draw_line(Vector2(0, y), Vector2(960, y), Color(0.10, 0.22, 0.29, 0.35), 1.0)
	draw_rect(Rect2(Vector2(12, 12), Vector2(936, 576)), Color(0.12, 0.36, 0.45, 0.8), false, 3.0)
	draw_circle(DOCK_POSITION, 54.0, Color(0.10, 0.95, 0.70, 0.12))
	draw_arc(DOCK_POSITION, 54.0, 0.0, TAU, 48, Color("#39f4b6"), 3.0)
	draw_string(ThemeDB.fallback_font, DOCK_POSITION + Vector2(-38, 5), "DOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9bffe1"))
	for hazard in hazards:
		draw_circle(hazard, 21.0, Color(0.92, 0.19, 0.25, 0.22))
		draw_arc(hazard, 21.0, 0.0, TAU, 24, Color("#ff5265"), 2.0)
		draw_line(hazard + Vector2(-8, -8), hazard + Vector2(8, 8), Color("#ff5265"), 2.0)
		draw_line(hazard + Vector2(-8, 8), hazard + Vector2(8, -8), Color("#ff5265"), 2.0)
	for scrap in scraps:
		draw_circle(scrap, 10.0, Color("#f6c85f"))
		draw_arc(scrap, 14.0, 0.0, TAU, 18, Color("#ffe8a1"), 2.0)
	draw_circle(player_position, 17.0, Color("#5bd8ff"))
	draw_arc(player_position, 24.0, 0.0, TAU, 28, Color("#a4efff"), 2.0)
	draw_line(player_position, player_position + Vector2(0, -22), Color.WHITE, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(24, 36), "KROLL MAGNETIC SALVAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#b8f3ff"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 64), "PARTS %d/%d   CHARGE %d/%d   TIME %02d" % [parts_collected, TARGET_PARTS, charge, MAX_CHARGE, ceili(time_left)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e7f7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 88), "WASD move | click/PULSE magnet | Space/DOCK extract | R/RESET restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8eb3c5"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 116), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f5d58b"))
	if state != "playing":
		draw_rect(Rect2(Vector2(240, 220), Vector2(480, 110)), Color(0.02, 0.06, 0.10, 0.92), true)
		draw_string(ThemeDB.fallback_font, Vector2(340, 270), "SALVAGE COMPLETE" if state == "won" else "SHIFT FAILED", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#b8f3ff"))
		draw_string(ThemeDB.fallback_font, Vector2(330, 305), "Press R or RESET to restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
