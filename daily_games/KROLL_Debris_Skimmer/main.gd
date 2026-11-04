extends Control

const Rules = preload("res://rules.gd")

var sector_index: int = 0
var ship_position: Vector2 = Rules.DOCK_POSITION + Vector2(38.0, 0.0)
var ship_velocity: Vector2 = Vector2.ZERO
var ship_heading: float = 0.0
var hull: int = 3
var carried: int = 0
var delivered: int = 0
var score: int = 0
var _cargo: Array[Dictionary] = []
var _asteroids: Array[Dictionary] = []
var _cleared: Dictionary = {}
var _actions: Dictionary = {"left":false,"right":false,"thrust":false,"reverse":false}
var _invulnerability: float = 0.0
var _tractor_flash: float = 0.0
var _tractor_target: Vector2 = Vector2.ZERO
var _message: String = ""
var _message_timer: float = 0.0
var _game_over: bool = false
var _campaign_complete: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_controls()
	restart_campaign()

func _build_controls() -> void:
	var specs: Array[Dictionary] = [
		{"name":"Retry","text":"R","mode":"retry","x":910.0,"y":40.0,"width":52.0,"height":40.0},
		{"name":"Next","text":"N","mode":"next","x":968.0,"y":40.0,"width":52.0,"height":40.0},
		{"name":"Campaign","text":"C","mode":"campaign","x":1026.0,"y":40.0,"width":52.0,"height":40.0},
		{"name":"TurnLeft","text":"A / TURN L","action":"left","mode":"hold","x":24.0,"y":636.0,"width":145.0},
		{"name":"Thrust","text":"W / THRUST","action":"thrust","mode":"hold","x":180.0,"y":636.0,"width":145.0},
		{"name":"TurnRight","text":"D / TURN R","action":"right","mode":"hold","x":336.0,"y":636.0,"width":145.0},
		{"name":"Reverse","text":"S / BRAKE","action":"reverse","mode":"hold","x":492.0,"y":636.0,"width":135.0},
		{"name":"Tractor","text":"TRACTOR","mode":"tractor","x":640.0,"y":636.0,"width":135.0},
		{"name":"Dock","text":"E / DOCK","mode":"dock","x":788.0,"y":636.0,"width":135.0}
	]
	for spec in specs:
		var button := Button.new()
		button.name = "Control_" + str(spec["name"])
		button.text = str(spec["text"])
		button.position = Vector2(float(spec["x"]), float(spec.get("y", 636.0)))
		button.size = Vector2(float(spec["width"]), float(spec.get("height", 52.0)))
		button.focus_mode = Control.FOCUS_NONE
		add_child(button)
		match str(spec["mode"]):
			"hold":
				var action := str(spec["action"])
				button.button_down.connect(_set_action.bind(action, true))
				button.button_up.connect(_set_action.bind(action, false))
			"tractor":
				button.pressed.connect(activate_tractor)
			"dock":
				button.pressed.connect(dock_cargo)
			"retry":
				button.pressed.connect(restart_current_sector)
			"next":
				button.pressed.connect(next_sector)
			"campaign":
				button.pressed.connect(restart_campaign)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
		_set_action("left", key_event.pressed)
	elif key_event.keycode == KEY_D or key_event.keycode == KEY_RIGHT:
		_set_action("right", key_event.pressed)
	elif key_event.keycode == KEY_W or key_event.keycode == KEY_UP:
		_set_action("thrust", key_event.pressed)
	elif key_event.keycode == KEY_S or key_event.keycode == KEY_DOWN:
		_set_action("reverse", key_event.pressed)
	elif key_event.pressed and not key_event.echo:
		match key_event.keycode:
			KEY_SPACE:
				activate_tractor()
			KEY_E, KEY_ENTER:
				dock_cargo()
			KEY_R:
				restart_current_sector()
			KEY_N:
				next_sector()
			KEY_C:
				restart_campaign()

func _set_action(action: String, pressed: bool) -> void:
	if _actions.has(action):
		_actions[action] = pressed

func _physics_process(delta: float) -> void:
	if _game_over or _campaign_complete:
		return
	var turn := float(int(bool(_actions["right"])) - int(bool(_actions["left"])))
	var movement: Dictionary = Rules.integrate_ship(ship_position, ship_velocity, ship_heading, turn, bool(_actions["thrust"]), bool(_actions["reverse"]), delta)
	ship_position = movement["position"]
	ship_velocity = movement["velocity"]
	ship_heading = float(movement["heading"])
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_tractor_flash = maxf(0.0, _tractor_flash - delta)
	_message_timer = maxf(0.0, _message_timer - delta)
	_update_asteroids(delta)
	_check_collisions()
	queue_redraw()

