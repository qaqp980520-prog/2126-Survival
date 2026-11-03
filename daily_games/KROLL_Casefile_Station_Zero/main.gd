extends Control

var _rules: RefCounted
var _state: Dictionary = {}
var _message: String = "Select one suspect and two linked evidence records."
var _suspect_buttons: Array[Button] = []
var _evidence_buttons: Array[Button] = []
var _case_label: Label
var _status_label: Label
var _score_label: Label
var _submit_button: Button
var _clear_button: Button
var _next_button: Button
var _retry_button: Button
var _campaign_button: Button

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Casefile Station Zero main script is unavailable.")
		return
	var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Casefile Station Zero could not load rules: " + rules_path)
		return
	_rules = rules_script.new() as RefCounted
	if _rules == null:
		push_error("Casefile Station Zero rules could not be instantiated.")
		return
	_state = _rules.create_state(103)
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.03, 0.055)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact_layout: bool = get_viewport_rect().size.x < 680.0
	var inset: int = 10 if compact_layout else 24
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "CasefileScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "KROLL // CASEFILE: STATION ZERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24 if compact_layout else 34)
	title.add_theme_color_override("font_color", Color(0.47, 0.88, 1.0))
	column.add_child(title)

	_case_label = Label.new()
	_case_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_case_label.add_theme_font_size_override("font_size", 20)
	_case_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.42))
	column.add_child(_case_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94))
	column.add_child(_status_label)

	var suspect_heading := Label.new()
	suspect_heading.text = "01 // SUSPECTS — SELECT ONE"
	suspect_heading.add_theme_color_override("font_color", Color(0.42, 0.83, 1.0))
	column.add_child(suspect_heading)

	var suspect_row := HBoxContainer.new()
	suspect_row.add_theme_constant_override("separation", 8)
	column.add_child(suspect_row)
	var case_definition: Dictionary = _current_case()
	for suspect in case_definition.get("suspects", []):
		var button := Button.new()
		button.text = str(suspect.get("name", "UNKNOWN")) + "\n" + str(suspect.get("role", ""))
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_suspect_pressed.bind(str(suspect.get("id", ""))))
		suspect_row.add_child(button)
		_suspect_buttons.append(button)

	var evidence_heading := Label.new()
	evidence_heading.text = "02 // EVIDENCE — SELECT TWO"
	evidence_heading.add_theme_color_override("font_color", Color(0.42, 0.83, 1.0))
	column.add_child(evidence_heading)

	var evidence_grid := GridContainer.new()
	evidence_grid.columns = 3 if not compact_layout else 1
	evidence_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_grid.add_theme_constant_override("h_separation", 8)
	evidence_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(evidence_grid)
	for evidence in case_definition.get("evidence", []):
		var button := Button.new()
		button.text = str(evidence.get("label", "RECORD")) + "\n" + str(evidence.get("text", ""))
		button.custom_minimum_size = Vector2(0.0, 112.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_evidence_pressed.bind(str(evidence.get("id", ""))))
		evidence_grid.add_child(button)
		_evidence_buttons.append(button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 7)
	column.add_child(action_row)

	_submit_button = _make_action_button(action_row, "SUBMIT", _on_submit_pressed)
	_clear_button = _make_action_button(action_row, "CLEAR", _on_clear_pressed)
	_next_button = _make_action_button(action_row, "NEXT CASE", _on_next_pressed)
	_retry_button = _make_action_button(action_row, "RETRY CASE", _on_retry_pressed)
	_campaign_button = _make_action_button(action_row, "RESET CAMPAIGN", _on_campaign_reset_pressed)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_color_override("font_color", Color(0.54, 0.9, 0.72))
	column.add_child(_score_label)

	var controls := Label.new()
	controls.text = "Keys: 1–3 suspect · Q/W/E evidence · Enter submit · Backspace clear · N next · R retry · C reset"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_color_override("font_color", Color(0.48, 0.58, 0.68))
	column.add_child(controls)

