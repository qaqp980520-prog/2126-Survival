extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Crew_Ledger/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"

var _rules: RefCounted
var _state: Dictionary = {}
var _title_label: Label
var _case_label: Label
var _score_label: Label
var _clues_label: Label
var _message_label: Label
var _crew_labels: Array[Label] = []
var _assignment_buttons: Array[Button] = []
var _submit_button: Button
var _reset_button: Button
var _next_button: Button
var _selected_crew: int = 0

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
	var rules_script := load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Crew Ledger could not load its rules module.")
		return
	_rules = rules_script.new() as RefCounted
	_state = _rules.call("create_state", 0, 0)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.065)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 28)
	inner.add_theme_constant_override("margin_right", 28)
	inner.add_theme_constant_override("margin_top", 24)
	inner.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(inner)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	inner.add_child(column)

	_title_label = Label.new()
	_title_label.text = "KROLL // CREW LEDGER"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	column.add_child(_title_label)

	var subtitle := Label.new()
	subtitle.text = "PERSONNEL ASSIGNMENT // LOGIC REVIEW"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.64, 0.76, 0.83))
	column.add_child(subtitle)

	var header := HBoxContainer.new()
	column.add_child(header)
	_case_label = Label.new()
	_case_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_case_label.add_theme_font_size_override("font_size", 19)
	header.add_child(_case_label)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.7))
	_score_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_score_label)

	var instructions := Label.new()
	instructions.text = "Read the four clues. Tap each crew row to cycle its station. Every station must be used exactly once."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_color_override("font_color", Color(0.78, 0.84, 0.88))
	column.add_child(instructions)

	var clue_panel := PanelContainer.new()
	column.add_child(clue_panel)
	var clue_margin := MarginContainer.new()
	clue_margin.add_theme_constant_override("margin_left", 16)
	clue_margin.add_theme_constant_override("margin_right", 16)
	clue_margin.add_theme_constant_override("margin_top", 10)
	clue_margin.add_theme_constant_override("margin_bottom", 10)
	clue_panel.add_child(clue_margin)
	_clues_label = Label.new()
	_clues_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clues_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.65))
	clue_margin.add_child(_clues_label)

	var assignment_title := Label.new()
	assignment_title.text = "CREW MANIFEST // SELECT ONE UNIQUE STATION PER CREW MEMBER"
	assignment_title.add_theme_color_override("font_color", Color(0.48, 0.86, 0.94))
	column.add_child(assignment_title)

	for index in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var crew_label := Label.new()
		crew_label.custom_minimum_size = Vector2(150.0, 48.0)
		crew_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		crew_label.add_theme_font_size_override("font_size", 18)
		row.add_child(crew_label)
		_crew_labels.append(crew_label)
		var assignment_button := Button.new()
		assignment_button.custom_minimum_size = Vector2(0.0, 50.0)
		assignment_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		assignment_button.pressed.connect(_cycle_assignment.bind(index))
		row.add_child(assignment_button)
		_assignment_buttons.append(assignment_button)

	_message_label = Label.new()
	_message_label.custom_minimum_size = Vector2(0.0, 36.0)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.76))
	column.add_child(_message_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_submit_button = Button.new()
	_submit_button.text = "VERIFY MANIFEST  [ENTER]"
	_submit_button.custom_minimum_size = Vector2(0.0, 52.0)
	_submit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_submit_button.pressed.connect(_submit_case)
	actions.add_child(_submit_button)
	_reset_button = Button.new()
	_reset_button.text = "RESET  [R]"
	_reset_button.custom_minimum_size = Vector2(140.0, 52.0)
	_reset_button.pressed.connect(_reset_case)
	actions.add_child(_reset_button)
	_next_button = Button.new()
	_next_button.text = "NEXT CASE  [N]"
	_next_button.custom_minimum_size = Vector2(160.0, 52.0)
	_next_button.pressed.connect(_next_case)
	actions.add_child(_next_button)

	var footer := Label.new()
	footer.text = "KEYBOARD: 1–4 select/cycle a crew row · SPACE cycle selected row · ENTER verify · R reset · N next case"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color(0.55, 0.65, 0.72))
	column.add_child(footer)

