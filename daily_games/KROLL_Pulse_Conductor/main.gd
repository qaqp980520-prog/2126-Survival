extends Control
const RulesScript = preload("res://rules.gd")
const APPROACH_SECONDS: float = 1.6
const LANE_LABELS: Array[String] = ["A","S","D","F"]
const LANE_COLORS: Array[Color] = [Color(0.30,0.88,1.0),Color(0.48,0.94,0.68),Color(1.0,0.72,0.34),Color(0.83,0.58,1.0)]
var _rules: Variant
var _state: Dictionary = {}
var _song_time: float = 0.0
var _lane_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _info_label: Label
var _score_label: Label
var _status_label: Label
var _restart_button: Button
var _next_button: Button
func _ready() -> void:
	_rules = RulesScript.new()
	_state = _rules.create_state(0)
	_build_ui()
	_refresh_ui()
	queue_redraw()
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
func _process(delta: float) -> void:
	if _state.is_empty() or str(_state.get("status", "")) != "playing":
		return
	_song_time += delta
	_state = _rules.resolve_misses(_state, _song_time)
	_refresh_ui()
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	var lane: int = -1
	match key_event.keycode:
		KEY_A: lane = 0
		KEY_S: lane = 1
		KEY_D: lane = 2
		KEY_F: lane = 3
	if lane >= 0:
		press_lane(lane)
		get_viewport().set_input_as_handled()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.018,0.030,0.055),true)
	if _state.is_empty():
		return
	var left: float = size.x * 0.14
	var right: float = size.x * 0.86
	var top: float = 132.0
	var target_y: float = minf(size.y * 0.77,size.y - 180.0)
	var lane_spacing: float = (right - left) / 3.0
	draw_rect(Rect2(Vector2(left - 34.0,top),Vector2(right - left + 68.0,maxf(0.0,target_y - top + 34.0))),Color(0.035,0.060,0.095,0.72),true)
	for lane in range(4):
		var x: float = left + float(lane) * lane_spacing
		draw_line(Vector2(x,top),Vector2(x,target_y + 26.0),Color(0.24,0.37,0.48,0.72),2.0)
		draw_circle(Vector2(x,target_y),25.0,Color(0.08,0.15,0.22))
		draw_arc(Vector2(x,target_y),25.0,0.0,TAU,48,LANE_COLORS[lane],2.5)
	draw_line(Vector2(left - 34.0,target_y),Vector2(right + 34.0,target_y),Color(0.55,0.92,1.0,0.95),3.0)
	for note_value in _state.get("notes",[]):
		if not (note_value is Dictionary):
			continue
		var note: Dictionary = note_value
		if bool(note.get("judged",false)):
			continue
		var lane: int = int(note.get("lane",-1))
		if lane < 0 or lane >= 4:
			continue
		var remaining: float = float(note.get("time",0.0)) - _song_time
		if remaining < -0.20 or remaining > APPROACH_SECONDS:
			continue
		var progress: float = clampf(1.0 - remaining / APPROACH_SECONDS,0.0,1.0)
		var y: float = lerpf(top,target_y,progress)
		var x: float = left + float(lane) * lane_spacing
		draw_circle(Vector2(x,y),17.0,LANE_COLORS[lane])
		draw_circle(Vector2(x,y),6.0,Color(0.96,0.99,1.0))
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",26)
	margin.add_theme_constant_override("margin_right",26)
	margin.add_theme_constant_override("margin_top",18)
	margin.add_theme_constant_override("margin_bottom",16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // PULSE CONDUCTOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color(0.55,0.92,1.0))
	column.add_child(title)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size",17)
	_info_label.add_theme_color_override("font_color",Color(0.77,0.88,0.96))
	column.add_child(_info_label)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size",15)
	_score_label.add_theme_color_override("font_color",Color(0.56,0.86,0.76))
	column.add_child(_score_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var lane_row := HBoxContainer.new()
	lane_row.add_theme_constant_override("separation",10)
	for lane in range(4):
		var lane_button := Button.new()
		lane_button.name = "LaneButton_" + str(lane)
		lane_button.text = LANE_LABELS[lane] + "  ·  " + str(lane + 1)
		lane_button.custom_minimum_size = Vector2(0.0,54.0)
		lane_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_button.focus_mode = Control.FOCUS_NONE
		lane_button.pressed.connect(_on_lane_pressed.bind(lane))
		lane_row.add_child(lane_button)
		_lane_buttons.append(lane_button)
	column.add_child(lane_row)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation",8)
	_restart_button = Button.new()
	_restart_button.name = "RestartChartButton"
	_restart_button.text = "RESTART SHIFT"
	_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart_button.pressed.connect(_on_restart_pressed)
	action_row.add_child(_restart_button)
	_action_buttons.append(_restart_button)
	_next_button = Button.new()
	_next_button.name = "NextChartButton"
	_next_button.text = "NEXT SHIFT"
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(_on_next_pressed)
	action_row.add_child(_next_button)
	_action_buttons.append(_next_button)
	var campaign_button := Button.new()
	campaign_button.name = "RestartCampaignButton"
	campaign_button.text = "RESTART CAMPAIGN"
	campaign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_button.pressed.connect(_on_campaign_restart_pressed)
	action_row.add_child(campaign_button)
	_action_buttons.append(campaign_button)
	column.add_child(action_row)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color",Color(0.91,0.80,0.55))
	column.add_child(_status_label)
func _refresh_ui() -> void:
	if _state.is_empty():
		return
	var chart_index: int = int(_state.get("chart_index",0))
	var chart: Dictionary = _rules.get_chart_definition(chart_index)
	_info_label.text = "SHIFT %02d / %02d   ·   %s   ·   %d BPM" % [chart_index + 1,_rules.get_chart_count(),str(chart.get("title","UNKNOWN")),int(chart.get("bpm",0))]
	var accuracy: float = _rules.get_accuracy(_state)
	_score_label.text = "SCORE %04d   ·   COMBO %02d   ·   ACCURACY %05.1f%%   ·   CAMPAIGN %04d" % [int(_state.get("score",0)),int(_state.get("combo",0)),accuracy,int(_state.get("campaign_score",0))]
	var status: String = str(_state.get("status","playing"))
	match status:
		"playing": _status_label.text = "A / S / D / F 或點擊下方按鈕，在光點抵達校準線時擊拍。"
		"passed": _status_label.text = "SHIFT CLEARED  ·  NEXT SHIFT 已解鎖。完成的班次不能重複刷分。"
		"failed": _status_label.text = "SYNC LOST  ·  重新開始本班次，再試一次。"
		"campaign_complete": _status_label.text = "CAMPAIGN COMPLETE  ·  TOTAL SCORE %04d" % int(_state.get("total_score",0))
	_restart_button.disabled = status == "passed" or status == "campaign_complete"
	_next_button.disabled = status != "passed"
	for lane_button in _lane_buttons:
		lane_button.disabled = status != "playing"
func _on_lane_pressed(lane: int) -> void:
	press_lane(lane)
func _on_restart_pressed() -> void:
	restart_chart()
func _on_next_pressed() -> void:
	advance_chart()
func _on_campaign_restart_pressed() -> void:
	restart_campaign()
func press_lane(lane: int) -> bool:
	return press_lane_at(lane,_song_time)
func press_lane_at(lane: int, song_time: float) -> bool:
	if _state.is_empty() or str(_state.get("status","")) != "playing":
		return false
	if lane < 0 or lane >= 4 or is_nan(song_time) or is_inf(song_time) or song_time < 0.0:
		return false
	_song_time = maxf(_song_time,song_time)
	_state = _rules.resolve_misses(_state,song_time)
	if str(_state.get("status","")) != "playing":
		_refresh_ui()
		queue_redraw()
		return false
	var note_index: int = _rules.find_note_index(_state,lane,song_time)
	if note_index < 0:
		return false
	var notes: Array = _state.get("notes",[])
	var note: Dictionary = notes[note_index]
	var hit: Dictionary = _rules.hit_note(_state,note_index,song_time - float(note.get("time",0.0)))
	if not bool(hit.get("ok",false)):
		return false
	_state = hit["state"]
	_refresh_ui()
	queue_redraw()
	return true
func advance_chart() -> bool:
	var result: Dictionary = _rules.advance_chart(_state)
	if not bool(result.get("ok",false)):
		return false
	_state = result["state"]
	_song_time = 0.0
	_refresh_ui()
	queue_redraw()
	return true
func restart_chart() -> bool:
	var result: Dictionary = _rules.restart_chart(_state)
	if not bool(result.get("ok",false)):
		return false
	_state = result["state"]
	_song_time = 0.0
	_refresh_ui()
	queue_redraw()
	return true
func restart_campaign() -> bool:
	_state = _rules.restart_campaign()
	_song_time = 0.0
	_refresh_ui()
	queue_redraw()
	return not _state.is_empty()
func get_title_text() -> String:
	return "KROLL // PULSE CONDUCTOR"
func get_chart_count() -> int:
	return _rules.get_chart_count()
func get_lane_button_count() -> int:
	return _lane_buttons.size()
func get_action_button_count() -> int:
	return _action_buttons.size()
func get_control_button_count() -> int:
	return _lane_buttons.size() + _action_buttons.size()
func get_current_state() -> Dictionary:
	return _state.duplicate(true)
func get_song_time() -> float:
	return _song_time
