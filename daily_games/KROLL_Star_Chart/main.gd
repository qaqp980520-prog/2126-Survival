extends Node2D

const MISSION_COUNT: int = 3
const MIN_ZOOM: int = 0
const MAX_ZOOM: int = 4

var rules: Variant

var mission_index: int = 0
var target_index: int = 0
var aim: Vector2 = Vector2(0.5, 0.5)
var zoom_level: int = 1
var time_left: float = 75.0
var score: int = 0
var status_text: String = "ALIGN THE RETICLE WITH THE NEXT STAR"
var mission_complete: bool = false
var campaign_complete: bool = false
var failed: bool = false

func _ready() -> void:
	var rules_path: String = "res://rules.gd"
	if not ResourceLoader.exists(rules_path):
		rules_path = "res://daily_games/KROLL_Star_Chart/rules.gd"
	rules = load(rules_path)
	if rules == null:
		push_error("KROLL Star Chart could not load its rules module.")
		set_process(false)
		return
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not mission_complete and not failed:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			failed = true
			status_text = "SIGNAL WINDOW CLOSED · PRESS R TO RETRY"
	queue_redraw()

func get_current_mission() -> Dictionary:
	return rules.get_mission(mission_index)

func set_aim(value: Vector2) -> void:
	aim = rules.clamp_aim(value)
	queue_redraw()

func attempt_lock() -> bool:
	if mission_complete or failed:
		return false
	var mission: Dictionary = get_current_mission()
	var targets: Array = mission.get("targets", [])
	if target_index >= targets.size():
		return false
	var target: Vector2 = targets[target_index]
	if not rules.can_lock(aim, target, zoom_level):
		status_text = "NO LOCK · ADJUST AZIMUTH / ELEVATION"
		time_left = maxf(0.0, time_left - 1.5)
		if time_left <= 0.0:
			failed = true
			status_text = "SIGNAL WINDOW CLOSED · PRESS R TO RETRY"
		queue_redraw()
		return false
	score += 100 + zoom_level * 15 + int(time_left)
	target_index = rules.advance_target(target_index, targets.size())
	if rules.is_mission_complete(target_index, targets.size()):
		mission_complete = true
		status_text = "CONSTELLATION LOCKED · N FOR NEXT SECTOR"
	else:
		status_text = "STAR LOCKED · TRACK THE NEXT SIGNAL"
	queue_redraw()
	return true

func next_mission() -> bool:
	if not mission_complete or campaign_complete:
		return false
	if mission_index >= MISSION_COUNT - 1:
		campaign_complete = true
		status_text = "SURVEY COMPLETE · ALL THREE SIGNALS MAPPED"
		queue_redraw()
		return true
	mission_index += 1
	restart_mission()
	return true

