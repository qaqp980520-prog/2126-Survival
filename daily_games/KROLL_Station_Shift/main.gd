extends Control

const Rules = preload("res://rules.gd")

var scenario_index: int = 0
var state: Dictionary = {}
var selected_sector: int = 0
var resource_labels: Dictionary = {}
var crew_value_labels: Array[Label] = []
var event_label: Label
var assignment_label: Label
var status_label: Label
var run_button: Button

func _ready() -> void:
	_build_ui()
	_start_scenario(0)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.018, 0.032, 0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "KROLL // STATION SHIFT"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "SIX CYCLES. FIVE CREW. THREE SYSTEMS. KEEP THE OUTPOST ONLINE."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	column.add_child(subtitle)

	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 14)
	column.add_child(resource_row)
	_add_resource_card(resource_row, "ENERGY", "EnergyValue")
	_add_resource_card(resource_row, "OXYGEN", "OxygenValue")
	_add_resource_card(resource_row, "HULL", "HullValue")

	event_label = Label.new()
	event_label.name = "EventForecast"
	event_label.custom_minimum_size = Vector2(0, 72)
	event_label.add_theme_font_size_override("font_size", 16)
	event_label.add_theme_color_override("font_color", Color(0.94, 0.79, 0.48))
	column.add_child(event_label)

	var crew_title := Label.new()
	crew_title.text = "CREW ASSIGNMENT — KEEP AT LEAST ONE PERSON IN EACH STATION"
	crew_title.add_theme_font_size_override("font_size", 16)
	crew_title.add_theme_color_override("font_color", Color(0.75, 0.91, 0.97))
	column.add_child(crew_title)

	_add_crew_row(column, 0, "1  POWER")
	_add_crew_row(column, 1, "2  LIFE SUPPORT")
	_add_crew_row(column, 2, "3  REPAIRS")

	assignment_label = Label.new()
	assignment_label.name = "AssignmentStatus"
	assignment_label.add_theme_font_size_override("font_size", 14)
	assignment_label.add_theme_color_override("font_color", Color(0.65, 0.84, 0.9))
	column.add_child(assignment_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)
	run_button = Button.new()
	run_button.name = "RunCycleButton"
	run_button.text = "RUN CYCLE  [ENTER]"
	run_button.custom_minimum_size = Vector2(220, 48)
	run_button.pressed.connect(_run_cycle)
	action_row.add_child(run_button)

	var reset_button := Button.new()
	reset_button.name = "RestartButton"
	reset_button.text = "RESTART  [R]"
	reset_button.custom_minimum_size = Vector2(140, 48)
	reset_button.pressed.connect(_restart_scenario)
	action_row.add_child(reset_button)

	var next_button := Button.new()
	next_button.name = "NextScenarioButton"
	next_button.text = "NEXT SCENARIO  [N]"
	next_button.custom_minimum_size = Vector2(190, 48)
	next_button.pressed.connect(_next_scenario)
	action_row.add_child(next_button)

	status_label = Label.new()
	status_label.name = "StatusMessage"
	status_label.custom_minimum_size = Vector2(0, 54)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.74))
	column.add_child(status_label)

	var help := Label.new()
	help.text = "Select a station with 1–3. Use - / = to move one crew member, then ENTER to run the cycle. Crew changes are applied before the next event."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.48, 0.6, 0.7))
	column.add_child(help)

func _add_resource_card(parent: HBoxContainer, caption: String, value_name: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	card.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.5, 0.72, 0.82))
	box.add_child(label)
	var value := Label.new()
	value.name = value_name
	value.add_theme_font_size_override("font_size", 28)
	value.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	box.add_child(value)
	resource_labels[caption.to_lower()] = value
	parent.add_child(card)

func _add_crew_row(parent: VBoxContainer, sector: int, caption: String) -> void:
	var row := HBoxContainer.new()
	row.name = "CrewRow" + ["Power", "Life", "Repair"][sector]
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(190, 38)
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)
	var minus := Button.new()
	minus.name = ["CrewPowerMinus", "CrewLifeMinus", "CrewRepairMinus"][sector]
	minus.text = "−"
	minus.custom_minimum_size = Vector2(54, 40)
	minus.pressed.connect(_change_crew.bind(sector, -1))
	row.add_child(minus)
	var value := Label.new()
	value.name = ["CrewPowerValue", "CrewLifeValue", "CrewRepairValue"][sector]
	value.custom_minimum_size = Vector2(54, 40)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 20)
	crew_value_labels.append(value)
	row.add_child(value)
	var plus := Button.new()
	plus.name = ["CrewPowerPlus", "CrewLifePlus", "CrewRepairPlus"][sector]
	plus.text = "+"
	plus.custom_minimum_size = Vector2(54, 40)
	plus.pressed.connect(_change_crew.bind(sector, 1))
	row.add_child(plus)

