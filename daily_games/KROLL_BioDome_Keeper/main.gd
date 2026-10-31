extends Control
const Rules = preload("res://daily_games/KROLL_BioDome_Keeper/rules.gd")
var _state: Dictionary = {}
var _selected_cell: int = 0
var _cell_buttons: Array[Button] = []
var _action_buttons: Dictionary = {}
var _mission_label: Label
var _stats_label: Label
var _selected_label: Label
var _message_label: Label

func _ready() -> void:
	_state=Rules.new_game(0)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color=Color("#071b1d")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",18)
	margin.add_theme_constant_override("margin_right",18)
	margin.add_theme_constant_override("margin_top",16)
	margin.add_theme_constant_override("margin_bottom",16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	var title := Label.new()
	title.text="KROLL BIODOME KEEPER"
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("#83f0c2"))
	column.add_child(title)
	_mission_label=Label.new()
	_mission_label.add_theme_font_size_override("font_size",22)
	_mission_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_mission_label.custom_minimum_size=Vector2(0.0,42.0)
	_mission_label.add_theme_color_override("font_color",Color("#f0f6df"))
	column.add_child(_mission_label)
	_stats_label=Label.new()
	_stats_label.add_theme_font_size_override("font_size",16)
	_stats_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size=Vector2(0.0,32.0)
	_stats_label.add_theme_color_override("font_color",Color("#a9d5c3"))
	column.add_child(_stats_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size=Vector2(420.0,0.0)
	left.add_theme_constant_override("separation",8)
	body.add_child(left)
	var grid_title := Label.new()
	grid_title.text="DOME GROWING GRID  //  SELECT A PLOT"
	grid_title.add_theme_color_override("font_color",Color("#9ee4c9"))
	left.add_child(grid_title)
	var grid := GridContainer.new()
	grid.name="GrowingGrid"
	grid.columns=Rules.GRID_WIDTH
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",5)
	grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	left.add_child(grid)
	for index in range(Rules.GRID_SIZE):
		var button := Button.new()
		button.name="Cell_%02d" % index
		button.custom_minimum_size=Vector2(65.0,58.0)
		button.focus_mode=Control.FOCUS_NONE
		button.pressed.connect(_select_cell.bind(index))
		grid.add_child(button)
		_cell_buttons.append(button)
	var right := VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",9)
	body.add_child(right)
	_selected_label=Label.new()
	_selected_label.custom_minimum_size=Vector2(0.0,72.0)
	_selected_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_selected_label.add_theme_color_override("font_color",Color("#f2e7bb"))
	right.add_child(_selected_label)
	var action_title := Label.new()
	action_title.text="RESTORATION ACTIONS"
	action_title.add_theme_color_override("font_color",Color("#83f0c2"))
	right.add_child(action_title)
	var actions := GridContainer.new()
	actions.columns=2
	actions.add_theme_constant_override("h_separation",8)
	actions.add_theme_constant_override("v_separation",8)
	right.add_child(actions)
	_add_action_button(actions,"PlantFernButton","PLANT FERN","plant","fern")
	_add_action_button(actions,"PlantMossButton","PLANT MOSS","plant","moss")
	_add_action_button(actions,"PlantBloomButton","PLANT BLOOM","plant","bloom")
	_add_action_button(actions,"WaterButton","WATER +2","water")
	_add_action_button(actions,"EnrichButton","COMPOST +2","enrich")
	_add_action_button(actions,"ReleasePollinatorsButton","RELEASE POLLINATORS","release_pollinators")
	_add_action_button(actions,"PrunePestsButton","PRUNE PESTS","prune")
	var advance := Button.new()
	advance.name="AdvanceDayButton"
	advance.text="END DAY  →"
	advance.custom_minimum_size=Vector2(180.0,48.0)
	advance.pressed.connect(_advance_day)
	actions.add_child(advance)
	_action_buttons["AdvanceDayButton"]=advance
	var reset := Button.new()
	reset.name="ResetButton"
	reset.text="RESET DOME"
	reset.custom_minimum_size=Vector2(180.0,44.0)
	reset.pressed.connect(_reset)
	actions.add_child(reset)
	_action_buttons["ResetButton"]=reset
	var next := Button.new()
	next.name="NextDomeButton"
	next.text="NEXT DOME  →"
	next.custom_minimum_size=Vector2(180.0,44.0)
	next.pressed.connect(_next_mission)
	actions.add_child(next)
	_action_buttons["NextDomeButton"]=next
	var hint := Label.new()
	hint.text="Keyboard: 1/2/3 plant · Q water · E compost · P pollinators · X prune · Enter end day · R reset · N next dome. Touch buttons are available."
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color",Color("#8eb8a9"))
	right.add_child(hint)
	_message_label=Label.new()
	_message_label.name="MessageLabel"
	_message_label.custom_minimum_size=Vector2(0.0,42.0)
	_message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color",Color("#f1d88d"))
	column.add_child(_message_label)

func _add_action_button(parent: GridContainer, button_name: String, label_text: String, action: String, species: String = "") -> void:
	var button := Button.new()
	button.name=button_name
	button.text=label_text
	button.custom_minimum_size=Vector2(180.0,48.0)
	button.focus_mode=Control.FOCUS_NONE
	button.pressed.connect(_perform.bind(action,species))
	parent.add_child(button)
	_action_buttons[button_name]=button

func _select_cell(index: int) -> void:
	_selected_cell=clampi(index,0,Rules.GRID_SIZE-1)
	_message_label.text="Plot %02d selected. Choose a restoration action." % (_selected_cell+1)
	_refresh()

func _perform(action: String, species: String = "") -> void:
	var previous_actions: int = int(_state.get("actions_used",0))
	_state=Rules.perform_action(_state,action,_selected_cell,species)
	if int(_state.get("actions_used",0)) == previous_actions:
		_message_label.text="Action unavailable: check the selected plot, resources or daily action budget."
	else:
		_message_label.text="Restoration action recorded: %s." % action.replace("_"," ").capitalize()
	_refresh()

func _advance_day() -> void:
	_state=Rules.advance_day(_state)
	match str(_state.get("status","")):
		"complete": _message_label.text="DOME RESTORED  //  Biodiversity targets reached."
		"failed": _message_label.text="DOME UNSTABLE  //  Targets missed. Reset and try another plan."
		_: _message_label.text="Day %d begins. Review moisture, nutrients and pollinator coverage." % int(_state.get("day",1))
	_refresh()

func _reset() -> void:
	_state=Rules.reset(_state)
	_selected_cell=0
	_message_label.text="Dome reset. The initial ecosystem has been restored."
	_refresh()

func _next_mission() -> void:
	var previous_index: int = int(_state.get("mission_index",0))
	_state=Rules.next_mission(_state)
	if int(_state.get("mission_index",0)) == previous_index:
		_message_label.text="Complete the current biodiversity targets before moving on."
	else:
		_message_label.text="New restoration dome loaded."
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: _perform("plant","fern")
		KEY_2: _perform("plant","moss")
		KEY_3: _perform("plant","bloom")
		KEY_Q: _perform("water")
		KEY_E: _perform("enrich")
		KEY_P: _perform("release_pollinators")
		KEY_X: _perform("prune")
		KEY_ENTER, KEY_KP_ENTER: _advance_day()
		KEY_R: _reset()
		KEY_N: _next_mission()
		_: return

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_selected_cell_index() -> int:
	return _selected_cell

func _refresh() -> void:
	var mission: Dictionary = Rules.get_mission(int(_state.get("mission_index",0)))
	var stats: Dictionary = Rules.get_stats(_state)
	var status: String = str(_state.get("status","playing"))
	var cells: Array = _state.get("cells",[])
	_mission_label.text="DOME %02d  //  %s — %s" % [int(_state.get("mission_index",0))+1,str(mission.get("name","RESTORATION DOME")),str(mission.get("brief",""))]
	_stats_label.text="DAY %d/%d   ACTIONS %d/%d   SEEDS %d   PLANTS %d/%d   SPECIES %d/%d   POLLINATORS %d/%d   PESTS %d/%d" % [
		int(_state.get("day",1)),Rules.DAYS,int(_state.get("actions_left",0)),Rules.ACTIONS_PER_DAY,int(_state.get("seed_bank",0)),
		int(stats.get("plants",0)),int(stats.get("target_plants",0)),int(stats.get("species",0)),int(stats.get("target_species",0)),
		int(stats.get("pollinators",0)),int(stats.get("target_pollinators",0)),int(stats.get("pests",0)),int(stats.get("max_pests",0))
	]
	for index in range(_cell_buttons.size()):
		var cell: Dictionary = cells[index]
		var species: String = str(cell.get("species",""))
		var short_name: String = "EMPTY"
		var color: Color = Color("#244247")
		match species:
			"fern":
				short_name="FERN"
				color=Color("#286b4b")
			"moss":
				short_name="MOSS"
				color=Color("#477c58")
			"bloom":
				short_name="BLOOM"
				color=Color("#8a5c91")
		var selected_mark: String = "▶ " if index == _selected_cell else ""
		var button: Button = _cell_buttons[index]
		button.text="%s%s\nW%d  N%d" % [selected_mark,short_name,int(cell.get("moisture",0)),int(cell.get("nutrients",0))]
		var style := StyleBoxFlat.new()
		style.bg_color=color
		style.border_width_left=3 if index == _selected_cell else 1
		style.border_width_right=3 if index == _selected_cell else 1
		style.border_width_top=3 if index == _selected_cell else 1
		style.border_width_bottom=3 if index == _selected_cell else 1
		style.border_color=Color("#f1d88d") if index == _selected_cell else Color("#537a78")
		button.add_theme_stylebox_override("normal",style)
		button.disabled=status == "campaign_complete"
	var selected: Dictionary = cells[_selected_cell]
	var selected_species: String = str(selected.get("species",""))
	if selected_species.is_empty():
		selected_species="EMPTY"
	_selected_label.text="PLOT %02d  //  %s\nMoisture %d/5 · Nutrients %d/5 · Health %d/3 · Pests %d" % [
		_selected_cell+1,selected_species.to_upper(),int(selected.get("moisture",0)),
		int(selected.get("nutrients",0)),int(selected.get("health",0)),int(selected.get("pests",0))
	]
	var can_act: bool = status == "playing" and int(_state.get("actions_left",0)) > 0
	var selected_empty: bool = str(selected.get("species","")).is_empty()
	_action_buttons["PlantFernButton"].disabled=not can_act or not selected_empty or int(_state.get("seed_bank",0)) <= 0
	_action_buttons["PlantMossButton"].disabled=not can_act or not selected_empty or int(_state.get("seed_bank",0)) <= 0
	_action_buttons["PlantBloomButton"].disabled=not can_act or not selected_empty or int(_state.get("seed_bank",0)) <= 0
	_action_buttons["WaterButton"].disabled=not can_act or int(selected.get("moisture",0)) >= Rules.MAX_RESOURCE
	_action_buttons["EnrichButton"].disabled=not can_act or int(selected.get("nutrients",0)) >= Rules.MAX_RESOURCE
	_action_buttons["ReleasePollinatorsButton"].disabled=not can_act or int(_state.get("pollinators",0)) >= Rules.MAX_POLLINATORS
	_action_buttons["PrunePestsButton"].disabled=not can_act or int(selected.get("pests",0)) <= 0
	_action_buttons["AdvanceDayButton"].disabled=status != "playing"
	_action_buttons["ResetButton"].disabled=false
	_action_buttons["NextDomeButton"].disabled=status != "complete" or int(_state.get("mission_index",0)) >= Rules.MISSIONS.size()-1
	if status == "campaign_complete":
		_message_label.text="ALL THREE DOMES RESTORED  //  KROLL ECOLOGY NETWORK ONLINE."
	elif status == "complete" and int(_state.get("mission_index",0)) >= Rules.MISSIONS.size()-1:
		_message_label.text="ALL THREE DOMES RESTORED  //  KROLL ECOLOGY NETWORK ONLINE."
	elif status == "complete":
		_message_label.text="DOME RESTORED  //  NEXT DOME UNLOCKED."
	elif status == "failed":
		_message_label.text="DOME UNSTABLE  //  RESET TO RETRY."
	elif _message_label.text.is_empty():
		_message_label.text="Plant three species, release pollinators and restore the dome before day six."
