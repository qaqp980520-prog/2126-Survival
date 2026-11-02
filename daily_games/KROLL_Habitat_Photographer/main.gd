extends Control

const STANDALONE_RULES_PATH: String = "res://rules.gd"
const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Habitat_Photographer/rules.gd"

class HabitatCanvas extends Control:
	var game: Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#102a32"))
		if not is_instance_valid(game):
			return
		var state: Dictionary = game.call("get_current_state")
		var stage_index: int = int(state.get("stage_index", 0))
		var habitat: String = str(state.get("habitat", "WETLAND"))
		var sky_color: Color = Color("#87b8bd")
		var ground_color: Color = Color("#355e50")
		if habitat == "RAINFOREST":
			sky_color = Color("#426d68")
			ground_color = Color("#244a3d")
		elif habitat == "DESERT":
			sky_color = Color("#e3b982")
			ground_color = Color("#a7794c")
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.68)), sky_color)
		draw_circle(Vector2(size.x * 0.84, size.y * 0.16), 25.0, Color("#f3dba0"))
		draw_rect(Rect2(Vector2(0.0, size.y * 0.68), Vector2(size.x, size.y * 0.32)), ground_color)
		if habitat == "WETLAND":
			draw_rect(Rect2(Vector2(0.0, size.y * 0.77), Vector2(size.x, size.y * 0.23)), Color("#315f69"))
			for index in range(18):
				var x: float = float(index) * size.x / 17.0
				draw_line(Vector2(x, size.y * 0.78), Vector2(x + 5.0, size.y * 0.62), Color("#718e58"), 3.0)
		else:
			for index in range(9):
				var x: float = float(index) * size.x / 8.0
				var height: float = 35.0 + float((index * 17 + stage_index * 11) % 48)
				draw_line(Vector2(x, size.y * 0.72), Vector2(x - 7.0, size.y * 0.72 - height), Color("#31543f"), 7.0)
				draw_circle(Vector2(x - 7.0, size.y * 0.72 - height), 18.0, Color("#416c4b"))
		var animal_x: float = clampf(float(state.get("animal_x", 0.5)), 0.0, 1.0)
		var animal_center := Vector2(size.x * animal_x, size.y * 0.62)
		var obscured: bool = bool(state.get("obscured", false))
		if not obscured:
			var body_color: Color = Color("#28343a")
			if stage_index == 1:
				body_color = Color("#8b6841")
			elif stage_index == 2:
				body_color = Color("#72513c")
			var zoom_scale: float = 0.82 + float(state.get("zoom", 2)) * 0.1
			if stage_index == 0:
				var heron_body := animal_center + Vector2(0.0, -12.0) * zoom_scale
				draw_circle(heron_body, 14.0 * zoom_scale, body_color)
				draw_line(heron_body + Vector2(7.0, -5.0) * zoom_scale, heron_body + Vector2(13.0, -37.0) * zoom_scale, body_color, 5.0 * zoom_scale)
				draw_circle(heron_body + Vector2(14.0, -40.0) * zoom_scale, 6.0 * zoom_scale, body_color)
				draw_line(heron_body + Vector2(19.0, -41.0) * zoom_scale, heron_body + Vector2(34.0, -38.0) * zoom_scale, Color("#d8a64c"), 2.5 * zoom_scale)
				draw_line(heron_body + Vector2(-4.0, 10.0) * zoom_scale, heron_body + Vector2(-8.0, 34.0) * zoom_scale, body_color, 3.0 * zoom_scale)
				draw_line(heron_body + Vector2(5.0, 10.0) * zoom_scale, heron_body + Vector2(8.0, 34.0) * zoom_scale, body_color, 3.0 * zoom_scale)
			elif stage_index == 1:
				var glider_body := animal_center + Vector2(0.0, -14.0) * zoom_scale
				draw_circle(glider_body, 13.0 * zoom_scale, body_color)
				draw_colored_polygon(PackedVector2Array([
					glider_body + Vector2(-5.0, -5.0) * zoom_scale,
					glider_body + Vector2(-42.0, -37.0) * zoom_scale,
					glider_body + Vector2(-25.0, 5.0) * zoom_scale
				]), body_color.lightened(0.18))
				draw_colored_polygon(PackedVector2Array([
					glider_body + Vector2(5.0, -5.0) * zoom_scale,
					glider_body + Vector2(42.0, -37.0) * zoom_scale,
					glider_body + Vector2(25.0, 5.0) * zoom_scale
				]), body_color.lightened(0.18))
				draw_circle(glider_body + Vector2(15.0, -12.0) * zoom_scale, 5.0 * zoom_scale, body_color)
				draw_line(glider_body + Vector2(-8.0, 5.0) * zoom_scale, glider_body + Vector2(-20.0, 18.0) * zoom_scale, body_color, 3.0 * zoom_scale)
			else:
				var runner_body := animal_center + Vector2(0.0, -13.0) * zoom_scale
				draw_circle(runner_body, 19.0 * zoom_scale, body_color)
				draw_line(runner_body + Vector2(-15.0, -3.0) * zoom_scale, runner_body + Vector2(-47.0, -18.0) * zoom_scale, body_color, 6.0 * zoom_scale)
				draw_circle(runner_body + Vector2(18.0, -12.0) * zoom_scale, 7.0 * zoom_scale, body_color)
				draw_line(runner_body + Vector2(-8.0, 10.0) * zoom_scale, runner_body + Vector2(-12.0, 28.0) * zoom_scale, body_color, 4.0 * zoom_scale)
				draw_line(runner_body + Vector2(9.0, 10.0) * zoom_scale, runner_body + Vector2(13.0, 28.0) * zoom_scale, body_color, 4.0 * zoom_scale)
		else:
			for index in range(7):
				var bush_x: float = size.x * 0.35 + float(index) * 26.0
				draw_circle(Vector2(bush_x, size.y * 0.61), 23.0, Color("#315b43"))
		var frame := Rect2(Vector2(size.x * 0.5 - 82.0, size.y * 0.18), Vector2(164.0, size.y * 0.56))
		draw_rect(frame, Color(0.75, 0.95, 1.0, 0.9), false, 2.0)
		draw_line(Vector2(size.x * 0.5, frame.position.y), Vector2(size.x * 0.5, frame.end.y), Color(0.75, 0.95, 1.0, 0.4), 1.0)
		draw_line(Vector2(frame.position.x, size.y * 0.46), Vector2(frame.end.x, size.y * 0.46), Color(0.75, 0.95, 1.0, 0.4), 1.0)
		draw_circle(Vector2(size.x * 0.5, size.y * 0.46), 4.0, Color("#f7d88b"))