func _cycle_assignment(crew_index: int) -> void:
	if _rules == null or str(_state.get("status", "")) != "solving":
		return
	if crew_index < 0 or crew_index >= 4:
		return
	_selected_crew = crew_index
	var assignments: Array = _state.get("assignments", [-1, -1, -1, -1])
	var current: int = int(assignments[crew_index])
	var next_station: int = (current + 1) % 4
	var result: Dictionary = _rules.call("set_assignment", _state, crew_index, next_station)
	if bool(result.get("ok", false)):
		_state = result.get("state", {}).duplicate(true)
	_refresh()

func _submit_case() -> void:
	if _rules == null:
		return
	var result: Dictionary = _rules.call("submit_case", _state)
	_state = result.get("state", _state).duplicate(true)
	if not bool(result.get("ok", false)):
		_state["last_message"] = str(result.get("reason", "Submission rejected.")).replace("_", " ").capitalize()
	_refresh()

func _reset_case() -> void:
	if _rules == null:
		return
	var result: Dictionary = _rules.call("reset_case", _state)
	if bool(result.get("ok", false)):
		_state = result.get("state", {}).duplicate(true)
	_refresh()

func _next_case() -> void:
	if _rules == null:
		return
	var result: Dictionary = _rules.call("advance_case", _state)
	if bool(result.get("ok", false)):
		_state = result.get("state", {}).duplicate(true)
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_cycle_assignment(0)
		KEY_2:
			_cycle_assignment(1)
		KEY_3:
			_cycle_assignment(2)
		KEY_4:
			_cycle_assignment(3)
		KEY_SPACE:
			_cycle_assignment(_selected_crew)
		KEY_ENTER, KEY_KP_ENTER:
			_submit_case()
		KEY_R:
			_reset_case()
		KEY_N:
			_next_case()

func _refresh() -> void:
	if _rules == null or _state.is_empty():
		return
	var definition: Dictionary = _rules.call("get_case_definition", int(_state.get("case_index", -1)))
	if definition.is_empty():
		return
	var crew: Array = definition.get("crew", [])
	var stations: Array = definition.get("stations", [])
	var assignments: Array = _state.get("assignments", [])
	_case_label.text = "CASE %d / %d  //  %s" % [int(_state.get("case_index", 0)) + 1, int(_rules.call("case_count")), str(definition.get("title", "UNKNOWN"))]
	_score_label.text = "SCORE  %03d" % int(_state.get("score", 0))
	_clues_label.text = "CLUES\n" + "\n".join(definition.get("clues", []))
	for index in range(4):
		_crew_labels[index].text = str(crew[index])
		var station_index: int = int(assignments[index])
		var station_name: String = "UNASSIGNED" if station_index < 0 else str(stations[station_index])
		_assignment_buttons[index].text = "%s  →  %s" % [str(crew[index]).to_upper(), station_name.to_upper()]
		_assignment_buttons[index].disabled = str(_state.get("status", "")) != "solving"
	_message_label.text = str(_state.get("last_message", ""))
	var status: String = str(_state.get("status", ""))
	_submit_button.disabled = status != "solving"
	_reset_button.disabled = status in ["complete", "campaign_complete"]
	_next_button.disabled = status != "complete"
	if status == "complete":
		_message_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72))
	elif status == "failed":
		_message_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.48))
	else:
		_message_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.76))

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_title_text() -> String:
	return _title_label.text if _title_label != null else "KROLL // CREW LEDGER"

func get_assignment_button_count() -> int:
	return _assignment_buttons.size()

func get_clues_text() -> String:
	return _clues_label.text if _clues_label != null else ""
