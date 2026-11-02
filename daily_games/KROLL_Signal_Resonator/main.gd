extends Control

const MISS_WINDOW_MS: int = 160
const LANE_COLORS: Array[Color] = [
	Color("#54d9ff"),
	Color("#ffbd58"),
	Color("#b79aff")
]

var _rules: Variant
var _rules: Variant
var _state: Dictionary = {}
var _round_start_ms: int = 0
var _elapsed_ms: int = 0
var _last_grade: String = "READY"
var _title_label: Label
var _info_label: Label
var _timing_label: Label
var _status_label: Label
var _progress: ProgressBar
var _lane_buttons: Array[Button] = []
var _restart_button: Button
var _next_button: Button

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Signal Resonator main script is unavailable.")
		set_process(false)
		return
	var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Signal Resonator rules script could not be loaded: " + rules_path)
		set_process(false)
		return
	_rules = rules_script.new()
	_state = _rules.create_state(0)
	_round_start_ms = Time.get_ticks_msec()
	_build_ui()
	_refresh_ui()

func _process(_delta: float) -> void:
	if _state.is_empty():
		return
	_elapsed_ms = maxi(0, Time.get_ticks_msec() - _round_start_ms)
	if str(_state.get("status", "")) == "playing":
		var advanced: Dictionary = _rules.advance_time(_state, _elapsed_ms)
		if bool(advanced.get("ok", false)):
			_state = advanced["state"]
	_refresh_ui()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07131f"), true)
	var lane_width: float = minf(230.0, (size.x - 120.0) / 3.0)
	var start_x: float = (size.x - lane_width * 3.0 - 36.0) * 0.5
	var center_y: float = size.y * 0.46
	var beat_interval: float = float(_rules.get_beat_interval_ms(_state)) if not _state.is_empty() else 600.0
	var pulse_phase: float = fposmod(float(_elapsed_ms), maxf(1.0, beat_interval)) / maxf(1.0, beat_interval)
	for lane in range(3):
		var x: float = start_x + float(lane) * (lane_width + 18.0)
		var lane_rect := Rect2(Vector2(x, center_y - 112.0), Vector2(lane_width, 224.0))
		draw_rect(lane_rect, Color("#10283a"), true)
		draw_rect(lane_rect, LANE_COLORS[lane], false, 2.0)
		for line_index in range(5):
			var y: float = lane_rect.position.y + 24.0 + float(line_index) * 44.0
			draw_line(Vector2(x + 10.0, y), Vector2(x + lane_width - 10.0, y), Color(LANE_COLORS[lane], 0.13), 1.0)
		var pulse_x: float = x + 16.0 + pulse_phase * (lane_width - 32.0)
		draw_circle(Vector2(pulse_x, center_y), 10.0, LANE_COLORS[lane])
		draw_arc(Vector2(pulse_x, center_y), 18.0, 0.0, TAU, 24, Color(LANE_COLORS[lane], 0.55), 2.0)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title_label = Label.new()
	_title_label.text = "KROLL // SIGNAL RESONATOR"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color("#6bdfff"))
	column.add_child(_title_label)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_color_override("font_color", Color("#d5e7f3"))
	column.add_child(_info_label)
	_timing_label = Label.new()
	_timing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timing_label.add_theme_font_size_override("font_size", 22)
	_timing_label.add_theme_color_override("font_color", Color("#f2c879"))
	column.add_child(_timing_label)
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(_progress)
	var lane_row := HBoxContainer.new()
	lane_row.add_theme_constant_override("separation", 12)
	column.add_child(lane_row)
	for lane in range(3):
		var button := Button.new()
		button.name = "Lane%d" % (lane + 1)
		button.text = "LANE %d  ·  %s / %d" % [lane + 1, ["A", "S", "D"][lane], lane + 1]
		button.custom_minimum_size = Vector2(0.0, 84.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", LANE_COLORS[lane])
		button.pressed.connect(submit_lane_hit.bind(lane, -1))
		lane_row.add_child(button)
		_lane_buttons.append(button)
	var control_row := HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 12)
	column.add_child(control_row)
	_restart_button = Button.new()
	_restart_button.text = "RESTART  ·  R"
	_restart_button.pressed.connect(restart_level)
	control_row.add_child(_restart_button)
	_next_button = Button.new()
	_next_button.text = "NEXT  ·  N"
	_next_button.pressed.connect(advance_level)
	control_row.add_child(_next_button)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 54.0)
	_status_label.add_theme_color_override("font_color", Color("#d7e5ef"))
	column.add_child(_status_label)
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "按 A / S / D 或 1 / 2 / 3 對準節拍；每個脈衝有 Perfect、Good 與 Miss 時窗。不按鍵即可等待，R 重試，N 前往下一關。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#8fa9bb"))
	column.add_child(hint)

