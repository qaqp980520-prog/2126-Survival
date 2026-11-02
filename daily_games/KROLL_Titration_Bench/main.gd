extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Titration_Bench/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"

class PHGraph extends Control:
	var _readings: Array = []

	func set_readings(readings: Array) -> void:
		_readings = readings.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.075))
		var plot := Rect2(Vector2(38.0, 12.0), Vector2(maxf(1.0, size.x - 52.0), maxf(1.0, size.y - 30.0)))
		for tick in range(0, 15, 2):
			var y: float = plot.position.y + (1.0 - float(tick) / 14.0) * plot.size.y
			draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), Color(0.16, 0.25, 0.31), 1.0)
		var endpoint_y: float = plot.position.y + 0.5 * plot.size.y
		draw_line(Vector2(plot.position.x, endpoint_y), Vector2(plot.position.x + plot.size.x, endpoint_y), Color(0.35, 0.78, 0.58, 0.7), 1.5)
		draw_line(plot.position, Vector2(plot.position.x, plot.position.y + plot.size.y), Color(0.42, 0.62, 0.72), 1.5)
		draw_line(Vector2(plot.position.x, plot.position.y + plot.size.y), Vector2(plot.position.x + plot.size.x, plot.position.y + plot.size.y), Color(0.42, 0.62, 0.72), 1.5)
		var points := PackedVector2Array()
		for reading in _readings:
			if not reading is Dictionary:
				continue
			var volume: float = clampf(float(reading.get("volume_ml", 0.0)), 0.0, 60.0)
			var ph: float = clampf(float(reading.get("ph", 7.0)), 0.0, 14.0)
			var point := Vector2(
				plot.position.x + volume / 60.0 * plot.size.x,
				plot.position.y + (1.0 - ph / 14.0) * plot.size.y
			)
			points.append(point)
		if points.size() >= 2:
			draw_polyline(points, Color(0.34, 0.83, 1.0), 2.5, true)
		for point in points:
			draw_circle(point, 3.5, Color(0.94, 0.76, 0.36))

var _rules: RefCounted
var _state: Dictionary = {}
var _title_label: Label
var _sample_label: Label
var _score_label: Label
var _info_label: Label
var _readout_label: Label
var _message_label: Label
var _graph: PHGraph
var _buttons: Array[Button] = []
var _submit_button: Button
var _restart_sample_button: Button
var _next_button: Button

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
	var rules_script := load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Titration Bench could not load its rules module.")
		return
	_rules = rules_script.new() as RefCounted
	_state = _rules.call("create_state", 0, 0)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.035, 0.052)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 24)
	inner.add_theme_constant_override("margin_right", 24)
	inner.add_theme_constant_override("margin_top", 20)
	inner.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(inner)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	inner.add_child(column)

	_title_label = Label.new()
	_title_label.text = "KROLL // TITRATION BENCH"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	column.add_child(_title_label)

	var header := HBoxContainer.new()
	column.add_child(header)
	_sample_label = Label.new()
	_sample_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_label.add_theme_font_size_override("font_size", 19)
	header.add_child(_sample_label)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.7))
	_score_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_score_label)

	_info_label = Label.new()
	_info_label.text = "SIMULATED STRONG-ACID TITRATION · 25.0 mL SAMPLE · 0.100 M NaOH TITRANT"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_color_override("font_color", Color(0.75, 0.83, 0.88))
	column.add_child(_info_label)

	_readout_label = Label.new()
	_readout_label.add_theme_font_size_override("font_size", 21)
	_readout_label.add_theme_color_override("font_color", Color(0.91, 0.91, 0.78))
	column.add_child(_readout_label)

	var graph_note := Label.new()
	graph_note.text = "LIVE pH CURVE · X: BASE ADDED (mL) · Y: pH 0–14 · GREEN LINE: pH 7"
	graph_note.add_theme_color_override("font_color", Color(0.54, 0.7, 0.78))
	column.add_child(graph_note)
	_graph = PHGraph.new()
	_graph.name = "PHCurve"
	_graph.custom_minimum_size = Vector2(0.0, 190.0)
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_graph)

	var addition_row := HBoxContainer.new()
	addition_row.add_theme_constant_override("separation", 8)
	column.add_child(addition_row)
	_add_button(addition_row, "ADD 0.5 mL  [Q]", Callable(self, "add_titrant").bind(0.5))
	_add_button(addition_row, "ADD 1.0 mL  [W]", Callable(self, "add_titrant").bind(1.0))
	_add_button(addition_row, "ADD 2.5 mL  [E]", Callable(self, "add_titrant").bind(2.5))
	_submit_button = _add_button(addition_row, "LOCK ENDPOINT  [ENTER]", Callable(self, "submit_endpoint"))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	_restart_sample_button = _add_button(action_row, "RESTART SAMPLE  [R]", Callable(self, "restart_sample"))
	_next_button = _add_button(action_row, "NEXT SAMPLE  [N]", Callable(self, "advance_sample"))
	_add_button(action_row, "NEW CAMPAIGN", Callable(self, "restart_campaign"))

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 15)
	_message_label.add_theme_color_override("font_color", Color(0.52, 0.88, 0.72))
	column.add_child(_message_label)

	var hint := Label.new()
	hint.text = "BROMOTHYMOL-BLUE MODEL: YELLOW → GREEN → BLUE · STOP NEAR THE SHARP pH CHANGE"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.52, 0.64, 0.72))
	column.add_child(hint)

