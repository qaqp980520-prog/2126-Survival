extends Control

const Rules = preload("res://rules.gd")

var _relay_index: int = 0
var _beat_index: int = 0
var _elapsed_seconds: float = 0.0
var _perfect_count: int = 0
var _good_count: int = 0
var _miss_count: int = 0
var _combo: int = 0
var _score: int = 0
var _relay_rewards: Array[bool] = [false, false, false]
var _state: String = "playing"
var _last_feedback: String = "SYSTEM READY"

var _title_label: Label
var _status_label: Label
var _expected_label: Label
var _progress_bar: ProgressBar
var _stats_label: Label
var _feedback_label: Label
var _lane_buttons: Array[Button] = []
var _next_button: Button

func _ready() -> void:
	_build_ui()
	_start_relay(0)
	set_process(true)

func _process(delta: float) -> void:
	if _state != "playing":
		return
	_elapsed_seconds += delta
	var relay: Dictionary = Rules.get_relay(_relay_index)
	var interval: float = Rules.beat_interval(int(relay.get("bpm", 72)))
	while _beat_index < Rules.BEATS_PER_RELAY:
		var target_time: float = Rules.LEAD_IN_SECONDS + float(_beat_index) * interval
		if _elapsed_seconds > target_time + Rules.GOOD_WINDOW:
			_register_miss("AUTO MISS")
		else:
			break
	_update_ui()

func submit_lane_hit(lane: int, at_seconds: float = -1.0) -> Dictionary:
	if _state != "playing":
		return {"accepted": false, "grade": "ignored", "reason": "relay_not_active"}
	if lane < 0 or lane >= Rules.LANE_COUNT:
		return {"accepted": false, "grade": "miss", "reason": "invalid_lane"}
	if _beat_index >= Rules.BEATS_PER_RELAY:
		return {"accepted": false, "grade": "ignored", "reason": "relay_complete"}

	var event_time: float = _elapsed_seconds if at_seconds < 0.0 else at_seconds
	if not is_finite(event_time) or event_time < 0.0:
		return {"accepted": false, "grade": "miss", "reason": "invalid_timing"}
	var relay: Dictionary = Rules.get_relay(_relay_index)
	var interval: float = Rules.beat_interval(int(relay.get("bpm", 72)))
	var target_time: float = Rules.LEAD_IN_SECONDS + float(_beat_index) * interval
	var timing_error: float = event_time - target_time
	if timing_error < -Rules.GOOD_WINDOW:
		_last_feedback = "TOO EARLY — WAIT FOR THE PULSE"
		_update_ui()
		return {"accepted": false, "grade": "early", "reason": "outside_window"}

	var expected_lane: int = int(relay["lanes"][_beat_index])
	var result: Dictionary = Rules.judge_hit(expected_lane, lane, timing_error)
	if not bool(result.get("accepted", false)):
		return result
	match str(result.get("grade", "miss")):
		"perfect":
			_perfect_count += 1
			_combo += 1
			_last_feedback = "PERFECT  +10"
		"good":
			_good_count += 1
			_combo += 1
			_last_feedback = "GOOD  +6"
		_:
			_miss_count += 1
			_combo = 0
			_last_feedback = "MISS — " + str(result.get("reason", "timing"))
	_beat_index += 1
	if _beat_index >= Rules.BEATS_PER_RELAY:
		_finish_relay()
	_update_ui()
	return result

func next_relay() -> bool:
	if _state != "complete" or _relay_index >= Rules.relay_count() - 1:
		return false
	_start_relay(_relay_index + 1)
	return true

func restart_current_relay() -> void:
	_start_relay(_relay_index)

func restart_campaign() -> void:
	_score = 0
	_relay_rewards = [false, false, false]
	_start_relay(0)

func get_relay_state() -> String:
	return _state

func get_relay_index() -> int:
	return _relay_index

func get_beat_index() -> int:
	return _beat_index

func get_score() -> int:
	return _score

func get_current_expected_lane() -> int:
	if _state != "playing":
		return -1
	var relay: Dictionary = Rules.get_relay(_relay_index)
	if _beat_index >= Rules.BEATS_PER_RELAY:
		return -1
	return int(relay["lanes"][_beat_index])

func _start_relay(index: int) -> void:
	_relay_index = clampi(index, 0, Rules.relay_count() - 1)
	_beat_index = 0
	_elapsed_seconds = 0.0
	_perfect_count = 0
	_good_count = 0
	_miss_count = 0
	_combo = 0
	_state = "playing"
	_last_feedback = "VISUAL METRONOME — NO AUDIO"
	_update_ui()