func _start_scenario(index: int) -> void:
	scenario_index = posmod(index, 3)
	state = Rules.new_state(scenario_index)
	selected_sector = 0
	_refresh()

func _restart_scenario() -> void:
	_start_scenario(scenario_index)

func _next_scenario() -> void:
	_start_scenario(scenario_index + 1)

func _change_crew(sector: int, delta: int) -> void:
	var result: Dictionary = Rules.set_crew(state, sector, delta)
	if bool(result.get("ok", false)):
		state = result["state"]
		selected_sector = sector
	_refresh()

func _run_cycle() -> void:
	var result: Dictionary = Rules.advance(state)
	if bool(result.get("ok", false)):
		state = result["state"]
	_refresh()

func _refresh() -> void:
	if state.is_empty():
		return
	var scenario: Dictionary = Rules.get_scenario(scenario_index)
	resource_labels["energy"].text = "%d / %d" % [int(state.get("energy", 0)), Rules.ENERGY_CAP]
	resource_labels["oxygen"].text = "%d / %d" % [int(state.get("oxygen", 0)), Rules.OXYGEN_CAP]
	resource_labels["hull"].text = "%d / %d" % [int(state.get("hull", 0)), Rules.HULL_CAP]
	var crew: Array = state.get("crew", [1, 2, 2])
	var assigned: int = 0
	for value in crew:
		assigned += int(value)
	for index in range(3):
		crew_value_labels[index].text = str(crew[index])
		var row_name: String = "CrewRow" + ["Power", "Life", "Repair"][index]
		var row: HBoxContainer = find_child(row_name, true, false) as HBoxContainer
		if row != null:
			var minus: Button = row.get_node(NodePath(["CrewPowerMinus", "CrewLifeMinus", "CrewRepairMinus"][index])) as Button
			var plus: Button = row.get_node(NodePath(["CrewPowerPlus", "CrewLifePlus", "CrewRepairPlus"][index])) as Button
			minus.disabled = int(crew[index]) <= 1 or str(state.get("status", "")) != "active"
			plus.disabled = assigned >= Rules.CREW_TOTAL or str(state.get("status", "")) != "active"
	var round_index: int = int(state.get("round", 0))
	var events: Array = scenario.get("events", [])
	if round_index < events.size():
		var event: Dictionary = events[round_index]
		event_label.text = "%s  |  CYCLE %d / %d\n%s\nPower demand %d (+%d solar)  ·  Oxygen demand %d  ·  Hull damage %d" % [
			str(scenario.get("title", "")), round_index + 1, Rules.ROUND_COUNT,
			str(event.get("name", "")), int(event.get("energy_demand", 0)), int(event.get("solar_bonus", 0)),
			int(event.get("oxygen_demand", 0)), int(event.get("hull_damage", 0))
		]
	else:
		event_label.text = "%s  |  ALL CYCLES COMPLETE" % str(scenario.get("title", ""))
	assignment_label.text = "CREW ASSIGNED: %d / %d     SELECTED STATION: %s" % [
		assigned, Rules.CREW_TOTAL, ["POWER", "LIFE SUPPORT", "REPAIRS"][selected_sector]
	]
	var status: String = str(state.get("status", "active"))
	run_button.disabled = status != "active" or assigned != Rules.CREW_TOTAL
	status_label.text = str(state.get("message", ""))
	if status == "won":
		status_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.68))
	elif status == "failed":
		status_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42))
	else:
		status_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.74))

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			selected_sector = 0
			_refresh()
		KEY_2:
			selected_sector = 1
			_refresh()
		KEY_3:
			selected_sector = 2
			_refresh()
		KEY_MINUS:
			_change_crew(selected_sector, -1)
		KEY_EQUAL:
			_change_crew(selected_sector, 1)
		KEY_ENTER, KEY_SPACE:
			_run_cycle()
		KEY_R:
			_restart_scenario()
		KEY_N:
			_next_scenario()
