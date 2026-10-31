extends Control

const RulesScript = preload("res://daily_games/KROLL_Crossflow_Controller/rules.gd")
const APPROACHES: Array[String] = ["north", "east", "south", "west"]

var _state: Dictionary = {}
var _timer: Timer
var _status_label: Label
var _phase_label: Label
var _progress_label: Label
var _message_label: Label
var _phase_light: ColorRect
var _queue_labels: Dictionary = {}
var _ns_button: Button
var _ew_button: Button
var _pause_button: Button
var _next_button: Button
var _paused: bool = false
var _campaign_complete: bool = false

func _ready() -> void:
	_state = RulesScript.create_state(0)
	_build_ui()
	_timer = Timer.new()
	_timer.name = "TrafficTick"
	_timer.wait_time = 0.72
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(step_once)
	_timer.start()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#07131d")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // CROSSFLOW CONTROLLER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("#63e5ff"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "KEEP THE INTERSECTION MOVING — NEVER SHOW BOTH AXES GREEN"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	column.add_child(subtitle)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_status_label)
	_phase_light = ColorRect.new()
	_phase_light.custom_minimum_size = Vector2(0.0, 9.0)
	_phase_light.color = Color("#43d98b")
	column.add_child(_phase_light)
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 17)
	column.add_child(_phase_label)
	var board := GridContainer.new()
	board.columns = 2
	board.add_theme_constant_override("h_separation", 12)
	board.add_theme_constant_override("v_separation", 8)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(board)
	for direction in APPROACHES:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(220.0, 64.0)
		board.add_child(card)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		card.add_child(label)
		_queue_labels[direction] = label
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", Color("#b9d5e0"))
	column.add_child(_progress_label)
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color("#91b4c2"))
	column.add_child(_message_label)
	var signal_row := HBoxContainer.new()
	signal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	signal_row.add_theme_constant_override("separation", 10)
	column.add_child(signal_row)
	_ns_button = Button.new()
	_ns_button.text = "N / S GREEN"
	_ns_button.custom_minimum_size = Vector2(170.0, 48.0)
	_ns_button.pressed.connect(set_signal_axis.bind(RulesScript.AXIS_NS))
	signal_row.add_child(_ns_button)
	_ew_button = Button.new()
	_ew_button.text = "E / W GREEN"
	_ew_button.custom_minimum_size = Vector2(170.0, 48.0)
	_ew_button.pressed.connect(set_signal_axis.bind(RulesScript.AXIS_EW))
	signal_row.add_child(_ew_button)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)
	_pause_button = Button.new()
	_pause_button.text = "PAUSE"
	_pause_button.custom_minimum_size = Vector2(110.0, 44.0)
	_pause_button.pressed.connect(toggle_pause)
	action_row.add_child(_pause_button)
	var reset_button := Button.new()
	reset_button.text = "RESET"
	reset_button.custom_minimum_size = Vector2(110.0, 44.0)
	reset_button.pressed.connect(reset_level)
	action_row.add_child(reset_button)
	_next_button = Button.new()
	_next_button.text = "NEXT"
	_next_button.custom_minimum_size = Vector2(110.0, 44.0)
	_next_button.pressed.connect(advance_level)
	action_row.add_child(_next_button)
	var help := Label.new()
	help.text = "Q / 1: N-S green   E / 2: E-W green   Space: pause   R: reset   N: next after quota. Signal changes always pass through an all-red clearance."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#7795a4"))
	column.add_child(help)

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_Q, KEY_1:
			set_signal_axis(RulesScript.AXIS_NS)
		KEY_E, KEY_2:
			set_signal_axis(RulesScript.AXIS_EW)
		KEY_SPACE:
			toggle_pause()
		KEY_R:
			reset_level()
		KEY_N:
			advance_level()

func set_signal_axis(axis: int) -> bool:
	var accepted: bool = RulesScript.request_signal(_state, axis)
	if accepted:
		_message_label.text = "Signal transition requested. All approaches are held during clearance."
	else:
		_message_label.text = "Signal unchanged. Wait for clearance to finish or choose the other axis."
	_refresh_ui()
	return accepted