func _refresh_ui() -> void:
	if _state.is_empty():
		return
	var status: String = str(_state.get("status", "playing"))
	var level_index: int = int(_state.get("level_index", 0))
	var level: Dictionary = _rules.get_level_definition(level_index)
	var note_count: int = _rules.get_note_count(level_index)
	var note_index: int = int(_state.get("note_index", 0))
	var expected_time: int = _rules.get_expected_time_ms(_state)
	var delta_to_note: int = expected_time - _elapsed_ms
	_info_label.text = "STAGE %02d / %02d  ·  %s  ·  %d BPM" % [
		level_index + 1, _rules.get_level_count(), str(level.get("title", "UNKNOWN")), int(level.get("bpm", 0))
	]
	if status == "playing":
		_timing_label.text = "NEXT PULSE  ·  %s  ·  %+.2f s" % [
			["CYAN", "AMBER", "VIOLET"][maxi(0, _rules.get_next_lane(_state))],
			float(delta_to_note) / 1000.0
		]
	else:
		_timing_label.text = "CHANNEL STATUS  ·  " + status.to_upper()
	_progress.value = clampf(100.0 * (1.0 - absf(float(delta_to_note)) / float(_rules.MISS_WINDOW_MS)), 0.0, 100.0) if status == "playing" else 0.0
	for lane in range(_lane_buttons.size()):
		_lane_buttons[lane].disabled = status != "playing"
		_lane_buttons[lane].text = "%s  ·  %s / %d" % [
			["CYAN", "AMBER", "VIOLET"][lane],
			["A", "S", "D"][lane],
			lane + 1
		]
	_restart_button.disabled = status == "passed"
	_restart_button.text = "RESTART CAMPAIGN  ·  R" if status == "campaign_complete" else "RESTART STAGE  ·  R"
	_next_button.disabled = status != "passed"
	_status_label.text = _status_text(status, note_index, note_count)

func _status_text(status: String, note_index: int, note_count: int) -> String:
	if status == "passed":
		return "RESONANCE LOCKED  ·  %d / %d hits  ·  SCORE %d  ·  按 N 前往下一個頻道。" % [
			int(_state.get("hits", 0)), note_count, int(_state.get("score", 0))
		]
	if status == "failed":
		return "SIGNAL LOST  ·  %d / %d hits  ·  按 R 重新校準。" % [
			int(_state.get("hits", 0)), note_count
		]
	if status == "campaign_complete":
		return "ALL CHANNELS LOCKED  ·  TOTAL SCORE %d  ·  按 R 重新開始戰役。" % int(_state.get("total_score", 0))
	return "HITS %02d  ·  MISSES %02d  ·  COMBO %02d  ·  ACCURACY %d%%  ·  NOTE %02d / %02d  ·  %s" % [
		int(_state.get("hits", 0)),
		int(_state.get("misses", 0)),
		int(_state.get("combo", 0)),
		_rules.get_accuracy_percent(_state),
		note_index + 1,
		note_count,
		_last_grade
	]

func submit_lane_hit(lane: int, elapsed_override: int = -1) -> bool:
	var elapsed: int = _elapsed_ms if elapsed_override < 0 else elapsed_override
	var result: Dictionary = _rules.submit_hit(_state, lane, elapsed)
	if result.has("state"):
		_state = result["state"]
	_last_grade = str(result.get("grade", result.get("reason", "READY"))).to_upper()
	_refresh_ui()
	return bool(result.get("ok", false))

func restart_level() -> bool:
	if str(_state.get("status", "")) == "campaign_complete":
		return restart_campaign()
	var result: Dictionary = _rules.restart_level(_state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_elapsed_ms = 0
	_round_start_ms = Time.get_ticks_msec()
	_last_grade = "READY"
	_refresh_ui()
	return true

func advance_level() -> bool:
	var result: Dictionary = _rules.advance_level(_state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_elapsed_ms = 0
	_round_start_ms = Time.get_ticks_msec()
	_last_grade = "READY"
	_refresh_ui()
	return true

func restart_campaign() -> bool:
	var result: Dictionary = _rules.restart_campaign()
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_elapsed_ms = 0
	_round_start_ms = Time.get_ticks_msec()
	_last_grade = "READY"
	_refresh_ui()
	return true

func get_title_text() -> String:
	return "KROLL // SIGNAL RESONATOR"

func get_level_count() -> int:
	return _rules.get_level_count()

func get_lane_button_count() -> int:
	return _lane_buttons.size()

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_status_text() -> String:
	return _status_text(str(_state.get("status", "")), int(_state.get("note_index", 0)), _rules.get_note_count(int(_state.get("level_index", 0))))

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_A, KEY_1:
			submit_lane_hit(0)
		KEY_S, KEY_2:
			submit_lane_hit(1)
		KEY_D, KEY_3:
			submit_lane_hit(2)
		KEY_R:
			restart_level()
		KEY_N:
			advance_level()