func _register_miss(feedback: String) -> void:
	if _state != "playing" or _beat_index >= Rules.BEATS_PER_RELAY:
		return
	_miss_count += 1
	_combo = 0
	_beat_index += 1
	_last_feedback = feedback
	if _beat_index >= Rules.BEATS_PER_RELAY:
		_finish_relay()

func _finish_relay() -> void:
	var hit_count: int = _perfect_count + _good_count
	if Rules.can_clear(hit_count, _miss_count):
		if not _relay_rewards[_relay_index]:
			_score += Rules.RELAY_REWARD
			_relay_rewards[_relay_index] = true
		_state = "complete"
		_last_feedback = "RELAY STABLE — 100 POINTS"
	else:
		_state = "failed"
		_last_feedback = "RELAY FAILED — PRESS R TO RETRY"

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.075)
	add_child(background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ReactorPanel"
	panel.custom_minimum_size = Vector2(820.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "RelayTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)

	_expected_label = Label.new()
	_expected_label.name = "ExpectedLaneLabel"
	_expected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expected_label.add_theme_font_size_override("font_size", 25)
	_expected_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	column.add_child(_expected_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "BeatProgress"
	_progress_bar.min_value = 0
	_progress_bar.max_value = Rules.BEATS_PER_RELAY
	_progress_bar.show_percentage = false
	column.add_child(_progress_bar)

	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats_label)

	var lane_row := HBoxContainer.new()
	lane_row.name = "LaneButtons"
	lane_row.add_theme_constant_override("separation", 12)
	column.add_child(lane_row)
	for lane in range(Rules.LANE_COUNT):
		var lane_button := Button.new()
		lane_button.name = "LaneButton_%d" % lane
		lane_button.text = Rules.lane_name(lane)
		lane_button.custom_minimum_size = Vector2(0.0, 112.0)
		lane_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_button.add_theme_font_size_override("font_size", 19)
		lane_button.pressed.connect(_on_lane_button_pressed.bind(lane))
		lane_row.add_child(lane_button)
		_lane_buttons.append(lane_button)

	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_feedback_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)

	var retry_button := Button.new()
	retry_button.name = "RetryButton"
	retry_button.text = "R  RETRY RELAY"
	retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry_button.pressed.connect(restart_current_relay)
	action_row.add_child(retry_button)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "N  NEXT RELAY"
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(next_relay)
	action_row.add_child(_next_button)

	var campaign_button := Button.new()
	campaign_button.name = "CampaignButton"
	campaign_button.text = "C  RESTART CAMPAIGN"
	campaign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_button.pressed.connect(restart_campaign)
	action_row.add_child(campaign_button)

	var controls := Label.new()
	controls.name = "ControlsLabel"
	controls.text = "A / S / D  hit lanes    •    R retry    •    N next    •    C restart"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	column.add_child(controls)

func _on_lane_button_pressed(lane: int) -> void:
	submit_lane_hit(lane)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A:
			submit_lane_hit(0)
		KEY_S:
			submit_lane_hit(1)
		KEY_D:
			submit_lane_hit(2)
		KEY_R:
			restart_current_relay()
		KEY_N:
			next_relay()
		KEY_C:
			restart_campaign()

func _update_ui() -> void:
	if _title_label == null:
		return
	var relay: Dictionary = Rules.get_relay(_relay_index)
	var bpm: int = int(relay.get("bpm", 72))
	_title_label.text = "KROLL PULSE REACTOR  —  %s" % str(relay.get("name", "UNKNOWN"))
	_status_label.text = "RELAY %d / %d     %d BPM     ENERGY CORE" % [_relay_index + 1, Rules.relay_count(), bpm]
	if _state == "playing":
		var lane: int = get_current_expected_lane()
		_expected_label.text = "NEXT PULSE: %s" % Rules.lane_name(lane)
	else:
		_expected_label.text = "RELAY %s" % _state.to_upper()
	_progress_bar.value = _beat_index
	_stats_label.text = "BEAT %02d / %02d     PERFECT %d     GOOD %d     MISS %d     COMBO %d     SCORE %d / 300" % [
		_beat_index, Rules.BEATS_PER_RELAY, _perfect_count, _good_count, _miss_count, _combo, _score
	]
	_feedback_label.text = _last_feedback
	for lane_index in range(_lane_buttons.size()):
		_lane_buttons[lane_index].disabled = _state != "playing"
	_next_button.disabled = _state != "complete" or _relay_index >= Rules.relay_count() - 1