func _update_asteroids(delta: float) -> void:
	for index in range(_asteroids.size()):
		var asteroid: Dictionary = _asteroids[index]
		var position: Vector2 = asteroid["position"]
		var velocity: Vector2 = asteroid["velocity"]
		asteroid["position"] = Rules.wrap_position(position + velocity * delta)
		_asteroids[index] = asteroid

func _check_collisions() -> void:
	if _invulnerability > 0.0:
		return
	for asteroid in _asteroids:
		var position: Vector2 = asteroid["position"]
		if ship_position.distance_to(position) <= float(asteroid["radius"]) + 14.0:
			hull = maxi(0, hull - 1)
			_invulnerability = 1.15
			ship_velocity *= -0.28
			_set_message("HULL IMPACT — " + str(hull) + " integrity left")
			if hull <= 0:
				_game_over = true
				_set_message("SHIP DISABLED — press R to retry")
			return

func activate_tractor() -> bool:
	if _game_over or _campaign_complete:
		return false
	var best_index := -1
	var best_distance := Rules.TRACTOR_RANGE
	for index in range(_cargo.size()):
		if bool(_cargo[index]["collected"]):
			continue
		var cargo_position: Vector2 = _cargo[index]["position"]
		var distance := ship_position.distance_to(cargo_position)
		if distance <= best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0:
		_set_message("NO SALVAGE IN TRACTOR RANGE")
		return false
	_tractor_target = _cargo[best_index]["position"]
	_cargo[best_index]["collected"] = true
	carried += 1
	_tractor_flash = 0.22
	_set_message("SALVAGE SECURED — " + str(carried) + " aboard")
	queue_redraw()
	return true

func dock_cargo() -> bool:
	if _game_over or _campaign_complete or not Rules.can_dock(ship_position) or carried <= 0:
		_set_message("RETURN TO DOCK WITH CARGO")
		return false
	delivered += carried
	carried = 0
	_set_message("DELIVERED — " + str(delivered) + " / " + str(get_sector_target()))
	if Rules.sector_complete(delivered, get_sector_target()):
		_complete_sector()
	queue_redraw()
	return true

func _complete_sector() -> void:
	if not bool(_cleared.get(sector_index, false)):
		score += Rules.clear_reward(false)
		_cleared[sector_index] = true
	if sector_index >= Rules.sector_count() - 1:
		_campaign_complete = true
		_set_message("CAMPAIGN COMPLETE — " + str(score) + " / 300")
	else:
		_set_message("SECTOR SECURED — press N for the next route")

func next_sector() -> bool:
	if not Rules.sector_complete(delivered, get_sector_target()) or sector_index >= Rules.sector_count() - 1:
		return false
	sector_index += 1
	_start_sector()
	return true

func restart_current_sector() -> void:
	_start_sector()

func restart_campaign() -> void:
	sector_index = 0
	score = 0
	_cleared.clear()
	_campaign_complete = false
	_start_sector()

func _start_sector() -> void:
	var data: Dictionary = Rules.sector_data(sector_index)
	ship_position = Rules.DOCK_POSITION + Vector2(38.0, 0.0)
	ship_velocity = Vector2.ZERO
	ship_heading = 0.0
	hull = 3
	carried = 0
	delivered = 0
	_invulnerability = 0.0
	_tractor_flash = 0.0
	_game_over = false
	_campaign_complete = false
	_cargo.clear()
	_asteroids.clear()
	for position in data.get("cargo_positions", []):
		_cargo.append({"position":position,"collected":false})
	for asteroid in data.get("asteroids", []):
		_asteroids.append(asteroid.duplicate(true))
	_set_message("Collect salvage with TRACTOR, then return to DOCK")

func _set_message(value: String) -> void:
	_message = value
	_message_timer = 2.5

func get_remaining_cargo_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cargo in _cargo:
		if not bool(cargo["collected"]):
			result.append(cargo["position"])
	return result

func get_sector_target() -> int:
	return int(Rules.sector_data(sector_index).get("target", 0))

func get_sector_index() -> int:
	return sector_index

func get_delivered_count() -> int:
	return delivered

func get_carried_count() -> int:
	return carried

func get_hull() -> int:
	return hull

