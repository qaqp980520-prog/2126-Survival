extends Control

const Rules = preload("res://rules.gd")
var state: Dictionary = {}
var action_buttons: Dictionary = {}
var status_label: Label
var pressure_label: Label
var doors_label: Label
var message_label: Label
var restart_button: Button
var _message: String = "Transfer all three cargo pods safely."

func _ready() -> void:
	_build_ui()
	_restart()
	set_process_unhandled_key_input(true)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.065)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // AIRLOCK OPERATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.48, 0.9, 1.0))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "CARGO TRANSFER // PRESSURE SAFETY CONSOLE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	column.add_child(subtitle)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 15)
	column.add_child(status_label)
	pressure_label = Label.new()
	pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pressure_label.add_theme_font_size_override("font_size", 20)
	pressure_label.add_theme_color_override("font_color", Color(0.48, 0.92, 0.82))
	column.add_child(pressure_label)
	doors_label = Label.new()
	doors_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doors_label.add_theme_font_size_override("font_size", 16)
	column.add_child(doors_label)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	column.add_child(message_label)
	_add_action_row(column, [{"id":"pressurize","label":"PRESSURIZE +50"},{"id":"vent","label":"VENT -50"},{"id":"recycle_oxygen","label":"RECYCLE OXYGEN"}])
	_add_action_row(column, [{"id":"open_outer","label":"OPEN OUTER"},{"id":"load_pod","label":"LOAD POD"},{"id":"close_outer","label":"CLOSE OUTER"}])
	_add_action_row(column, [{"id":"open_inner","label":"OPEN INNER"},{"id":"unload_pod","label":"UNLOAD POD"},{"id":"close_inner","label":"CLOSE INNER"}])
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	restart_button = Button.new()
	restart_button.text = "RESTART SHIFT (R)"
	restart_button.custom_minimum_size = Vector2(190, 48)
	restart_button.pressed.connect(_restart)
	footer.add_child(restart_button)
	var help := Label.new()
	help.text = "Q pressurize · E vent · T recycle · 1-3 outer/load · 4-6 inner/unload · R restart"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

func _add_action_row(parent: VBoxContainer, actions: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for data in actions:
		var action_id: String = str(data.get("id", ""))
		var button := Button.new()
		button.text = str(data.get("label", action_id))
		button.custom_minimum_size = Vector2(150, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_act.bind(action_id))
		row.add_child(button)
		action_buttons[action_id] = button

func _restart() -> void:
	state = Rules.new_game()
	_message = "Equalize pressure within 10 kPa before opening a door. Both doors must stay interlocked."
	_refresh_ui()

func _act(action_id: String) -> void:
	var result: Dictionary = Rules.apply_action(state, action_id)
	if bool(result.get("ok", false)):
		state = result["state"]
		_message = _action_message(action_id)
		if str(state.get("result", "")) == "won":
			_message = "SHIFT COMPLETE // all cargo delivered and both doors safely closed."
		elif str(state.get("result", "")) == "lost":
			_message = "SHIFT FAILED // oxygen or action budget exhausted. Restart and try again."
	else:
		_message = _reason_message(str(result.get("reason", "unknown")))
	_refresh_ui()

func _refresh_ui() -> void:
	if state.is_empty():
		return
	status_label.text = "OXYGEN %d%%     ACTIONS %d / %d     RESULT %s" % [int(state.get("oxygen",0)),int(state.get("actions",0)),Rules.MAX_ACTIONS,str(state.get("result","playing")).to_upper()]
	pressure_label.text = "EXTERIOR %d kPa     AIRLOCK %d kPa     HABITAT %d kPa" % [int(state.get("exterior_pressure",0)),int(state.get("airlock_pressure",0)),int(state.get("habitat_pressure",0))]
	doors_label.text = "OUTER: %s     INNER: %s\nPODS OUTSIDE %d     AIRLOCK %d     DELIVERED %d" % ["OPEN" if bool(state.get("outer_open",false)) else "CLOSED","OPEN" if bool(state.get("inner_open",false)) else "CLOSED",int(state.get("pods_exterior",0)),int(state.get("pods_airlock",0)),int(state.get("pods_delivered",0))]
	message_label.text = _message
	var finished: bool = str(state.get("result","")) != "playing"
	for value in action_buttons.values():
		(value as Button).disabled = finished

func _action_message(action_id: String) -> String:
	match action_id:
		"pressurize": return "Airlock pressure increased by 50 kPa."
		"vent": return "Airlock pressure reduced by 50 kPa."
		"recycle_oxygen": return "Oxygen recycler restored 20 points."
		"open_outer": return "Outer door opened. Load one pod, then close it."
		"close_outer": return "Outer door sealed."
		"load_pod": return "One cargo pod moved into the airlock."
		"open_inner": return "Inner door opened. Unload the pod, then close it."
		"close_inner": return "Inner door sealed."
		"unload_pod": return "One cargo pod delivered to the habitat."
	return "Action completed."

func _reason_message(reason: String) -> String:
	match reason:
		"pressure_mismatch": return "SAFETY LOCK: equalize pressure to within 10 kPa before opening."
		"interlock": return "SAFETY LOCK: the opposite door must be closed."
		"door_open": return "Close both doors before operating pressure or oxygen valves."
		"low_oxygen": return "Oxygen is too low for a safe transfer."
		"outer_closed": return "Open the outer door before loading a pod."
		"inner_closed": return "Open the inner door before unloading a pod."
		"airlock_empty": return "There is no cargo pod inside the airlock."
		"no_pods": return "No cargo pods remain outside."
		"pressure_limit": return "Pressure is already at its limit."
		"oxygen_full": return "Oxygen reserve is already full."
		"finished": return "The shift is over. Restart to play again."
	return "Action rejected: %s." % reason

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q: _act("pressurize")
		KEY_E: _act("vent")
		KEY_T: _act("recycle_oxygen")
		KEY_1: _act("open_outer")
		KEY_2: _act("load_pod")
		KEY_3: _act("close_outer")
		KEY_4: _act("open_inner")
		KEY_5: _act("unload_pod")
		KEY_6: _act("close_inner")
		KEY_R: _restart()