func _make_action_button(parent: HBoxContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _current_case() -> Dictionary:
	if _rules == null:
		return {}
	return _rules.get_case_definition(int(_state.get("case_index", 0)))

func _refresh_ui() -> void:
	if _rules == null:
		return
	var definition: Dictionary = _current_case()
	var case_index: int = int(_state.get("case_index", 0))
	var status: String = str(_state.get("status", "playing"))
	var selected_suspect: String = str(_state.get("selected_suspect", ""))
	var selected_evidence: Array = _state.get("selected_evidence", [])
	_case_label.text = "CASE %d / %d — %s" % [case_index + 1, _rules.get_case_count(), str(definition.get("title", ""))]
	var state_text := "STRIKES %d / 3" % int(_state.get("strikes", 0))
	if status == "case_solved":
		state_text = "CASE SOLVED — proceed to the next file."
	elif status == "victory":
		state_text = "ALL FILES CLOSED — CAMPAIGN COMPLETE."
	elif status == "failed":
		state_text = "THREE INCORRECT DEDUCTIONS — retry this case."
	_status_label.text = str(definition.get("brief", "")) + "\n" + _message + "\n" + state_text
	_score_label.text = "CAMPAIGN SCORE  %03d / %03d" % [int(_state.get("score", 0)), _rules.get_max_score()]

	var suspects: Array = definition.get("suspects", [])
	for index in range(_suspect_buttons.size()):
		var suspect_id: String = str(suspects[index].get("id", ""))
		var selected: bool = suspect_id == selected_suspect
		_suspect_buttons[index].text = ("[SELECTED] " if selected else "") + str(suspects[index].get("name", ""))
		_suspect_buttons[index].disabled = status != "playing"
		_suspect_buttons[index].modulate = Color(0.52, 0.92, 1.0) if selected else Color(1.0, 1.0, 1.0)

	var evidence: Array = definition.get("evidence", [])
	for index in range(_evidence_buttons.size()):
		var evidence_id: String = str(evidence[index].get("id", ""))
		var selected: bool = selected_evidence.has(evidence_id)
		_evidence_buttons[index].text = ("[SELECTED] " if selected else "") + str(evidence[index].get("label", "RECORD")) + "\n" + str(evidence[index].get("text", ""))
		_evidence_buttons[index].disabled = status != "playing" or (selected_evidence.size() >= 2 and not selected)
		_evidence_buttons[index].modulate = Color(0.62, 0.96, 0.8) if selected else Color(1.0, 1.0, 1.0)

	_submit_button.disabled = status != "playing" or selected_suspect.is_empty() or selected_evidence.size() != 2
	_clear_button.disabled = status != "playing" or (selected_suspect.is_empty() and selected_evidence.is_empty())
	_next_button.disabled = status != "case_solved"
	_retry_button.disabled = status != "failed"
	_campaign_button.disabled = status == "playing" and int(_state.get("case_index", 0)) == 0 and int(_state.get("score", 0)) == 0

func _on_suspect_pressed(suspect_id: String) -> void:
	if bool(_rules.select_suspect(_state, suspect_id)):
		_message = "Suspect selected. Choose two records that prove the link."
	_refresh_ui()

func _on_evidence_pressed(evidence_id: String) -> void:
	if bool(_rules.toggle_evidence(_state, evidence_id)):
		_message = "Evidence selection updated."
	else:
		_message = "Choose no more than two evidence records."
	_refresh_ui()

func _on_submit_pressed() -> void:
	var result: Dictionary = _rules.submit_deduction(_state)
	if str(result.get("reason", "")) == "incomplete":
		_message = "Select one suspect and exactly two evidence records."
	elif bool(result.get("ok", false)):
		_message = "Deduction confirmed. +100 points."
	else:
		_message = "Deduction rejected. Check the records and try again."
	_refresh_ui()

func _on_clear_pressed() -> void:
	_rules.clear_selection(_state)
	_message = "Selection cleared."
	_refresh_ui()

func _on_next_pressed() -> void:
	if bool(_rules.advance_case(_state)):
		_message = "New file opened. Review the records."
	_refresh_ui()

func _on_retry_pressed() -> void:
	if bool(_rules.restart_case(_state)):
		_message = "Case reset. You have three fresh attempts."
	_refresh_ui()

func _on_campaign_reset_pressed() -> void:
	_state = _rules.restart_campaign(103)
	_message = "Campaign reset. All three files are available."
	_refresh_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or _rules == null:
		return
	var definition: Dictionary = _current_case()
	var suspects: Array = definition.get("suspects", [])
	var evidence: Array = definition.get("evidence", [])
	match key_event.keycode:
		KEY_1, KEY_2, KEY_3:
			var suspect_index: int = int(key_event.keycode) - int(KEY_1)
			if suspect_index < suspects.size():
				_on_suspect_pressed(str(suspects[suspect_index].get("id", "")))
		KEY_Q, KEY_W, KEY_E:
			var evidence_index: int = 0 if key_event.keycode == KEY_Q else (1 if key_event.keycode == KEY_W else 2)
			if evidence_index < evidence.size():
				_on_evidence_pressed(str(evidence[evidence_index].get("id", "")))
		KEY_ENTER:
			_on_submit_pressed()
		KEY_BACKSPACE:
			_on_clear_pressed()
		KEY_N:
			_on_next_pressed()
		KEY_R:
			_on_retry_pressed()
		KEY_C:
			_on_campaign_reset_pressed()

func get_title_text() -> String:
	return "KROLL // CASEFILE: STATION ZERO"

func get_case_count() -> int:
	return _rules.get_case_count() if _rules != null else 0

func get_suspect_button_count() -> int:
	return _suspect_buttons.size()

func get_evidence_button_count() -> int:
	return _evidence_buttons.size()

func get_action_button_count() -> int:
	return 5

func get_status_text() -> String:
	return _status_label.text if is_instance_valid(_status_label) else ""