func step_once() -> Dictionary:
	if _state.is_empty() or str(_state.get("status", "")) != "running":
		return get_current_state()
	_state = RulesScript.advance_tick(_state)
	if str(_state.get("status", "")) != "running" and _timer != null:
		_timer.stop()
	_message_label.text = _result_message()
	_refresh_ui()
	return get_current_state()

func set_paused(value: bool) -> void:
	_paused = value
	if _timer != null:
		if _paused:
			_timer.stop()
		elif str(_state.get("status", "")) == "running":
			_timer.start()
	_refresh_ui()

func toggle_pause() -> void:
	set_paused(not _paused)

func reset_level() -> void:
	var level_index: int = int(_state.get("level_index", 0))
	_state = RulesScript.create_state(level_index)
	_campaign_complete = false
	if _timer != null and not _paused:
		_timer.start()
	_message_label.text = "Shift reset. The north/south axis starts green."
	_refresh_ui()

func advance_level() -> bool:
	if str(_state.get("status", "")) != "won":
		return false
	var next_index: int = int(_state.get("level_index", 0)) + 1
	if next_index >= RulesScript.get_level_count():
		_campaign_complete = true
		_message_label.text = "All three traffic shifts completed."
		_refresh_ui()
		return true
	_state = RulesScript.create_state(next_index)
	if _timer != null and not _paused:
		_timer.start()
	_message_label.text = "New shift loaded. Plan your signal changes."
	_refresh_ui()
	return true

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_level() -> Dictionary:
	return RulesScript.get_level_data(int(_state.get("level_index", 0)))

func _on_tick_timeout() -> void:
	step_once()

func _result_message() -> String:
	match str(_state.get("status", "")):
		"won":
			return "Quota reached. Press N or NEXT for the next shift."
		"failed":
			return "Shift failed: %s. Press R to retry." % str(_state.get("reason", "unknown"))
		_:
			return str(_message_label.text) if _message_label != null else ""

func _refresh_ui() -> void:
	if _state.is_empty() or _status_label == null:
		return
	var level: Dictionary = RulesScript.get_level_data(int(_state.get("level_index", 0)))
	var counts: Dictionary = RulesScript.get_queue_counts(_state)
	_status_label.text = "%s   |   DELIVERED %d / %d" % [
		str(level.get("name", "Traffic Shift")),
		int(_state.get("delivered", 0)),
		int(_state.get("target_deliveries", 0))
	]
	_phase_label.text = RulesScript.get_phase_label(_state)
	match str(_state.get("phase", "")):
		RulesScript.PHASE_NS_GREEN:
			_phase_light.color = Color("#45df91")
		RulesScript.PHASE_EW_GREEN:
			_phase_light.color = Color("#45df91")
		RulesScript.PHASE_CLEARANCE:
			_phase_light.color = Color("#f4c65e")
		_:
			_phase_light.color = Color("#e65e6a")
	for direction in APPROACHES:
		var label: Label = _queue_labels.get(direction) as Label
		if label != null:
			label.text = "%s  //  %d / %d" % [
				direction.to_upper(),
				int(counts.get(direction, 0)),
				int(_state.get("queue_limit", 0))
			]
	_progress_label.text = "TICK %d / %d     CLEARANCE %d     CAMPAIGN %s" % [
		int(_state.get("tick", 0)),
		int(_state.get("max_ticks", 0)),
		int(_state.get("clearance_remaining", 0)),
		"COMPLETE" if _campaign_complete else "ACTIVE"
	]
	if _ns_button != null:
		_ns_button.disabled = str(_state.get("phase", "")) == RulesScript.PHASE_NS_GREEN or str(_state.get("phase", "")) == RulesScript.PHASE_CLEARANCE or str(_state.get("status", "")) != "running"
	if _ew_button != null:
		_ew_button.disabled = str(_state.get("phase", "")) == RulesScript.PHASE_EW_GREEN or str(_state.get("phase", "")) == RulesScript.PHASE_CLEARANCE or str(_state.get("status", "")) != "running"
	if _pause_button != null:
		_pause_button.text = "RESUME" if _paused else "PAUSE"
	if _next_button != null:
		_next_button.disabled = str(_state.get("status", "")) != "won"
