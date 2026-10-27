extends Node2D

const Rules = preload("res://rules.gd")
const PLAYER_HALF := Vector2(13.0, 18.0)
const MOVE_SPEED := 245.0
const GRAVITY := 1320.0
const JUMP_SPEED := -555.0
const PLATFORM_DATA = [
	[0.0, 570.0, 960.0, 70.0],
	[170.0, 485.0, 150.0, 16.0],
	[360.0, 410.0, 140.0, 16.0],
	[545.0, 335.0, 150.0, 16.0],
	[700.0, 425.0, 125.0, 16.0],
	[820.0, 500.0, 100.0, 16.0]
]
const CELL_DATA = [
	[230.0, 458.0],
	[420.0, 383.0],
	[600.0, 308.0],
	[745.0, 398.0],
	[865.0, 473.0]
]
const VENT_DATA = [
	[280.0, 550.0, 44.0, 20.0],
	[600.0, 315.0, 42.0, 20.0]
]

var platforms: Array[Rect2] = []
var cell_positions: Array[Vector2] = []
var cell_active: Array[bool] = []
var vents: Array[Rect2] = []
var hazards: Array[Dictionary] = []
var player_position := Vector2(70.0, 535.0)
var velocity := Vector2.ZERO
var state: Dictionary = {}
var grounded := false
var jump_requested := false
var touch_left := false
var touch_right := false
var invulnerability_left := 0.0
var vent_cooldown := 0.0
var notice := "Collect all five power cells, then reach the extraction hatch."

func _ready() -> void:
	for data in PLATFORM_DATA:
		platforms.append(Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3])))
	for data in CELL_DATA:
		cell_positions.append(Vector2(float(data[0]), float(data[1])))
	for data in VENT_DATA:
		vents.append(Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3])))
	_restart_game()

