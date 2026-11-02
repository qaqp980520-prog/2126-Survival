extends Control

const ROOT_RULES_PATH := "res://daily_games/KROLL_Planetary_Climate_Lab/rules.gd"
const STANDALONE_RULES_PATH := "res://rules.gd"
const TITLE_TEXT := "KROLL // PLANETARY CLIMATE LAB"

var _rules: RefCounted
var _state: Dictionary = {}
var _planet_label: Label
var _target_label: Label
var _temperature_label: Label
var _score_label: Label
var _message_label: Label
var _albedo_value_label: Label
var _greenhouse_value_label: Label
var _temperature_bar: ProgressBar
var _albedo_slider: HSlider
var _greenhouse_slider: HSlider
var _simulate_button: Button
var _reset_button: Button
var _next_button: Button
var _restart_campaign_button: Button
var _buttons: Array[Button] = []

func _ready() -> void:
	var rules_script: Script = _resolve_rules_script()
	if rules_script == null:
		push_error("KROLL Planetary Climate Lab could not load rules.gd.")
		return
	_rules = rules_script.new()
	_state = _rules.call("create_state", 0, 0)
	_build_ui()
	_refresh()

func _resolve_rules_script() -> Script:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else STANDALONE_RULES_PATH
	var loaded: Resource = load(rules_path)
	return loaded as Script

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#07131d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#9ee7ff"))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "KROLL PLANETARY SYSTEMS · ENERGY BALANCE CONTROL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#8aa7b7"))
	column.add_child(subtitle)

	_planet_label = Label.new()
	_planet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_label.add_theme_font_size_override("font_size", 22)
	_planet_label.add_theme_color_override("font_color", Color("#f0f5f7"))
	column.add_child(_planet_label)

	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_color_override("font_color", Color("#f3c978"))
	column.add_child(_target_label)

	_temperature_label = Label.new()
	_temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_temperature_label.add_theme_font_size_override("font_size", 26)
	_temperature_label.add_theme_color_override("font_color", Color("#78e0c4"))
	column.add_child(_temperature_label)

	_temperature_bar = ProgressBar.new()
	_temperature_bar.min_value = 180.0
	_temperature_bar.max_value = 340.0
	_temperature_bar.show_percentage = false
	_temperature_bar.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(_temperature_bar)

	var parameter_panel := PanelContainer.new()
	column.add_child(parameter_panel)
	var parameter_column := VBoxContainer.new()
	parameter_column.add_theme_constant_override("separation", 10)
	parameter_panel.add_child(parameter_column)

	var albedo_heading := Label.new()
	albedo_heading.text = "SURFACE ALBEDO · REFLECTED STELLAR ENERGY"
	albedo_heading.add_theme_color_override("font_color", Color("#c7e6f2"))
	parameter_column.add_child(albedo_heading)

	var albedo_row := HBoxContainer.new()
	parameter_column.add_child(albedo_row)
	_albedo_slider = HSlider.new()
	_albedo_slider.min_value = 0.05
	_albedo_slider.max_value = 0.80
	_albedo_slider.step = 0.05
	_albedo_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_albedo_slider.custom_minimum_size = Vector2(0.0, 34.0)
	_albedo_slider.value_changed.connect(_on_albedo_changed)
	albedo_row.add_child(_albedo_slider)
	_albedo_value_label = Label.new()
	_albedo_value_label.custom_minimum_size = Vector2(76.0, 0.0)
	_albedo_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	albedo_row.add_child(_albedo_value_label)

	var greenhouse_heading := Label.new()
	greenhouse_heading.text = "GREENHOUSE RETENTION · OUTGOING HEAT FRACTION"
	greenhouse_heading.add_theme_color_override("font_color", Color("#c7e6f2"))
	parameter_column.add_child(greenhouse_heading)

	var greenhouse_row := HBoxContainer.new()
	parameter_column.add_child(greenhouse_row)
	_greenhouse_slider = HSlider.new()
	_greenhouse_slider.min_value = 0.0
	_greenhouse_slider.max_value = 0.70
	_greenhouse_slider.step = 0.05
	_greenhouse_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_greenhouse_slider.custom_minimum_size = Vector2(0.0, 34.0)
	_greenhouse_slider.value_changed.connect(_on_greenhouse_changed)
	greenhouse_row.add_child(_greenhouse_slider)
	_greenhouse_value_label = Label.new()
	_greenhouse_value_label.custom_minimum_size = Vector2(76.0, 0.0)
	_greenhouse_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	greenhouse_row.add_child(_greenhouse_value_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	column.add_child(button_row)
	_simulate_button = _make_button(button_row, "SIMULATE", _on_simulate_pressed)
	_reset_button = _make_button(button_row, "RESET PLANET", _on_reset_pressed)
	_next_button = _make_button(button_row, "NEXT PLANET", _on_next_pressed)
	_restart_campaign_button = _make_button(button_row, "NEW CAMPAIGN", _on_restart_campaign_pressed)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_color_override("font_color", Color("#9ee7ff"))
	column.add_child(_score_label)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(0.0, 44.0)
	_message_label.add_theme_color_override("font_color", Color("#d2e0e7"))
	column.add_child(_message_label)

	var controls := Label.new()
	controls.text = "KEYS · ←/→ ALBEDO · ↑/↓ GREENHOUSE · ENTER SIMULATE · R RESET · N NEXT"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_color_override("font_color", Color("#7893a1"))
	column.add_child(controls)

func _make_button(parent: HBoxContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button

func _on_albedo_changed(value: float) -> void:
	if _rules == null:
		return
	var result: Dictionary = _rules.call("set_albedo", _state, value)
	_state = result.get("state", _state)
	_refresh()

func _on_greenhouse_changed(value: float) -> void:
	if _rules == null:
		return
	var result: Dictionary = _rules.call("set_greenhouse", _state, value)
	_state = result.get("state", _state)
	_refresh()

func _on_simulate_pressed() -> void:
	simulate()

func _on_reset_pressed() -> void:
	restart_planet()

func _on_next_pressed() -> void:
	advance_planet()

func _on_restart_campaign_pressed() -> void:
	restart_campaign()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_LEFT:
			_adjust_albedo(-1)
		KEY_RIGHT:
			_adjust_albedo(1)
		KEY_UP:
			_adjust_greenhouse(1)
		KEY_DOWN:
			_adjust_greenhouse(-1)
		KEY_ENTER:
			simulate()
		KEY_R:
			restart_planet()
		KEY_N:
			advance_planet()
		_:
			return
	get_viewport().set_input_as_handled()

func _adjust_albedo(direction: int) -> void:
	var result: Dictionary = _rules.call("adjust_albedo", _state, direction)
	_state = result.get("state", _state)
	_refresh()

func _adjust_greenhouse(direction: int) -> void:
	var result: Dictionary = _rules.call("adjust_greenhouse", _state, direction)
	_state = result.get("state", _state)
	_refresh()

func set_albedo(value: float) -> bool:
	var result: Dictionary = _rules.call("set_albedo", _state, value)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func set_greenhouse(value: float) -> bool:
	var result: Dictionary = _rules.call("set_greenhouse", _state, value)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func simulate() -> bool:
	var result: Dictionary = _rules.call("simulate", _state)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func advance_planet() -> bool:
	var result: Dictionary = _rules.call("advance_planet", _state)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func restart_planet() -> bool:
	var result: Dictionary = _rules.call("restart_planet", _state)
	_state = result.get("state", _state)
	_refresh()
	return bool(result.get("ok", false))

func restart_campaign() -> bool:
	_state = _rules.call("restart_campaign")
	_refresh()
	return not _state.is_empty()

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_title_text() -> String:
	return TITLE_TEXT

func get_planet_count() -> int:
	return int(_rules.call("get_planet_count")) if _rules != null else 0

func get_slider_count() -> int:
	return 2 if is_instance_valid(_albedo_slider) and is_instance_valid(_greenhouse_slider) else 0

func get_control_button_count() -> int:
	return _buttons.size()

func _refresh() -> void:
	if _rules == null or _state.is_empty():
		return
	var index: int = int(_state.get("planet_index", 0))
	var definition: Dictionary = _rules.call("get_planet_definition", index)
	if definition.is_empty():
		return
	var minimum: float = float(definition["target_min_k"])
	var maximum: float = float(definition["target_max_k"])
	var temperature: float = float(_state.get("equilibrium_temp_k", 0.0))
	var status: String = str(_state.get("status", ""))
	_planet_label.text = "PLANET %d / %d · %s" % [index + 1, get_planet_count(), str(definition["title"])]
	_target_label.text = "TARGET BAND · %.1f–%.1f K" % [minimum, maximum]
	_temperature_label.text = "EQUILIBRIUM · %.1f K" % temperature
	_temperature_bar.value = clampf(temperature, _temperature_bar.min_value, _temperature_bar.max_value)
	_albedo_slider.set_value_no_signal(float(_state.get("albedo", 0.05)))
	_greenhouse_slider.set_value_no_signal(float(_state.get("greenhouse", 0.0)))
	_albedo_value_label.text = "%.2f" % float(_state.get("albedo", 0.0))
	_greenhouse_value_label.text = "%.2f" % float(_state.get("greenhouse", 0.0))
	_score_label.text = "CAMPAIGN SCORE · %d / 300" % int(_state.get("score", 0))
	_message_label.text = str(_state.get("last_message", ""))
	var open_for_tuning: bool = status == "tuning"
	_albedo_slider.editable = open_for_tuning
	_greenhouse_slider.editable = open_for_tuning
	_simulate_button.disabled = not open_for_tuning
	_reset_button.disabled = not open_for_tuning
	_next_button.disabled = status != "complete"
	_restart_campaign_button.disabled = status != "campaign_complete"