var _rules: RefCounted
var _stage_index: int = 0
var _elapsed: float = 0.0
var _focus: int = 3
var _zoom: int = 2
var _exposure: int = 0
var _score: int = 0
var _stage_awarded: bool = false
var _campaign_complete: bool = false
var _result: Dictionary = {}
var _status: String = "Wait for the subject to enter the viewfinder."
var _canvas: HabitatCanvas
var _stage_label: Label
var _species_label: Label
var _settings_label: Label
var _telemetry_label: Label
var _score_label: Label
var _status_label: Label
var _buttons: Array[Button] = []
var _ui_elapsed: float = 0.0

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else STANDALONE_RULES_PATH
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Habitat Photographer could not load its rules module: %s" % rules_path)
		return
	_rules = rules_script.new() as RefCounted
	_build_ui()
	_load_stage_settings()
	_refresh_ui()

func _process(delta: float) -> void:
	if not _stage_awarded and not _campaign_complete:
		_elapsed += delta
		_ui_elapsed += delta
		if _ui_elapsed >= 0.1:
			_ui_elapsed = 0.0
			_refresh_ui()
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q: adjust_setting("focus", -1)
		KEY_E: adjust_setting("focus", 1)
		KEY_W: adjust_setting("zoom", 1)
		KEY_S: adjust_setting("zoom", -1)
		KEY_A: adjust_setting("exposure", -1)
		KEY_D: adjust_setting("exposure", 1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: capture_photo()
		KEY_R: reset_stage()
		KEY_N: advance_stage()
		_: return
	get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#07151c")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // HABITAT PHOTOGRAPHER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#9ce6d3"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "FIELD OBSERVATION · FOCUS · EXPOSURE · SHUTTER TIMING"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#b4c8ca"))
	column.add_child(subtitle)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 24)
	column.add_child(header)
	_stage_label = Label.new()
	header.add_child(_stage_label)
	_species_label = Label.new()
	header.add_child(_species_label)
	_score_label = Label.new()
	header.add_child(_score_label)
	_canvas = HabitatCanvas.new()
	_canvas.name = "HabitatViewfinder"
	_canvas.game = self
	_canvas.custom_minimum_size = Vector2(0.0, 330.0)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_canvas)
	_settings_label = Label.new()
	_settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_label.add_theme_color_override("font_color", Color("#d8e7e5"))
	column.add_child(_settings_label)
	_telemetry_label = Label.new()
	_telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telemetry_label.add_theme_color_override("font_color", Color("#8daeb3"))
	column.add_child(_telemetry_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)
	var setting_row := HBoxContainer.new()
	setting_row.alignment = BoxContainer.ALIGNMENT_CENTER
	setting_row.add_theme_constant_override("separation", 7)
	column.add_child(setting_row)
	setting_row.add_child(_make_button("FOCUS −", Callable(self, "adjust_setting").bind("focus", -1)))
	setting_row.add_child(_make_button("FOCUS +", Callable(self, "adjust_setting").bind("focus", 1)))
	setting_row.add_child(_make_button("ZOOM −", Callable(self, "adjust_setting").bind("zoom", -1)))
	setting_row.add_child(_make_button("ZOOM +", Callable(self, "adjust_setting").bind("zoom", 1)))
	setting_row.add_child(_make_button("EXPOSURE −", Callable(self, "adjust_setting").bind("exposure", -1)))
	setting_row.add_child(_make_button("EXPOSURE +", Callable(self, "adjust_setting").bind("exposure", 1)))
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)
	action_row.add_child(_make_button("SHUTTER  [SPACE]", Callable(self, "capture_photo")))
	action_row.add_child(_make_button("RESET / RESTART  [R]", Callable(self, "reset_stage")))
	action_row.add_child(_make_button("NEXT  [N]", Callable(self, "advance_stage")))
	var hint := Label.new()
	hint.text = "Q/E focus · W/S zoom · A/D exposure · Space capture · R reset · N next habitat"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#718c93"))
	hint.add_theme_font_size_override("font_size", 11)
	column.add_child(hint)

