extends Control

const MIN_LENGTH: float = 0.5
const MAX_LENGTH: float = 3.0
const LENGTH_STEP: float = 0.05
const CYCLES_PER_TEST: int = 4

class PendulumCanvas extends Control:
	var game: Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#071522"))
		if not is_instance_valid(game):
			return
		var state: Dictionary = game.call("get_display_state")
		var actual_angle: float = float(state.get("actual_angle", 0.0))
		var reference_angle: float = float(state.get("reference_angle", 0.0))
		var active: bool = bool(state.get("testing", false))
		var arm_length: float = size.y * 0.55
		var left_origin := Vector2(size.x * 0.27, size.y * 0.17)
		var right_origin := Vector2(size.x * 0.73, size.y * 0.17)
		var left_bob := left_origin + Vector2(sin(actual_angle), cos(actual_angle)) * arm_length
		var right_bob := right_origin + Vector2(sin(reference_angle), cos(reference_angle)) * arm_length
		draw_circle(left_origin, 7.0, Color("#d4e8ef"))
		draw_circle(right_origin, 7.0, Color("#d4e8ef"))
		draw_line(left_origin, left_bob, Color("#39d8ed"), 4.0, true)
		draw_line(right_origin, right_bob, Color("#ffb45c"), 4.0, true)
		draw_circle(left_bob, 17.0, Color("#39d8ed"))
		draw_circle(right_bob, 17.0, Color("#ffb45c"))
		draw_arc(left_origin, arm_length, -0.17, 0.17, 36, Color(0.22, 0.75, 0.85, 0.35), 1.5, true)
		draw_arc(right_origin, arm_length, -0.17, 0.17, 36, Color(0.95, 0.58, 0.25, 0.35), 1.5, true)
		if active:
			draw_rect(Rect2(Vector2(12.0, size.y - 16.0), Vector2((size.x - 24.0) * float(state.get("progress", 0.0)), 4.0)), Color("#39d8ed"))

var _rules: RefCounted
var _stage_index: int = 0
var _length: float = 1.5
var _elapsed: float = 0.0
var _testing: bool = false
var _campaign_complete: bool = false
var _score: int = 0
var _result: Dictionary = {}
var _status: String = "Tune the pendulum length, then run four cycles."
var _canvas: PendulumCanvas
var _stage_label: Label
var _target_label: Label
var _length_label: Label
var _score_label: Label
var _status_label: Label
var _run_button: Button
var _minus_button: Button
var _plus_button: Button
var _next_button: Button

func _ready() -> void:
	var rules_path: String = "res://daily_games/KROLL_Pendulum_Array/rules.gd"
	if not ResourceLoader.exists(rules_path):
		rules_path = "res://rules.gd"
	var rules_script: Script = load(rules_path) as Script
	if rules_script != null:
		_rules = rules_script.new()
	_build_ui()
	_refresh_ui()

func _process(delta: float) -> void:
	if _testing and _rules != null:
		_elapsed += delta
		var stage: Dictionary = _rules.call("get_stage", _stage_index)
		var duration: float = float(stage.get("target_period", 1.0)) * float(CYCLES_PER_TEST)
		if _elapsed >= duration:
			_finish_test()
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			adjust_length(-LENGTH_STEP)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			adjust_length(LENGTH_STEP)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			run_test()
			get_viewport().set_input_as_handled()
		KEY_R:
			reset_stage()
			get_viewport().set_input_as_handled()
		KEY_N:
			advance_stage()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#07111d")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // PENDULUM ARRAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#52d9ee"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "RESONANCE CALIBRATION • FOUR-CYCLE PHASE TEST"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#a8bdc8"))
	column.add_child(subtitle)
	var stage_row := HBoxContainer.new()
	stage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_row.add_theme_constant_override("separation", 28)
	column.add_child(stage_row)
	_stage_label = Label.new()
	stage_row.add_child(_stage_label)
	_target_label = Label.new()
	stage_row.add_child(_target_label)
	_score_label = Label.new()
	stage_row.add_child(_score_label)
	_canvas = PendulumCanvas.new()
	_canvas.name = "PendulumDisplay"
	_canvas.game = self
	_canvas.custom_minimum_size = Vector2(0.0, 340.0)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_canvas)
	var control_row := HBoxContainer.new()
	control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	control_row.add_theme_constant_override("separation", 12)
	column.add_child(control_row)
	_minus_button = _make_button("LENGTH −", Callable(self, "adjust_length").bind(-LENGTH_STEP))
	control_row.add_child(_minus_button)
	_length_label = Label.new()
	_length_label.custom_minimum_size = Vector2(130.0, 44.0)
	_length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_length_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control_row.add_child(_length_label)
	_plus_button = _make_button("LENGTH +", Callable(self, "adjust_length").bind(LENGTH_STEP))
	control_row.add_child(_plus_button)
	_run_button = _make_button("RUN FOUR CYCLES", Callable(self, "run_test"))
	control_row.add_child(_run_button)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	column.add_child(action_row)
	action_row.add_child(_make_button("RESET STAGE  [R]", Callable(self, "reset_stage")))
	_next_button = _make_button("NEXT STAGE  [N]", Callable(self, "advance_stage"))
	action_row.add_child(_next_button)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 17)
	column.add_child(_status_label)
	var guide := Label.new()
	guide.text = "FIELD GUIDE: T ≈ 2π√(L/g),  g = 9.81 m/s². Match the reference period; smaller phase drift earns a stable lock. Arrow keys adjust length, Enter/Space runs the test."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_color_override("font_color", Color("#8ea7b4"))
	column.add_child(guide)

