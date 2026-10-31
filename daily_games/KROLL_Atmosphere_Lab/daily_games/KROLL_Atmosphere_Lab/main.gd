extends Control
const Rules = preload("res://daily_games/KROLL_Atmosphere_Lab/rules.gd")

var _state: Dictionary = {}
var _reading_labels: Dictionary = {}
var _target_labels: Dictionary = {}
var _minus_buttons: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _instrument_titles: Dictionary = {}
var _selected_instrument: String = "temperature"
var _mission_label: Label
var _brief_label: Label
var _actions_label: Label
var _storm_label: Label
var _message_label: Label
var _next_button: Button

func _ready() -> void:
	_state = Rules.new_game(0)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "KROLL ATMOSPHERE LAB"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#82e8ff"))
	column.add_child(title)

	_mission_label = Label.new()
	_mission_label.add_theme_font_size_override("font_size", 20)
	_mission_label.add_theme_color_override("font_color", Color("#f1f6fa"))
	column.add_child(_mission_label)

	_brief_label = Label.new()
	_brief_label.custom_minimum_size = Vector2(0.0, 36.0)
	_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_label.add_theme_color_override("font_color", Color("#b8cbd4"))
	column.add_child(_brief_label)

	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 14)
	cards.add_theme_constant_override("v_separation", 12)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for instrument in Rules.INSTRUMENTS:
		_build_instrument_card(cards, instrument)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	_actions_label = Label.new()
	_actions_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(_actions_label)
	_storm_label = Label.new()
	_storm_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(_storm_label)

	_message_label = Label.new()
	_message_label.custom_minimum_size = Vector2(0.0, 36.0)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color("#f5d58a"))
	column.add_child(_message_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var reset_button := Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "RESET MISSION"
	reset_button.custom_minimum_size = Vector2(180.0, 44.0)
	reset_button.pressed.connect(_reset)
	actions.add_child(reset_button)
	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "NEXT STATION"
	_next_button.custom_minimum_size = Vector2(180.0, 44.0)
	_next_button.pressed.connect(_next_level)
	actions.add_child(_next_button)
	var hint := Label.new()
	hint.text = "Select an instrument card, then use −5 / +5. Keyboard: 1–4 select · ←/→ adjust · R reset · N next."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#91a8b4"))
	actions.add_child(hint)

func _build_instrument_card(parent: GridContainer, instrument: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420.0, 150.0)
	parent.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	card.add_child(inner)
	var heading := Label.new()
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color("#8ce5f3"))
	inner.add_child(heading)
	_instrument_titles[instrument] = heading
	var reading := Label.new()
	reading.add_theme_font_size_override("font_size", 26)
	reading.add_theme_color_override("font_color", Color("#ffffff"))
	inner.add_child(reading)
	_reading_labels[instrument] = reading
	var target := Label.new()
	target.add_theme_color_override("font_color", Color("#b8cbd4"))
	inner.add_child(target)
	_target_labels[instrument] = target
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	inner.add_child(controls)
	var minus := Button.new()
	minus.name = instrument.capitalize() + "Minus"
	minus.text = "−5"
	minus.custom_minimum_size = Vector2(100.0, 38.0)
	minus.focus_mode = Control.FOCUS_NONE
	minus.pressed.connect(_adjust.bind(instrument, -1))
	controls.add_child(minus)
	_minus_buttons[instrument] = minus
	var plus := Button.new()
	plus.name = instrument.capitalize() + "Plus"
	plus.text = "+5"
	plus.custom_minimum_size = Vector2(100.0, 38.0)
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(_adjust.bind(instrument, 1))
	controls.add_child(plus)
	_plus_buttons[instrument] = plus

func _adjust(instrument: String, direction: int) -> void:
	var before: Dictionary = _state.get("readings", {}).duplicate(true)
	_state = Rules.adjust(_state, instrument, direction)
	if before == _state.get("readings", {}):
		_message_label.text = "No adjustment: the instrument is at its limit or the station is locked."
	else:
		_selected_instrument = instrument
		_message_label.text = "%s adjusted. Recheck the storm load before spending the next action." % instrument.capitalize()
		if str(_state.get("status", "")) == "complete":
			_message_label.text = "Forecast stabilized. All four readings match the target."
		elif str(_state.get("status", "")) == "failed":
			_message_label.text = "Action budget exhausted. Reset the station and try a different order."
	_refresh()

func _reset() -> void:
	_state = Rules.reset(_state)
	_selected_instrument = "temperature"
	_message_label.text = "Station reset. Plan the instrument changes before using the action budget."
	_refresh()

func _next_level() -> void:
	var previous_index: int = int(_state.get("level_index", 0))
	_state = Rules.next_level(_state)
	if int(_state.get("level_index", 0)) == previous_index:
		_message_label.text = "Match every target reading and keep storm load below the limit to unlock the next station."
	else:
		_message_label.text = "New weather station loaded."
	_selected_instrument = "temperature"
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: _selected_instrument = "temperature"
		KEY_2: _selected_instrument = "humidity"
		KEY_3: _selected_instrument = "pressure"
		KEY_4: _selected_instrument = "wind"
		KEY_LEFT: _adjust(_selected_instrument, -1)
		KEY_RIGHT: _adjust(_selected_instrument, 1)
		KEY_R: _reset()
		KEY_N: _next_level()
		_: return
	_refresh()

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func _refresh() -> void:
	var level: Dictionary = Rules.get_level(int(_state.get("level_index", 0)))
	var readings: Dictionary = _state.get("readings", {})
	var target: Dictionary = level.get("target", {})
	_mission_label.text = "STATION %02d  //  %s" % [int(_state.get("level_index", 0)) + 1, str(level.get("name", "WEATHER STATION"))]
	_brief_label.text = str(level.get("brief", ""))
	for instrument in Rules.INSTRUMENTS:
		_instrument_titles[instrument].text = ("> " if instrument == _selected_instrument else "") + instrument.to_upper()
		_reading_labels[instrument].text = "%d %s" % [int(readings.get(instrument, 0)), _unit(instrument)]
		_target_labels[instrument].text = "TARGET  %d %s" % [int(target.get(instrument, 0)), _unit(instrument)]
		var bounds: Vector2i = Rules.LIMITS[instrument]
		var playing: bool = str(_state.get("status", "")) == "playing"
		_minus_buttons[instrument].disabled = not playing or int(readings[instrument]) - Rules.STEP < bounds.x
		_plus_buttons[instrument].disabled = not playing or int(readings[instrument]) + Rules.STEP > bounds.y
	var assessment: Dictionary = Rules.evaluate(_state)
	_actions_label.text = "ACTIONS  %02d / %02d" % [int(_state.get("actions_left", 0)), int(level.get("budget", 0))]
	_storm_label.text = "STORM  %02d / %02d" % [int(assessment.get("storm_load", 0)), int(assessment.get("storm_limit", 0))]
	_next_button.disabled = str(_state.get("status", "")) != "complete"
	if str(_state.get("status", "")) == "complete":
		_message_label.text = "FORECAST STABLE  //  NEXT STATION UNLOCKED"
	elif str(_state.get("status", "")) == "failed":
		_message_label.text = "FORECAST MISSED  //  RESET TO RETRY"
	elif _message_label.text.is_empty():
		_message_label.text = "Choose the instrument adjustments carefully. Each ±5 change costs one action."

func _unit(instrument: String) -> String:
	match instrument:
		"temperature": return "°C"
		"humidity": return "%"
		"pressure": return "hPa"
		"wind": return "km/h"
	return ""