func _make_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(132.0, 42.0)
	button.pressed.connect(callback)
	_buttons.append(button)
	return button

func _load_stage_settings() -> void:
	# Start each habitat from a neutral camera profile; the visible field brief
	# tells the player which adjustments are required for the current species.
	_focus = 3
	_zoom = 2
	_exposure = 0

func adjust_setting(setting: String, amount: int) -> bool:
	if _stage_awarded or _campaign_complete or amount == 0:
		return false
	match setting:
		"focus": _focus = clampi(_focus + amount, 1, 5)
		"zoom": _zoom = clampi(_zoom + amount, 1, 3)
		"exposure": _exposure = clampi(_exposure + amount, -1, 1)
		_: return false
	_refresh_ui()
	return true

func capture_photo() -> bool:
	if _stage_awarded or _campaign_complete or _rules == null:
		return false
	_result = _rules.call("evaluate_capture", _stage_index, _elapsed, _focus, _zoom, _exposure)
	if bool(_result.get("passed", false)):
		_stage_awarded = true
		_score += int(_result.get("score", 100))
		if _stage_index == int(_rules.call("get_stage_count")) - 1:
			_campaign_complete = true
			_status = "CAMPAIGN COMPLETE · ALL THREE FIELD PHOTOS ARCHIVED."
		else:
			_status = "PHOTO LOCKED · %s · 100 POINTS. ADVANCE WHEN READY." % str(_result.get("species", "SUBJECT"))
	else:
		var reasons: Dictionary = {
			"subject_obscured": "Foliage blocks the subject. Wait for a clear sightline.",
			"subject_not_centered": "Hold the shutter until the subject enters the center frame.",
			"focus_mismatch": "Focus is not sharp enough for this species.",
			"zoom_mismatch": "Change zoom to match the field distance.",
			"exposure_mismatch": "Exposure does not match the current light.",
			"invalid_time": "Camera timing is invalid; reset the field station."
		}
		_status = str(reasons.get(str(_result.get("reason", "")), "Photo rejected. Recheck camera settings."))
	_refresh_ui()
	return bool(_result.get("passed", false))