func restart_mission() -> void:
	target_index = 0
	aim = Vector2(0.5, 0.5)
	zoom_level = 1
	time_left = float(get_current_mission().get("time_limit", 60.0))
	score = 0 if mission_index == 0 else score
	mission_complete = false
	campaign_complete = false
	failed = false
	status_text = "ALIGN THE RETICLE WITH THE NEXT STAR"
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_A, KEY_LEFT:
				_nudge_aim(Vector2(-0.012, 0.0))
			KEY_D, KEY_RIGHT:
				_nudge_aim(Vector2(0.012, 0.0))
			KEY_W, KEY_UP:
				_nudge_aim(Vector2(0.0, -0.012))
			KEY_S, KEY_DOWN:
				_nudge_aim(Vector2(0.0, 0.012))
			KEY_Q:
				zoom_level = maxi(MIN_ZOOM, zoom_level - 1)
				queue_redraw()
			KEY_E:
				zoom_level = mini(MAX_ZOOM, zoom_level + 1)
				queue_redraw()
			KEY_SPACE:
				attempt_lock()
			KEY_R:
				restart_mission()
			KEY_N:
				next_mission()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_aim_from_screen(mouse_event.position)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			attempt_lock()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			return
		var viewport_size: Vector2 = get_viewport_rect().size
		var lock_rect := Rect2(Vector2(viewport_size.x - 190.0, viewport_size.y - 94.0), Vector2(170.0, 72.0))
		if lock_rect.has_point(touch_event.position):
			attempt_lock()
		else:
			_set_aim_from_screen(touch_event.position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		var viewport_size: Vector2 = get_viewport_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			_nudge_aim(Vector2(drag_event.relative.x / viewport_size.x, drag_event.relative.y / viewport_size.y))

func _nudge_aim(delta_value: Vector2) -> void:
	aim = rules.clamp_aim(aim + delta_value)
	queue_redraw()

func _set_aim_from_screen(position: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	set_aim(Vector2(position.x / viewport_size.x, position.y / viewport_size.y))

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.052))
	draw_rect(Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0)), Color(0.025, 0.055, 0.085), false, 2.0)
	for index in range(96):
		var star_x: float = float((index * 137 + 31) % 997) / 997.0
		var star_y: float = float((index * 79 + 17) % 991) / 991.0
		var radius: float = 1.0 + float(index % 3) * 0.45
		draw_circle(Vector2(star_x * size.x, star_y * size.y), radius, Color(0.38, 0.58, 0.72, 0.42))
	var mission: Dictionary = get_current_mission()
	var targets: Array = mission.get("targets", [])
	for index in range(targets.size()):
		var point: Vector2 = targets[index]
		var position := Vector2(point.x * size.x, point.y * size.y)
		if index > 0 and index < target_index:
			var previous: Vector2 = targets[index - 1]
			draw_line(
				Vector2(previous.x * size.x, previous.y * size.y),
				position,
				Color(0.22, 0.82, 0.72, 0.8),
				2.0
			)
		var star_color := Color(0.32, 0.58, 0.70, 0.72)
		if index < target_index:
			star_color = Color(0.28, 0.92, 0.66, 0.95)
		elif index == target_index and not mission_complete:
			star_color = Color(1.0, 0.68, 0.24, 1.0)
		draw_circle(position, 5.0 if index != target_index else 7.0, star_color)
		if index == target_index and not mission_complete:
			draw_arc(position, 14.0, 0.0, TAU, 32, Color(1.0, 0.72, 0.32, 0.75), 1.5)
	var reticle := Vector2(aim.x * size.x, aim.y * size.y)
	var reticle_color := Color(0.40, 0.90, 1.0, 0.95)
	draw_arc(reticle, 22.0 + float(zoom_level) * 2.0, 0.0, TAU, 40, reticle_color, 2.0)
	draw_line(reticle + Vector2(-34.0, 0.0), reticle + Vector2(-9.0, 0.0), reticle_color, 2.0)
	draw_line(reticle + Vector2(9.0, 0.0), reticle + Vector2(34.0, 0.0), reticle_color, 2.0)
	draw_line(reticle + Vector2(0.0, -34.0), reticle + Vector2(0.0, -9.0), reticle_color, 2.0)
	draw_line(reticle + Vector2(0.0, 9.0), reticle + Vector2(0.0, 34.0), reticle_color, 2.0)
	draw_rect(Rect2(22.0, 20.0, 440.0, 112.0), Color(0.018, 0.045, 0.072, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(38.0, 50.0), "KROLL STAR CHART", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.48, 0.91, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(38.0, 78.0), str(mission.get("name", "UNKNOWN SIGNAL")), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.92, 0.96, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(38.0, 105.0), str(mission.get("region", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.72, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 245.0, 42.0), "TIME %04.1f" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.77, 0.39))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 245.0, 70.0), "SCORE %05d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.56, 0.91, 0.79))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, size.y - 112.0), "STAR %d / %d   ZOOM %d   AZ %.2f   EL %.2f" % [mini(target_index + 1, targets.size()), targets.size(), zoom_level + 1, aim.x, 1.0 - aim.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.72, 0.88, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, size.y - 82.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.77, 0.40))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, size.y - 48.0), "A/D/W/S OR ARROWS AIM · Q/E ZOOM · SPACE LOCK · R RETRY · N NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.72, 0.82))
	var lock_rect := Rect2(Vector2(size.x - 190.0, size.y - 94.0), Vector2(170.0, 72.0))
	draw_rect(lock_rect, Color(0.06, 0.22, 0.29, 0.96))
	draw_rect(lock_rect, Color(0.34, 0.86, 0.92, 0.95), false, 2.0)
	draw_string(ThemeDB.fallback_font, lock_rect.position + Vector2(28.0, 43.0), "LOCK TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.76, 0.97, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 190.0, 24.0), "MISSION %d / %d" % [mission_index + 1, MISSION_COUNT], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 0.82, 0.92))