func _process(delta: float) -> void:
	_step_game(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP:
			jump_requested = true
		elif event.keycode == KEY_R:
			_restart_game()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_control_press(event.position)
		else:
			touch_left = false
			touch_right = false
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_control_press(event.position)
		else:
			touch_left = false
			touch_right = false

func _handle_control_press(position: Vector2) -> void:
	if position.y >= 590.0:
		if position.x < 155.0:
			touch_left = true
		elif position.x < 310.0:
			jump_requested = true
		elif position.x < 465.0:
			touch_right = true
		elif position.x >= 790.0:
			_restart_game()
	elif position.x >= 790.0 and position.y < 70.0:
		_restart_game()

func _step_game(delta: float) -> void:
	if str(state.get("status", "")) != "playing":
		return
	Rules.tick(state, delta)
	if str(state.get("status", "")) != "playing":
		notice = "Run ended. Press R or RESET to try again."
		return

	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	vent_cooldown = maxf(0.0, vent_cooldown - delta)
	_update_hazards(delta)

	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch_left:
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch_right:
		direction += 1.0
	velocity.x = direction * MOVE_SPEED
	if jump_requested and grounded:
		velocity.y = JUMP_SPEED
		grounded = false
	jump_requested = false

	var previous_y := player_position.y
	player_position.x = clampf(player_position.x + velocity.x * delta, PLAYER_HALF.x, 960.0 - PLAYER_HALF.x)
	player_position.y += velocity.y * delta
	velocity.y += GRAVITY * delta
	grounded = false
	_resolve_platform_collisions(previous_y)

	if player_position.y > 700.0:
		_take_hit("You fell into the shaft.")
	if invulnerability_left <= 0.0:
		for hazard in hazards:
			var hazard_rect := Rect2(Vector2(float(hazard["x"]) - 17.0, float(hazard["y"]) - 12.0), Vector2(34.0, 24.0))
			if _player_rect().intersects(hazard_rect):
				_take_hit("Hazard impact. Keep moving.")
				break

	_collect_nearby_cells()
	_apply_vent_boost()
	_try_exit()

func _resolve_platform_collisions(previous_y: float) -> void:
	var previous_bottom := previous_y + PLAYER_HALF.y
	var previous_top := previous_y - PLAYER_HALF.y
	var current_bottom := player_position.y + PLAYER_HALF.y
	var current_top := player_position.y - PLAYER_HALF.y
	for platform in platforms:
		var horizontal_overlap := player_position.x + PLAYER_HALF.x > platform.position.x and player_position.x - PLAYER_HALF.x < platform.end.x
		if not horizontal_overlap:
			continue
		if velocity.y >= 0.0 and previous_bottom <= platform.position.y + 2.0 and current_bottom >= platform.position.y:
			player_position.y = platform.position.y - PLAYER_HALF.y
			velocity.y = 0.0
			grounded = true
			current_bottom = player_position.y + PLAYER_HALF.y
		elif velocity.y < 0.0 and previous_top >= platform.end.y - 2.0 and current_top <= platform.end.y:
			player_position.y = platform.end.y + PLAYER_HALF.y
			velocity.y = 0.0
			current_top = player_position.y - PLAYER_HALF.y

func _update_hazards(delta: float) -> void:
	for index in range(hazards.size()):
		var hazard: Dictionary = hazards[index]
		var next_x := float(hazard["x"]) + float(hazard["direction"]) * float(hazard["speed"]) * delta
		if next_x < float(hazard["min_x"]):
			next_x = float(hazard["min_x"])
			hazard["direction"] = 1.0
		elif next_x > float(hazard["max_x"]):
			next_x = float(hazard["max_x"])
			hazard["direction"] = -1.0
		hazard["x"] = next_x
		hazards[index] = hazard

func _take_hit(message: String) -> void:
	if invulnerability_left > 0.0 or str(state.get("status", "")) != "playing":
		return
	Rules.hit_hazard(state)
	invulnerability_left = 1.15
	player_position = Vector2(70.0, 535.0)
	velocity = Vector2.ZERO
	grounded = false
	notice = message
	if str(state.get("status", "")) == "lost":
		notice = "HULL BREACH — press R to restart."

func _collect_nearby_cells() -> void:
	if str(state.get("status", "")) != "playing":
		return
	for index in range(cell_positions.size()):
		if cell_active[index] and player_position.distance_to(cell_positions[index]) <= 29.0:
			if Rules.collect_cell(state):
				cell_active[index] = false
				notice = "Power cell secured. %d / %d" % [int(state["cells_collected"]), Rules.REQUIRED_CELLS]

func _apply_vent_boost() -> void:
	if not grounded or vent_cooldown > 0.0:
		return
	for vent in vents:
		if player_position.x + PLAYER_HALF.x > vent.position.x and player_position.x - PLAYER_HALF.x < vent.end.x and player_position.y + PLAYER_HALF.y >= vent.position.y:
			velocity.y = JUMP_SPEED * 1.18
			grounded = false
			vent_cooldown = 0.85
			notice = "VENT BOOST!"
			return

func _try_exit() -> void:
	if player_position.x >= 900.0 and player_position.y >= 500.0:
		if Rules.try_exit(state):
			notice = "EXTRACTION SUCCESS — press R to run again."
		else:
			notice = "Hatch locked: collect all five power cells."

func _player_rect() -> Rect2:
	return Rect2(player_position - PLAYER_HALF, PLAYER_HALF * 2.0)

func _restart_game() -> void:
	state = Rules.new_state()
	player_position = Vector2(70.0, 535.0)
	velocity = Vector2.ZERO
	grounded = false
	jump_requested = false
	touch_left = false
	touch_right = false
	invulnerability_left = 0.0
	vent_cooldown = 0.0
	cell_active.clear()
	for _cell in cell_positions:
		cell_active.append(true)
	hazards = [
		{"x": 425.0, "y": 550.0, "min_x": 365.0, "max_x": 525.0, "direction": 1.0, "speed": 108.0},
		{"x": 425.0, "y": 392.0, "min_x": 370.0, "max_x": 485.0, "direction": -1.0, "speed": 78.0}
	]
	notice = "Collect all five power cells, then reach the extraction hatch."

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 640.0)), Color("#06111b"))
	for x in range(0, 960, 40):
		draw_line(Vector2(float(x), 55.0), Vector2(float(x), 590.0), Color("#102434"), 1.0)
	for y in range(60, 590, 40):
		draw_line(Vector2(0.0, float(y)), Vector2(960.0, float(y)), Color("#102434"), 1.0)
	draw_rect(Rect2(0.0, 0.0, 960.0, 54.0), Color("#0d2232"))
	draw_string(ThemeDB.fallback_font, Vector2(24.0, 34.0), "KROLL / VENT RUNNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("#7ceeff"))
	draw_string(ThemeDB.fallback_font, Vector2(385.0, 32.0), "CELLS %d/%d   LIVES %d   TIME %02d   SCORE %d" % [int(state.get("cells_collected", 0)), Rules.REQUIRED_CELLS, int(state.get("lives", Rules.STARTING_LIVES)), int(ceil(float(state.get("time_left", Rules.TIME_LIMIT)))), int(state.get("score", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d3e8f2"))
	draw_rect(Rect2(800.0, 9.0, 130.0, 36.0), Color("#27495b"))
	draw_string(ThemeDB.fallback_font, Vector2(830.0, 32.0), "RESET  R", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	for platform in platforms:
		draw_rect(platform, Color("#29475a"))
		draw_rect(Rect2(platform.position.x, platform.position.y, platform.size.x, 4.0), Color("#70dce8"))
	for vent in vents:
		draw_rect(vent, Color("#124c59"))
		for stripe in range(3):
			var sx := vent.position.x + 7.0 + float(stripe) * 12.0
			draw_line(Vector2(sx, vent.position.y + 3.0), Vector2(sx, vent.end.y - 3.0), Color("#76f6ff"), 3.0)
	for index in range(cell_positions.size()):
		if cell_active[index]:
			var cell := cell_positions[index]
			draw_circle(cell, 11.0, Color("#ffcf70"))
			draw_circle(cell, 5.0, Color("#fff3bf"))
	for hazard in hazards:
		var hazard_center := Vector2(float(hazard["x"]), float(hazard["y"]))
		draw_circle(hazard_center, 15.0, Color("#a42f51"))
		draw_circle(hazard_center, 6.0, Color("#ff6c86"))
	draw_rect(Rect2(900.0, 515.0, 45.0, 55.0), Color("#176d63"))
	draw_rect(Rect2(907.0, 522.0, 31.0, 41.0), Color("#59f0c1"))
	var player_color := Color("#78efff") if invulnerability_left <= 0.0 or int(Time.get_ticks_msec() / 90) % 2 == 0 else Color("#ffffff")
	draw_rect(_player_rect(), player_color)
	draw_rect(Rect2(player_position.x - 7.0, player_position.y - 11.0, 14.0, 8.0), Color("#143047"))
	if str(state.get("status", "")) != "playing":
		draw_rect(Rect2(245.0, 235.0, 470.0, 105.0), Color("#0a1a28"))
		var result_text := "EXTRACTION COMPLETE" if str(state.get("status", "")) == "won" else "RUN FAILED"
		draw_string(ThemeDB.fallback_font, Vector2(325.0, 280.0), result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#7fffd5") if str(state.get("status", "")) == "won" else Color("#ff7188"))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 615.0), notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c5d9e5"))
	_draw_control_button(Rect2(22.0, 590.0, 125.0, 42.0), "LEFT")
	_draw_control_button(Rect2(158.0, 590.0, 125.0, 42.0), "JUMP")
	_draw_control_button(Rect2(294.0, 590.0, 125.0, 42.0), "RIGHT")
	_draw_control_button(Rect2(805.0, 590.0, 125.0, 42.0), "RESET")

func _draw_control_button(rect: Rect2, label: String) -> void:
	draw_rect(rect, Color("#18394b"))
	draw_rect(rect, Color("#5b9fb3"), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(30.0, 27.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e1f8ff"))
