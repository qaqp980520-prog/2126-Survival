extends Control

const ROOT_RULES_PATH: String = "res://daily_games/KROLL_Wind_Farm_Dispatch/rules.gd"
const LOCAL_RULES_PATH: String = "res://rules.gd"
const DIRECTIONS: Array[String] = ["N", "E", "S", "W"]
const BATTERY_CAPACITY: int = 8
const TRIP_HEAT: int = 6

var _rules: RefCounted
var _state: Dictionary = {}
var _selected_turbine: int = 0
var _scenario_label: Label
var _weather_label: Label
var _battery_label: Label
var _status_label: Label
var _selection_label: Label
var _turbine_cards: Array[Dictionary] = []
var _commit_button: Button
var _next_button: Button

func _ready() -> void:
	var rules_path: String = ROOT_RULES_PATH if ResourceLoader.exists(ROOT_RULES_PATH) else LOCAL_RULES_PATH
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("KROLL Wind Farm Dispatch could not load its rules module.")
		return
	_rules = rules_script.new() as RefCounted
	_state = _rules.call("make_state", 0)
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#08151b")
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
	title.text = "KROLL // WIND FARM DISPATCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#80e5f2"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ALIGN THREE TURBINES • BALANCE GRID DEMAND • MANAGE HEAT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#a9c3cc"))
	column.add_child(subtitle)
	_scenario_label = Label.new()
	_scenario_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scenario_label.add_theme_font_size_override("font_size", 22)
	_scenario_label.add_theme_color_override("font_color", Color("#f0d59c"))
	column.add_child(_scenario_label)
	_weather_label = Label.new()
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weather_label.add_theme_font_size_override("font_size", 18)
	_weather_label.add_theme_color_override("font_color", Color("#d5e7ed"))
	column.add_child(_weather_label)
	_battery_label = Label.new()
	_battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battery_label.add_theme_font_size_override("font_size", 16)
	_battery_label.add_theme_color_override("font_color", Color("#a9e4bd"))
	column.add_child(_battery_label)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for index in range(3):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(300.0, 300.0)
		cards.add_child(panel)
		var card_column := VBoxContainer.new()
		card_column.add_theme_constant_override("separation", 10)
		panel.add_child(card_column)
		var heading := Label.new()
		heading.text = "TURBINE %d" % (index + 1)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", 20)
		card_column.add_child(heading)
		var yaw_label := Label.new()
		yaw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_column.add_child(yaw_label)
		var pitch_label := Label.new()
		pitch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_column.add_child(pitch_label)
		var heat_label := Label.new()
		heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_column.add_child(heat_label)
		var output_label := Label.new()
		output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		output_label.add_theme_color_override("font_color", Color("#83dce8"))
		card_column.add_child(output_label)
		var yaw_row := HBoxContainer.new()
		yaw_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card_column.add_child(yaw_row)
		var yaw_left := _make_button("YAW -", yaw_row, _change_yaw.bind(index, -1))
		var yaw_right := _make_button("YAW +", yaw_row, _change_yaw.bind(index, 1))
		var pitch_row := HBoxContainer.new()
		pitch_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card_column.add_child(pitch_row)
		var pitch_down := _make_button("PITCH -", pitch_row, _change_pitch.bind(index, -1))
		var pitch_up := _make_button("PITCH +", pitch_row, _change_pitch.bind(index, 1))
		var select_button := _make_button("SELECT TURBINE", card_column, _select_turbine.bind(index))
		_turbine_cards.append({
			"heading":heading,
			"yaw":yaw_label,
			"pitch":pitch_label,
			"heat":heat_label,
			"output":output_label,
			"yaw_left":yaw_left,
			"yaw_right":yaw_right,
			"pitch_down":pitch_down,
			"pitch_up":pitch_up,
			"select":select_button
		})
	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.add_theme_color_override("font_color", Color("#f0d59c"))
	column.add_child(_selection_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_status_label.add_theme_color_override("font_color", Color("#b8d3db"))
	column.add_child(_status_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_commit_button = _make_button("COMMIT ROUND", actions, commit_current_round)
	_commit_button.custom_minimum_size = Vector2(180.0, 48.0)
	var reset_button := _make_button("RESET ARRAY", actions, _reset_scenario)
	reset_button.custom_minimum_size = Vector2(150.0, 48.0)
	_next_button = _make_button("NEXT ARRAY", actions, advance_to_next_scenario)
	_next_button.custom_minimum_size = Vector2(180.0, 48.0)
	var help := Label.new()
	help.text = "Keys: 1-3 select turbine · Q/E yaw · W/S pitch · Space commit · R reset · N next array"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#7897a2"))
	column.add_child(help)

func _make_button(label_text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(112.0, 42.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _change_yaw(index: int, delta: int) -> void:
	if _rules == null or _state.is_empty():
		return
	var turbines: Array = _state["turbines"]
	var yaw: int = posmod(int(turbines[index]["yaw"]) + delta, 4)
	var result: Dictionary = _rules.call("set_turbine_yaw", _state, index, yaw)
	if bool(result.get("ok", false)):
		_state = result["state"]
		_selected_turbine = index
		_refresh_ui()

func _change_pitch(index: int, delta: int) -> void:
	if _rules == null or _state.is_empty():
		return
	var turbines: Array = _state["turbines"]
	var pitch: int = clampi(int(turbines[index]["pitch"]) + delta, 0, 3)
	var result: Dictionary = _rules.call("set_turbine_pitch", _state, index, pitch)
	if bool(result.get("ok", false)):
		_state = result["state"]
		_selected_turbine = index
		_refresh_ui()

func _select_turbine(index: int) -> void:
	_selected_turbine = clampi(index, 0, 2)
	_refresh_ui()

func commit_current_round() -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("resolve_round", _state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_refresh_ui()
	return true

func advance_to_next_scenario() -> bool:
	if _rules == null:
		return false
	var result: Dictionary = _rules.call("advance_scenario", _state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_selected_turbine = 0
	_refresh_ui()
	return true

func _reset_scenario() -> void:
	if _rules == null:
		return
	_state = _rules.call("reset_state", _state)
	_selected_turbine = 0
	_refresh_ui()

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_scenario() -> Dictionary:
	return _rules.call("get_scenario", int(_state.get("scenario_index", -1))) if _rules != null else {}

func get_turbine_card_count() -> int:
	return _turbine_cards.size()

func _refresh_ui() -> void:
	if _rules == null or _state.is_empty():
		return
	var scenario_index: int = int(_state["scenario_index"])
	var scenario: Dictionary = _rules.call("get_scenario", scenario_index)
	var weather: Dictionary = _rules.call("get_current_weather", _state)
	var progress: Dictionary = _rules.call("get_progress", _state)
	_scenario_label.text = "%s  //  ARRAY %d / %d" % [str(scenario.get("name", "Wind Farm")), scenario_index + 1, int(_rules.call("get_scenario_count"))]
	if weather.is_empty():
		_weather_label.text = "WEATHER WINDOW CLOSED"
	else:
		_weather_label.text = "WIND %s  ·  SPEED %d  ·  GRID DEMAND %d" % [
			DIRECTIONS[int(weather["wind_direction"])],
			int(weather["wind_speed"]),
			int(weather["demand"])
		]
	_battery_label.text = "BATTERY %d / %d    ROUND %d / %d" % [
		int(_state["battery"]),
		BATTERY_CAPACITY,
		int(progress["round"]),
		int(progress["total_rounds"])
	]
	var turbines: Array = _state["turbines"]
	var outputs: Array = _rules.call("get_estimated_outputs", _state)
	for index in range(_turbine_cards.size()):
		var turbine: Dictionary = turbines[index]
		var card: Dictionary = _turbine_cards[index]
		var online: bool = bool(turbine["online"])
		card["heading"].text = "TURBINE %d%s" % [index + 1, "  ◀ SELECTED" if index == _selected_turbine else ""]
		card["yaw"].text = "YAW: %s" % DIRECTIONS[int(turbine["yaw"])]
		card["pitch"].text = "BLADE PITCH: %d / 3" % int(turbine["pitch"])
		card["heat"].text = "HEAT: %d / %d  ·  %s" % [int(turbine["heat"]), TRIP_HEAT, "ONLINE" if online else "TRIPPED"]
		card["output"].text = "ESTIMATED OUTPUT: %d" % int(outputs[index]) if index < outputs.size() else "ESTIMATED OUTPUT: —"
		for key in ["yaw_left","yaw_right","pitch_down","pitch_up"]:
			card[key].disabled = str(_state["status"]) != "playing" or not online
		card["select"].disabled = str(_state["status"]) != "playing"
	var status: String = str(_state["status"])
	match status:
		"failed":
			_status_label.text = "GRID SHORTFALL — reset the array and tune yaw, pitch and battery use."
		"won":
			_status_label.text = "ARRAY STABLE — all demand served. Advance to the next wind site."
		"campaign_complete":
			_status_label.text = "ALL THREE ARRAYS STABLE — regional dispatch complete."
		_:
			_status_label.text = str(scenario.get("brief", "Tune each turbine before committing the round."))
	_commit_button.disabled = status != "playing"
	_next_button.disabled = status != "won"
	_next_button.text = "CAMPAIGN COMPLETE" if status == "campaign_complete" else "NEXT ARRAY"

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1: _select_turbine(0)
		KEY_2: _select_turbine(1)
		KEY_3: _select_turbine(2)
		KEY_Q: _change_yaw(_selected_turbine, -1)
		KEY_E: _change_yaw(_selected_turbine, 1)
		KEY_W: _change_pitch(_selected_turbine, 1)
		KEY_S: _change_pitch(_selected_turbine, -1)
		KEY_SPACE: commit_current_round()
		KEY_R: _reset_scenario()
		KEY_N: advance_to_next_scenario()