func reset_stage() -> bool:
	if _stage_awarded or _campaign_complete:
		return false
	_elapsed = 0.0
	_result = {}
	_load_stage_settings()
	_status = "FIELD RESET · WAIT FOR A CLEAR, CENTERED SUBJECT."
	_refresh_ui()
	return true

func advance_stage() -> bool:
	if not _stage_awarded or _campaign_complete:
		return false
	_stage_index += 1
	_elapsed = 0.0
	_stage_awarded = false
	_result = {}
	_load_stage_settings()
	_status = "NEW HABITAT · TRACK THE SUBJECT AND PREPARE THE CAMERA."
	_refresh_ui()
	return true

func reset_campaign() -> void:
	_stage_index = 0
	_elapsed = 0.0
	_score = 0
	_stage_awarded = false
	_campaign_complete = false
	_result = {}
	_load_stage_settings()
	_status = "NEW EXPEDITION · FIND THE FIRST CLEAR SHOT."
	_refresh_ui()

func get_current_state() -> Dictionary:
	var stage: Dictionary = _rules.call("get_stage", _stage_index) if _rules != null else {}
	return {
		"stage_index": _stage_index,
		"stage_count": int(_rules.call("get_stage_count")) if _rules != null else 0,
		"stage_id": str(stage.get("id", "")),
		"stage_name": str(stage.get("name", "")),
		"habitat": str(stage.get("habitat", "")),
		"species": str(stage.get("species", "")),
		"elapsed": _elapsed,
		"animal_x": float(_rules.call("get_animal_position", _stage_index, _elapsed)) if _rules != null else 0.5,
		"obscured": bool(_rules.call("is_obscured", _stage_index, _elapsed)) if _rules != null else false,
		"focus": _focus,
		"zoom": _zoom,
		"exposure": _exposure,
		"target_focus": int(stage.get("focus", 0)),
		"target_zoom": int(stage.get("zoom", 0)),
		"target_exposure": int(stage.get("exposure", 0)),
		"score": _score,
		"stage_awarded": _stage_awarded,
		"campaign_complete": _campaign_complete,
		"result": _result.duplicate(true),
		"status": _status
	}

func get_title_text() -> String:
	return "KROLL // HABITAT PHOTOGRAPHER"

func get_stage_count() -> int:
	return int(_rules.call("get_stage_count")) if _rules != null else 0

func get_control_button_count() -> int:
	return _buttons.size()

func get_status_text() -> String:
	return _status

func _refresh_ui() -> void:
	if _rules == null or _stage_label == null:
		return
	var state: Dictionary = get_current_state()
	_stage_label.text = "%s · %d / %d" % [str(state.get("stage_name", "")), _stage_index + 1, int(state.get("stage_count", 0))]
	_species_label.text = str(state.get("species", ""))
	_score_label.text = "SCORE %d" % _score
	_settings_label.text = "CAMERA F%d/5 Z%d/3 E%+d  ·  FIELD BRIEF F%d Z%d E%+d" % [
		_focus, _zoom, _exposure,
		int(state.get("target_focus", 0)),
		int(state.get("target_zoom", 0)),
		int(state.get("target_exposure", 0))
	]
	var visibility_text: String = "OBSCURED" if bool(state.get("obscured", false)) else "CLEAR"
	_telemetry_label.text = "SUBJECT X %.2f · %s · %.1fs" % [float(state.get("animal_x", 0.5)), visibility_text, _elapsed]
	_status_label.text = _status
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()
