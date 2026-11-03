extends Control

const Rules = preload("res://rules.gd")
const GraphScript = preload("res://waveform_graph.gd")

var _level_index: int = 0
var _settings: Dictionary = {}
var _target: Dictionary = {}
var _start: Dictionary = {}
var _moves: int = 0
var _score: int = 0
var _solved: Array[bool] = []
var _status_label: Label
var _level_label: Label
var _score_label: Label
var _move_label: Label
var _value_labels: Dictionary = {}
var _graph: Control

func _ready() -> void:
	_build_ui()
	_start_campaign()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#07111f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL WAVEFORM CALIBRATOR"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("#e2e8f0"))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tune frequency, amplitude, phase and offset until your cyan signal matches the amber reference."
	subtitle.add_theme_color_override("font_color", Color("#94a3b8"))
	layout.add_child(subtitle)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color("#7dd3fc"))
	layout.add_child(_level_label)

	_graph = Control.new()
	_graph.name = "WaveformGraph"
	_graph.set_script(GraphScript)
	_graph.custom_minimum_size = Vector2(0, 250)
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_graph)

	var knob_row := HBoxContainer.new()
	knob_row.add_theme_constant_override("separation", 10)
	layout.add_child(knob_row)
	for knob in ["frequency", "amplitude", "phase", "offset"]:
		var knob_name := str(knob)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		panel.add_child(column)
		var heading := Label.new()
		heading.text = knob_name.to_upper()
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_color_override("font_color", Color("#cbd5e1"))
		column.add_child(heading)
		var value_label := Label.new()
		value_label.name = knob_name + "Value"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 24)
		value_label.add_theme_color_override("font_color", Color("#38bdf8"))
		column.add_child(value_label)
		_value_labels[knob_name] = value_label
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(controls)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(46, 38)
		minus.pressed.connect(_adjust_knob.bind(knob_name, -1))
		controls.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(46, 38)
		plus.pressed.connect(_adjust_knob.bind(knob_name, 1))
		controls.add_child(plus)
		knob_row.add_child(panel)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	var calibrate := Button.new()
	calibrate.text = "CALIBRATE  [SPACE]"
	calibrate.custom_minimum_size = Vector2(190, 44)
	calibrate.pressed.connect(_submit_signal)
	actions.add_child(calibrate)
	var reset := Button.new()
	reset.text = "RESET  [R]"
	reset.custom_minimum_size = Vector2(130, 44)
	reset.pressed.connect(_reset_level)
	actions.add_child(reset)
	var next := Button.new()
	next.text = "NEXT  [N]"
	next.custom_minimum_size = Vector2(130, 44)
	next.pressed.connect(_next_level)
	actions.add_child(next)
	var restart := Button.new()
	restart.text = "RESTART  [X]"
	restart.custom_minimum_size = Vector2(150, 44)
	restart.pressed.connect(_restart_campaign)
	actions.add_child(restart)

	_move_label = Label.new()
	_move_label.name = "MoveLabel"
	_move_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	layout.add_child(_move_label)
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.add_theme_font_size_override("font_size", 17)
	_score_label.add_theme_color_override("font_color", Color("#86efac"))
	layout.add_child(_score_label)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color("#fbbf24"))
	layout.add_child(_status_label)

	var instructions := Label.new()
	instructions.text = "Keys: A/D frequency · W/S amplitude · Q/E phase · Z/C offset · Space calibrate · R reset · N next · X restart"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_color_override("font_color", Color("#64748b"))
	layout.add_child(instructions)

func _start_campaign() -> void:
	_solved.clear()
	for _index in range(Rules.level_count()):
		_solved.append(false)
	_score = 0
	_level_index = 0
	_load_level()

func _load_level() -> void:
	var level := Rules.get_level(_level_index)
	_start = (level.get("start", {}) as Dictionary).duplicate(true)
	_target = (level.get("target", {}) as Dictionary).duplicate(true)
	_settings = _start.duplicate(true)
	_moves = 0
	_status_label.text = "Tune the four controls, then calibrate the signal."
	_update_ui()

func _adjust_knob(knob: String, delta: int) -> void:
	if _level_index < 0 or _level_index >= _solved.size() or _solved[_level_index]:
		return
	var adjusted := Rules.adjust_setting(_settings, knob, delta)
	if adjusted != _settings:
		_settings = adjusted
		_moves += 1
		_status_label.text = "Signal adjusted. Compare the cyan curve with the amber reference."
	_update_ui()

func _submit_signal() -> void:
	if _level_index < 0 or _level_index >= _solved.size() or _solved[_level_index]:
		return
	var error := Rules.root_mean_square_error(_settings, _target, 128)
	if Rules.is_calibrated(_settings, _target):
		_solved[_level_index] = true
		var level := Rules.get_level(_level_index)
		_score += Rules.score_for_moves(_moves, int(level.get("par", 8)))
		_status_label.text = "CALIBRATED — facility secured. Press N for the next relay."
	else:
		_status_label.text = "MISMATCH — RMS error %.3f. Keep tuning." % error
	_update_ui()

func _reset_level() -> void:
	if _level_index < 0 or _level_index >= _solved.size() or _solved[_level_index]:
		return
	_settings = _start.duplicate(true)
	_moves = 0
	_status_label.text = "Current relay reset to its starting signal."
	_update_ui()

func _next_level() -> void:
	if _level_index < 0 or _level_index >= _solved.size() or not _solved[_level_index]:
		return
	if _level_index + 1 >= Rules.level_count():
		_status_label.text = "CAMPAIGN COMPLETE — all three relays calibrated."
		_update_ui()
		return
	_level_index += 1
	_load_level()

func _restart_campaign() -> void:
	_start_campaign()

func _update_ui() -> void:
	if _level_index < 0 or _level_index >= Rules.level_count():
		return
	var level := Rules.get_level(_level_index)
	_level_label.text = "RELAY %d / %d — %s" % [_level_index + 1, Rules.level_count(), str(level.get("name", ""))]
	for knob in _value_labels.keys():
		(_value_labels[knob] as Label).text = str(_settings.get(knob, 0))
	_move_label.text = "MOVES: %d" % _moves
	_score_label.text = "CAMPAIGN SCORE: %d / 300" % _score
	_graph.call("set_waveforms", _settings, _target)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_A:
			_adjust_knob("frequency", -1)
		KEY_D:
			_adjust_knob("frequency", 1)
		KEY_S:
			_adjust_knob("amplitude", -1)
		KEY_W:
			_adjust_knob("amplitude", 1)
		KEY_Q:
			_adjust_knob("phase", -1)
		KEY_E:
			_adjust_knob("phase", 1)
		KEY_Z:
			_adjust_knob("offset", -1)
		KEY_C:
			_adjust_knob("offset", 1)
		KEY_SPACE:
			_submit_signal()
		KEY_R:
			_reset_level()
		KEY_N:
			_next_level()
		KEY_X:
			_restart_campaign()
