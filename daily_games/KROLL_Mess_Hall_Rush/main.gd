extends Control

var rules: Variant
var state: Dictionary = {}
var selected_order_id: String = ""
var order_list: VBoxContainer
var shift_label: Label
var score_label: Label
var expected_label: Label
var status_label: Label
var next_button: Button
var action_buttons: Dictionary = {}
var action_names: Array[String] = []

func _ready() -> void:
	var rules_path := "res://rules.gd"
	var root_rules_path := "res://daily_games/KROLL_Mess_Hall_Rush/rules.gd"
	if ResourceLoader.exists(root_rules_path):
		rules_path = root_rules_path
	var rules_script := load(rules_path) as Script
	if rules_script == null:
		push_error("Mess Hall Rush could not load its rules script: " + rules_path)
		return
	rules = rules_script.new()
	state = rules.create_state(0)
	action_names = rules.get_action_names()
	_build_ui()
	_select_first_active_order()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.065)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "KROLL // MESS HALL RUSH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "STATION CAFETERIA · THREE SHIFTS · TWELVE ORDERS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	column.add_child(subtitle)

	var metrics := HBoxContainer.new()
	column.add_child(metrics)
	shift_label = Label.new()
	shift_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_child(shift_label)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metrics.add_child(score_label)

	var instructions := Label.new()
	instructions.text = "選取訂單，再按下正確工序。每次操作都會讓所有未完成訂單倒數；錯誤工序也會消耗時間。"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)

	var order_heading := Label.new()
	order_heading.text = "ACTIVE ORDERS"
	order_heading.add_theme_font_size_override("font_size", 18)
	column.add_child(order_heading)

	order_list = VBoxContainer.new()
	order_list.add_theme_constant_override("separation", 6)
	column.add_child(order_list)

	expected_label = Label.new()
	expected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expected_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.72))
	column.add_child(expected_label)

	var action_heading := Label.new()
	action_heading.text = "WORKSTATIONS"
	action_heading.add_theme_font_size_override("font_size", 18)
	column.add_child(action_heading)

	var action_grid := GridContainer.new()
	action_grid.columns = 3 if get_viewport_rect().size.x < 700.0 else 4
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(action_grid)

	for action in action_names:
		var button := Button.new()
		button.text = action.to_upper()
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action_pressed.bind(action))
		action_grid.add_child(button)
		action_buttons[action] = button

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0.0, 42.0)
	status_label.text = "Choose an order and follow its next workstation."
	status_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	column.add_child(status_label)

	var controls := HBoxContainer.new()
	column.add_child(controls)
	next_button = Button.new()
	next_button.text = "NEXT SHIFT"
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(_on_next_shift)
	controls.add_child(next_button)
	var restart_button := Button.new()
	restart_button.text = "RESTART CAMPAIGN"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_on_restart)
	controls.add_child(restart_button)

func _refresh_ui() -> void:
	if not is_instance_valid(order_list):
		return
	for child in order_list.get_children():
		child.free()
	var orders: Array = state.get("orders", [])
	for order_value in orders:
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value
		var order_id: String = str(order.get("id", ""))
		var steps: Array = order.get("steps", [])
		var progress: int = int(order.get("progress", 0))
		var next_step: String = str(steps[progress]) if progress >= 0 and progress < steps.size() else "—"
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s  |  %s  |  %s  |  %d ticks" % [
			order_id.to_upper(),
			str(order.get("dish", "Unknown")),
			str(order.get("status", "unknown")).to_upper() if str(order.get("status", "")) != "active" else next_step.to_upper(),
			int(order.get("remaining", 0))
		]
		button.disabled = str(order.get("status", "")) != "active"
		button.pressed.connect(_select_order.bind(order_id))
		if order_id == selected_order_id:
			button.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
		order_list.add_child(button)

	shift_label.text = "SHIFT %d / %d  ·  %s  ·  %s" % [
		int(state.get("shift_index", 0)) + 1,
		rules.get_shift_count(),
		str(state.get("shift_name", "")),
		str(state.get("status", "")).to_upper()
	]
	score_label.text = "SCORE %d  ·  SERVED %d  ·  FAILED %d" % [
		int(state.get("score", 0)),
		int(state.get("served_total", 0)),
		int(state.get("failed_total", 0))
	]
	var selected: Dictionary = rules.get_order_snapshot(state, selected_order_id)
	var expected: String = rules.get_next_action(state, selected_order_id)
	if selected.is_empty():
		expected_label.text = "No active order selected."
	else:
		expected_label.text = "Selected: %s  ·  Next station: %s  ·  Mistakes: %d" % [
			str(selected.get("dish", "")),
			expected.to_upper() if not expected.is_empty() else "COMPLETE",
			int(selected.get("mistakes", 0))
		]
	for action in action_names:
		var action_button: Button = action_buttons[action]
		action_button.disabled = str(state.get("status", "")) != "playing" or selected.is_empty()
	next_button.disabled = str(state.get("status", "")) != "shift_passed"
	next_button.text = "NEXT SHIFT" if int(state.get("shift_index", 0)) < rules.get_shift_count() - 1 else "CAMPAIGN COMPLETE"
	if str(state.get("status", "")) == "campaign_passed":
		status_label.text = "CAMPAIGN COMPLETE — all shifts stabilized. Press Restart Campaign to play again."
	elif str(state.get("status", "")) == "campaign_failed":
		status_label.text = "CAMPAIGN FAILED — too many orders expired. Restart and prioritize the tight deadlines."
	elif str(state.get("status", "")) == "shift_passed":
		status_label.text = "SHIFT PASSED — at least three orders were served. Proceed when ready."
	elif str(state.get("status", "")) == "shift_failed":
		status_label.text = "SHIFT FAILED — fewer than three orders were served. Restart the campaign."
	if str(state.get("status", "")) != "playing":
		for action in action_names:
			(action_buttons[action] as Button).disabled = true