func _add_button(parent: HBoxContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(150.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			add_titrant(0.5)
		KEY_W:
			add_titrant(1.0)
		KEY_E:
			add_titrant(2.5)
		KEY_ENTER, KEY_KP_ENTER:
			submit_endpoint()
		KEY_R:
			restart_sample()
		KEY_N:
			advance_sample()

func add_titrant(amount_ml: float) -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("add_titrant", _state, amount_ml)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func submit_endpoint() -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("submit_endpoint", _state)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func restart_sample() -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("restart_sample", _state)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func advance_sample() -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("advance_sample", _state)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func restart_campaign() -> bool:
	if _rules == null:
		return false
	_state = _rules.call("restart_campaign")
	_refresh()
	return not _state.is_empty()

func _refresh() -> void:
	if _state.is_empty() or _rules == null:
		return
	var index: int = int(_state.get("sample_index", 0))
	var definition: Dictionary = _rules.call("get_sample_definition", index)
	_sample_label.text = "%s  ·  SAMPLE %d / %d" % [
		str(definition.get("title", "UNKNOWN")),
		index + 1,
		int(_rules.call("get_sample_count"))
	]
	_score_label.text = "SCORE %03d" % int(_state.get("score", 0))
	_info_label.text = "SIMULATED STRONG-ACID TITRATION · %.1f mL SAMPLE · %.3f M NaOH TITRANT" % [
		float(definition.get("acid_volume_ml", 25.0)),
		float(definition.get("titrant_molarity", 0.1))
	]
	_readout_label.text = "BASE ADDED %.1f mL     pH %.2f     %s" % [
		float(_state.get("volume_added_ml", 0.0)),
		float(_state.get("ph", 7.0)),
		str(_state.get("indicator", "YELLOW · ACID"))
	]
	_message_label.text = str(_state.get("last_message", ""))
	if _graph != null:
		_graph.set_readings(_state.get("readings", []))
	var status: String = str(_state.get("status", ""))
	_submit_button.disabled = status != "titrating"
	_restart_sample_button.disabled = status == "complete" or status == "campaign_complete"
	_next_button.disabled = status != "complete"

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_title_text() -> String:
	return _title_label.text if _title_label != null else "KROLL // TITRATION BENCH"

func get_sample_count() -> int:
	return int(_rules.call("get_sample_count")) if _rules != null else 0

func get_control_button_count() -> int:
	return _buttons.size()