func get_score() -> int:
	return score

func is_game_over() -> bool:
	return _game_over

func is_campaign_complete() -> bool:
	return _campaign_complete

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.035, 0.060), true)
	draw_string(font, Vector2(28,38), "KROLL / DEBRIS SKIMMER", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.45,0.88,1.0))
	var sector_data: Dictionary = Rules.sector_data(sector_index)
	draw_string(font, Vector2(360,36), "SECTOR " + str(sector_index + 1) + " / 3   " + str(sector_data.get("name","")), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.78,0.88,0.94))
	draw_string(font, Vector2(750,36), "SCORE " + str(score) + " / 300", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98,0.78,0.36))
	draw_rect(Rules.FIELD_RECT, Color(0.035,0.085,0.12), true)
	draw_rect(Rules.FIELD_RECT, Color(0.16,0.34,0.42), false, 2.0)
	for x in range(64, 1076, 64):
		draw_line(Vector2(x,76), Vector2(x,576), Color(0.10,0.18,0.23,0.55), 1.0)
	for y in range(116, 576, 40):
		draw_line(Vector2(24,y), Vector2(1076,y), Color(0.10,0.18,0.23,0.55), 1.0)
	draw_circle(Rules.DOCK_POSITION, Rules.DOCK_RADIUS, Color(0.08,0.28,0.31,0.45))
	draw_arc(Rules.DOCK_POSITION, Rules.DOCK_RADIUS, 0.0, PI * 2.0, 48, Color(0.26,0.92,0.72), 3.0)
	draw_circle(Rules.DOCK_POSITION, 10.0, Color(0.35,1.0,0.78))
	draw_string(font, Rules.DOCK_POSITION + Vector2(-25,82), "DOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.45,1.0,0.82))
	for cargo in _cargo:
		if bool(cargo["collected"]):
			continue
		var cargo_position: Vector2 = cargo["position"]
		draw_rect(Rect2(cargo_position - Vector2(10,10), Vector2(20,20)), Color(1.0,0.72,0.28), true)
		draw_rect(Rect2(cargo_position - Vector2(10,10), Vector2(20,20)), Color(1.0,0.92,0.62), false, 2.0)
	for asteroid in _asteroids:
		var asteroid_position: Vector2 = asteroid["position"]
		var radius: float = float(asteroid["radius"])
		draw_circle(asteroid_position, radius, Color(0.36,0.40,0.46))
		draw_arc(asteroid_position, radius, 0.0, PI * 2.0, 24, Color(0.68,0.75,0.82), 2.0)
	if _tractor_flash > 0.0:
		draw_line(ship_position, _tractor_target, Color(0.30,0.94,1.0,0.85), 4.0)
	var forward := Vector2.RIGHT.rotated(ship_heading)
	var side := Vector2(-forward.y, forward.x)
	var ship_points := PackedVector2Array([ship_position + forward * 21.0, ship_position - forward * 15.0 + side * 12.0, ship_position - forward * 15.0 - side * 12.0])
	draw_colored_polygon(ship_points, Color(0.36,0.86,1.0) if _invulnerability <= 0.0 else Color(1.0,0.62,0.35))
	draw_polyline(PackedVector2Array([ship_points[0],ship_points[1],ship_points[2],ship_points[0]]), Color(0.92,0.98,1.0), 2.0)
	var progress := "DELIVERED " + str(delivered) + " / " + str(get_sector_target()) + "    CARGO " + str(carried) + "    HULL " + str(hull) + "    SPEED " + str(roundi(ship_velocity.length()))
	draw_string(font, Vector2(30,604), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.82,0.92,0.97))
	if _message_timer > 0.0 or _game_over or _campaign_complete:
		draw_string(font, Vector2(30,626), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0,0.80,0.43))
	if _game_over:
		draw_rect(Rect2(350,240,400,110), Color(0.04,0.06,0.09,0.92), true)
		draw_string(font, Vector2(390,286), "SHIP DISABLED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0,0.55,0.38))
		draw_string(font, Vector2(390,322), "Press R to retry this sector", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95,0.95,0.95))
	elif _campaign_complete:
		draw_rect(Rect2(350,240,400,110), Color(0.04,0.06,0.09,0.92), true)
		draw_string(font, Vector2(390,286), "SALVAGE CAMPAIGN CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.36,1.0,0.76))
		draw_string(font, Vector2(390,322), "300 points — press C to replay", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95,0.95,0.95))
