extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var seed_cursor: int = 0
var zone_picker: OptionButton
var status_label: Label
var resources_label: Label
var ecosystem_label: Label
var feedback_label: Label
var action_buttons: Dictionary = {}

func _ready() -> void:
	state = Rules.new_game(Rules.SEEDS[seed_cursor])
	_build_ui()
	_populate_zones()
	_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_select_zone(0)
		KEY_2:
			_select_zone(1)
		KEY_3:
			_select_zone(2)
		KEY_P:
			_perform_action(Rules.ACTION_PLANT)
		KEY_G:
			_perform_action(Rules.ACTION_GRAZER)
		KEY_W:
			_perform_action(Rules.ACTION_WATER)
		KEY_C:
			_perform_action(Rules.ACTION_CULL)
		KEY_ENTER, KEY_KP_ENTER:
			_end_turn()
		KEY_R:
			restart_game()
		KEY_N:
			next_layout()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // BIOME BALANCE"
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Six turns to stabilize three habitats. Each turn allows two interventions; protect flora and grazers while keeping predators under control."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(subtitle)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(status_label)

	resources_label = Label.new()
	resources_label.name = "ResourcesLabel"
	resources_label.add_theme_font_size_override("font_size", 15)
	layout.add_child(resources_label)

	var zone_row := HBoxContainer.new()
	zone_row.add_theme_constant_override("separation", 10)
	layout.add_child(zone_row)
	var zone_label := Label.new()
	zone_label.text = "ACTIVE HABITAT"
	zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_row.add_child(zone_label)
	zone_picker = OptionButton.new()
	zone_picker.name = "ZonePicker"
	zone_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_picker.custom_minimum_size = Vector2(0, 48)
	zone_row.add_child(zone_picker)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	_add_button(actions, "PLANT (P)", "plant", func(): _perform_action(Rules.ACTION_PLANT))
	_add_button(actions, "ADD GRAZER (G)", "grazer", func(): _perform_action(Rules.ACTION_GRAZER))
	_add_button(actions, "WATER (W)", "water", func(): _perform_action(Rules.ACTION_WATER))
	_add_button(actions, "REMOVE PREDATOR (C)", "cull", func(): _perform_action(Rules.ACTION_CULL))

	ecosystem_label = Label.new()
	ecosystem_label.name = "EcosystemLabel"
	ecosystem_label.custom_minimum_size = Vector2(0, 180)
	ecosystem_label.add_theme_font_size_override("font_size", 18)
	ecosystem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(ecosystem_label)

	feedback_label = Label.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.custom_minimum_size = Vector2(0, 50)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)
	_add_button(controls, "END TURN (ENTER)", "end", _end_turn)
	_add_button(controls, "RESTART (R)", "restart", restart_game)
	_add_button(controls, "NEXT LAYOUT (N)", "next", next_layout)

	var footer := Label.new()
	footer.text = "Balance target: every habitat needs flora >= 2, grazers >= 2 and predators <= 2, with total biodiversity >= 18. Seeds 17 / 29 / 41 reorder the same deterministic habitat conditions."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(footer)

func _add_button(parent: Container, text_value: String, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = {
		"plant": "PlantButton",
		"grazer": "GrazerButton",
		"water": "WaterButton",
		"cull": "CullButton",
		"end": "EndTurnButton",
		"restart": "RestartButton",
		"next": "NextLayoutButton"
	}.get(key, key)
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons[key] = button

func _select_zone(zone_index: int) -> void:
	if zone_picker == null or zone_index < 0 or zone_index >= zone_picker.item_count:
		return
	zone_picker.select(zone_index)

func _perform_action(action_name: String) -> Dictionary:
	var zone_index: int = zone_picker.get_selected_id() if zone_picker != null else -1
	return _perform_action_for(zone_index, action_name)

func _perform_action_for(zone_index: int, action_name: String) -> Dictionary:
	var result: Dictionary = Rules.perform_action(state, zone_index, action_name)
	_act(result)
	return result

func _end_turn() -> Dictionary:
	var result: Dictionary = Rules.end_turn(state)
	_act(result)
	return result

func _act(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		state = result.get("state", state)
	else:
		feedback_label.text = "ACTION BLOCKED: " + str(result.get("reason", "unknown"))
	_render()

func restart_game() -> void:
	state = Rules.new_game(int(state.get("seed", Rules.SEEDS[seed_cursor])))
	_populate_zones()
	_render()

func next_layout() -> void:
	seed_cursor = (seed_cursor + 1) % Rules.SEEDS.size()
	state = Rules.new_game(Rules.SEEDS[seed_cursor])
	_populate_zones()
	_render()

func _populate_zones() -> void:
	if zone_picker == null:
		return
	zone_picker.clear()
	var zones: Array = state.get("zones", [])
	for index in range(zones.size()):
		zone_picker.add_item(str(zones[index].get("name", "HABITAT")), index)
	if zone_picker.item_count > 0:
		zone_picker.select(0)

func _render() -> void:
	if state.is_empty() or status_label == null:
		return
	var status: String = str(state.get("status", "unknown"))
	status_label.text = "STATUS: %s    TURN: %d/%d    ACTIONS LEFT: %d" % [
		status.to_upper(),
		int(state.get("turn", 1)),
		Rules.MAX_TURNS,
		int(state.get("actions_left", 0))
	]
	resources_label.text = "SEEDS: %d   GRAZER RELEASES: %d   WATER CELLS: %d   INTERVENTIONS USED: %d" % [
		int(state.get("seed_tokens", 0)),
		int(state.get("grazer_tokens", 0)),
		int(state.get("water_cells", 0)),
		int(state.get("actions_used", 0))
	]
	var zone_lines: Array[String] = []
	for zone_value in state.get("zones", []):
		var zone: Dictionary = zone_value
		zone_lines.append("%s    FLORA %d    GRAZERS %d    PREDATORS %d    WATER %d" % [
			str(zone.get("name", "HABITAT")),
			int(zone.get("flora", 0)),
			int(zone.get("herbivores", 0)),
			int(zone.get("predators", 0)),
			int(zone.get("water", 0))
		])
	ecosystem_label.text = "\n".join(zone_lines)
	feedback_label.text = str(state.get("message", ""))
	for key in ["plant", "grazer", "water", "cull"]:
		action_buttons[key].disabled = status != "playing" or int(state.get("actions_left", 0)) <= 0
	action_buttons["end"].disabled = status != "playing"
	action_buttons["restart"].disabled = false
	action_buttons["next"].disabled = false
