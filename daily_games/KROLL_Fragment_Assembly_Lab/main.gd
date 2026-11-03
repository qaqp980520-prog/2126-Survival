extends Control

var rules: Variant
var state: Dictionary = {}
var title_label: Label
var progress_label: Label
var score_label: Label
var sequence_label: Label
var status_label: Label
var error_label: Label
var fragment_grid: GridContainer
var next_button: Button
var restart_button: Button

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Fragment Assembly Lab main script is unavailable.")
		return
	var script_directory: String = attached_script.resource_path.get_base_dir()
	var rules_path: String = script_directory.path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Fragment Assembly Lab could not load rules: " + rules_path)
		return
	rules = rules_script.new()
	state = rules.create_state()
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#07111e")
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

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#102238")
	panel_style.border_color = Color("#31516d")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)

	title_label = Label.new()
	title_label.text = "KROLL // FRAGMENT ASSEMBLY LAB"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("#9be7ff"))
	title_label.add_theme_font_size_override("font_size", 27)
	content.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "拼接重疊片段，重建三組虛構樣本序列。這是字串邏輯遊戲，不是生物實驗流程。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#b6c8d8"))
	content.add_child(subtitle)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	content.add_child(info_row)

	progress_label = Label.new()
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.add_theme_color_override("font_color", Color("#f4d58d"))
	progress_label.add_theme_font_size_override("font_size", 17)
	info_row.add_child(progress_label)

	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_color_override("font_color", Color("#a8e6cf"))
	info_row.add_child(score_label)

	var sequence_panel := PanelContainer.new()
	var sequence_style := StyleBoxFlat.new()
	sequence_style.bg_color = Color("#081725")
	sequence_style.border_color = Color("#254b61")
	sequence_style.set_border_width_all(1)
	sequence_style.set_corner_radius_all(10)
	sequence_panel.add_theme_stylebox_override("panel", sequence_style)
	content.add_child(sequence_panel)

	sequence_label = Label.new()
	sequence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sequence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sequence_label.add_theme_color_override("font_color", Color("#e6f4ff"))
	sequence_label.add_theme_font_size_override("font_size", 23)
	sequence_label.custom_minimum_size = Vector2(0.0, 88.0)
	sequence_panel.add_child(sequence_label)

	var guidance := Label.new()
	guidance.text = "規則：片段開頭必須與目前序列結尾至少重疊 2 個字元，而且拼接後必須仍是目標序列的前綴。"
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance.add_theme_color_override("font_color", Color("#9eb5c8"))
	content.add_child(guidance)

	fragment_grid = GridContainer.new()
	fragment_grid.columns = 2
	fragment_grid.add_theme_constant_override("h_separation", 10)
	fragment_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(fragment_grid)

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color("#ffbd9d"))
	content.add_child(error_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#b8d8ec"))
	content.add_child(status_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	content.add_child(controls)

	restart_button = Button.new()
	restart_button.text = "RESTART LAB  [R]"
	restart_button.custom_minimum_size = Vector2(190.0, 48.0)
	restart_button.pressed.connect(_on_restart_pressed)
	controls.add_child(restart_button)

	next_button = Button.new()
	next_button.text = "NEXT LAB  [N]"
	next_button.custom_minimum_size = Vector2(190.0, 48.0)
	next_button.pressed.connect(_on_next_pressed)
	controls.add_child(next_button)

func _refresh_ui() -> void:
	var level_index: int = int(state.get("level_index", 0))
	var level_name: String = str(state.get("level_name", "UNKNOWN"))
	var status: String = str(state.get("status", "playing"))
	progress_label.text = "LAB %02d / %02d   %s" % [level_index + 1, rules.get_level_count(), level_name]
	score_label.text = "TOTAL  %03d" % int(state.get("total_score", 0))
	sequence_label.text = "ASSEMBLED SEQUENCE\n" + str(state.get("sequence", ""))
	error_label.text = "MISMATCHES  %d / %d" % [int(state.get("errors", 0)), int(state.get("max_errors", 3))]
	status_label.text = str(state.get("last_message", ""))

	for child in fragment_grid.get_children():
		fragment_grid.remove_child(child)
		child.queue_free()

	var available: Array = rules.get_available_fragments(state)
	for index in range(available.size()):
		var fragment: Dictionary = available[index]
		var fragment_id: String = str(fragment.get("id", ""))
		var sequence: String = str(fragment.get("sequence", ""))
		var button := Button.new()
		button.text = "%d   %s   ·   %s" % [index + 1, fragment_id, sequence]
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_fragment_pressed.bind(fragment_id))
		fragment_grid.add_child(button)

	next_button.disabled = status != "level_passed"
	restart_button.disabled = status == "level_passed" or status == "campaign_passed"
	if status == "failed":
		restart_button.disabled = false
	if status == "campaign_passed":
		next_button.disabled = true
		next_button.text = "CAMPAIGN COMPLETE"

func perform_fragment(fragment_id: String) -> void:
	state = rules.attempt_fragment(state, fragment_id)
	_refresh_ui()

func advance_level() -> void:
	state = rules.next_level(state)
	_refresh_ui()

func restart_current_level() -> void:
	state = rules.restart_level(state)
	_refresh_ui()

func get_state() -> Dictionary:
	return state.duplicate(true)

func get_title_text() -> String:
	return title_label.text if is_instance_valid(title_label) else "KROLL // FRAGMENT ASSEMBLY LAB"

func get_level_count() -> int:
	return Rules.get_level_count()

func get_fragment_button_count() -> int:
	return fragment_grid.get_child_count() if is_instance_valid(fragment_grid) else 0

func get_sequence_text() -> String:
	return str(state.get("sequence", ""))

func get_control_button_count() -> int:
	return 2

func _on_fragment_pressed(fragment_id: String) -> void:
	perform_fragment(fragment_id)

func _on_next_pressed() -> void:
	advance_level()

func _on_restart_pressed() -> void:
	restart_current_level()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			restart_current_level()
			get_viewport().set_input_as_handled()
		KEY_N:
			advance_level()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var index: int = int(key_event.keycode - KEY_1)
			var available: Array = Rules.get_available_fragments(state)
			if index >= 0 and index < available.size():
				perform_fragment(str(available[index].get("id", "")))
				get_viewport().set_input_as_handled()