func _select_order(order_id: String) -> void:
	var snapshot: Dictionary = rules.get_order_snapshot(state, order_id)
	if snapshot.is_empty() or str(snapshot.get("status", "")) != "active":
		return
	selected_order_id = order_id
	_refresh_ui()

func _select_first_active_order() -> void:
	selected_order_id = ""
	for order_value in state.get("orders", []):
		if order_value is Dictionary and str(order_value.get("status", "")) == "active":
			selected_order_id = str(order_value.get("id", ""))
			return

func _on_action_pressed(action: String) -> void:
	perform_action(selected_order_id, action)

func perform_action(order_id: String, action: String) -> Dictionary:
	var result: Dictionary = rules.perform_action(state, order_id, action)
	if not bool(result.get("ok", false)):
		status_label.text = "Rejected: %s" % str(result.get("reason", "unknown"))
		return result
	state = result["state"]
	if bool(result.get("correct", false)):
		status_label.text = "Correct station: %s." % action.to_upper()
	else:
		status_label.text = "Wrong station. Expected %s; every active ticket lost one tick." % str(result.get("expected", "")).to_upper()
	if str(state.get("status", "")) == "playing":
		var selected: Dictionary = rules.get_order_snapshot(state, selected_order_id)
		if selected.is_empty() or str(selected.get("status", "")) != "active":
			_select_first_active_order()
	_refresh_ui()
	return result

func _on_next_shift() -> void:
	var result: Dictionary = rules.advance_shift(state)
	if not bool(result.get("ok", false)):
		status_label.text = "Cannot advance: %s" % str(result.get("reason", "unknown"))
		return
	state = result["state"]
	_select_first_active_order()
	status_label.text = "New shift started."
	_refresh_ui()

func _on_restart() -> void:
	state = rules.restart_campaign()
	_select_first_active_order()
	status_label.text = "Campaign restarted."
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_select_order_by_index(0)
		KEY_2:
			_select_order_by_index(1)
		KEY_3:
			_select_order_by_index(2)
		KEY_4:
			_select_order_by_index(3)
		KEY_Q:
			perform_action(selected_order_id, "chop")
		KEY_W:
			perform_action(selected_order_id, "grill")
		KEY_E:
			perform_action(selected_order_id, "simmer")
		KEY_R:
			perform_action(selected_order_id, "brew")
		KEY_T:
			perform_action(selected_order_id, "chill")
		KEY_Y:
			perform_action(selected_order_id, "butter")
		KEY_U:
			perform_action(selected_order_id, "glaze")
		KEY_I:
			perform_action(selected_order_id, "wash")
		KEY_O:
			perform_action(selected_order_id, "plate")
		KEY_P:
			perform_action(selected_order_id, "pour")
		KEY_SPACE:
			perform_action(selected_order_id, "wait")
		KEY_ENTER:
			var expected: String = rules.get_next_action(state, selected_order_id)
			if not expected.is_empty():
				perform_action(selected_order_id, expected)

func _select_order_by_index(order_index: int) -> void:
	var orders: Array = state.get("orders", [])
	if order_index < 0 or order_index >= orders.size():
		return
	if orders[order_index] is Dictionary:
		_select_order(str(orders[order_index].get("id", "")))

func get_title_text() -> String:
	return "KROLL // MESS HALL RUSH"

func get_shift_count() -> int:
	return rules.get_shift_count()

func get_order_button_count() -> int:
	return order_list.get_child_count() if is_instance_valid(order_list) else 0

func get_action_button_count() -> int:
	return action_buttons.size()

func get_control_button_count() -> int:
	return 2

func get_current_state() -> Dictionary:
	return state.duplicate(true)

func get_selected_order_id() -> String:
	return selected_order_id