func _make_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150.0, 46.0)
	button.pressed.connect(callback)
	return button

func adjust_length(delta_length: float) -> void:
	if _testing or _campaign_complete or _rules == null:
		return
	_length = float(_rules.call("snap_length", _length + delta_length))
	_status = "Length adjusted. Run four cycles to compare phase drift."
	_refresh_ui()

func run_test() -> bool:
	if _testing or _campaign_complete or _rules == null:
		return false
	_elapsed = 0.0
	_result.clear()
	_testing = true
	_status = "TEST RUNNING — watch the cyan pendulum drift against the amber reference."
	_refresh_ui()
	return true

func _finish_test() -> void:
	if not _testing:
		return
	_testing = false
	_result = _rules.call("evaluate", _length, _stage_index)
	if bool(_result.get("passed", false)):
		_score += int(_result.get("score", 0))
		_status = "RESONANCE LOCKED — period error %.3f s. Press N for the next chamber." % float(_result.get("period_error", 0.0))
	else:
		_status = "PHASE DRIFT — error %.3f s. Adjust the length and try again." % float(_result.get("period_error", 0.0))
	_refresh_ui()

func finish_test_now() -> void:
	_finish_test()

func advance_stage() -> bool:
	if _testing or not bool(_result.get("passed", false)):
		return false
	if _stage_index >= int(_rules.call("get_stage_count")) - 1:
		_campaign_complete = true
		_status = "ARRAY CALIBRATED — all three chambers are synchronized."
	else:
		_stage_index += 1
		_length = 1.5
		_result.clear()
		_status = "New chamber loaded. Tune the pendulum to the reference period."
	_refresh_ui()
	return true

func reset_stage() -> void:
	if _campaign_complete:
		reset_campaign()
		return
	_testing = false
	_elapsed = 0.0
	_length = 1.5
	_result.clear()
	_status = "Stage reset. Tune the pendulum length and try again."
	_refresh_ui()

func reset_campaign() -> void:
	_stage_index = 0
	_length = 1.5
	_elapsed = 0.0
	_testing = false
	_campaign_complete = false
	_score = 0
	_result.clear()
	_status = "Campaign restarted. Calibrate all three pendulum arrays."
	_refresh_ui()

func get_display_state() -> Dictionary:
	if _rules == null:
		return {}
	var stage: Dictionary = _rules.call("get_stage", _stage_index)
	var actual_period: float = float(_rules.call("period_for_length", _length))
	var target_period: float = float(stage.get("target_period", 1.0))
	var actual_phase: float = _elapsed * TAU / maxf(actual_period, 0.001)
	var reference_phase: float = _elapsed * TAU / maxf(target_period, 0.001)
	return {
		"testing":_testing,
		"actual_angle":sin(actual_phase) * 0.17,
		"reference_angle":sin(reference_phase) * 0.17,
		"progress":clampf(_elapsed / maxf(target_period * float(CYCLES_PER_TEST), 0.001), 0.0, 1.0)
	}

func get_current_state() -> Dictionary:
	var stage: Dictionary = _rules.call("get_stage", _stage_index) if _rules != null else {}
	return {
		"stage_index":_stage_index,
		"stage_name":str(stage.get("name", "")),
		"length":_length,
		"target_period":float(stage.get("target_period", -1.0)),
		"score":_score,
		"testing":_testing,
		"result":_result.duplicate(true),
		"campaign_complete":_campaign_complete
	}

func get_title_text() -> String:
	return "KROLL // PENDULUM ARRAY"

func get_length() -> float:
	return _length

func get_stage_count() -> int:
	return int(_rules.call("get_stage_count")) if _rules != null else 0

func _refresh_ui() -> void:
	if _rules == null or not is_instance_valid(_stage_label):
		return
	var stage: Dictionary = _rules.call("get_stage", _stage_index)
	_stage_label.text = "%02d / %02d  %s" % [_stage_index + 1, _rules.call("get_stage_count"), str(stage.get("name", ""))]
	_target_label.text = "REFERENCE  %.3f s" % float(stage.get("target_period", 0.0))
	_score_label.text = "SCORE  %03d" % _score
	_length_label.text = "L = %.2f m" % _length
	_status_label.text = _status
	_minus_button.disabled = _testing or _campaign_complete or _length <= MIN_LENGTH
	_plus_button.disabled = _testing or _campaign_complete or _length >= MAX_LENGTH
	_run_button.disabled = _testing or _campaign_complete
	_next_button.disabled = _testing or not bool(_result.get("passed", false))
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()
