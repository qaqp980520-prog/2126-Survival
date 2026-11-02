extends Control

const GRID_SIZE: int = 8
const DRONE_COLORS: Array[Color] = [
	Color("#49d9ff"),
	Color("#ffbd58"),
	Color("#a98bff")
]
const ACTIONS: Array[String] = ["up", "left", "wait", "right", "down"]
const ACTION_LABELS: Array[String] = ["↑  UP", "←  LEFT", "WAIT", "RIGHT  →", "DOWN  ↓"]

var _rules: Variant
var _state: Dictionary = {}
var _selected_drone: int = 0
var _info_label: Label
var _status_label: Label
var _select_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _control_buttons: Dictionary = {}

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Swarm Dispatcher main script is unavailable.")
		set_process_unhandled_key_input(false)
		return
	var script_directory: String = attached_script.resource_path.get_base_dir()
	var rules_path: String = script_directory.path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Swarm Dispatcher rules script could not be loaded: " + rules_path)
		set_process_unhandled_key_input(false)
		return
	_rules = rules_script.new()
	_state = _rules.create_state(0)
	_build_ui()
	_refresh_ui()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#08131f"), true)
	if _state.is_empty():
		return
	var level: Dictionary = _rules.get_level_definition(int(_state.get("level_index", 0)))
	if level.is_empty():
		return
	var cell: float = 48.0
	var origin := Vector2(48.0, 128.0)
	var walls: Array = level.get("walls", [])
	var starts: Array = level.get("starts", [])
	var goals: Array = level.get("goals", [])
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var point := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(float(x) * cell, float(y) * cell), Vector2(cell - 3.0, cell - 3.0))
			var fill: Color = Color("#122638")
			if x == 0 or y == 0 or x == GRID_SIZE - 1 or y == GRID_SIZE - 1:
				fill = Color("#25394a")
			if walls.has(point):
				fill = Color("#52606d")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color("#29485c"), false, 1.0)
			for drone_index in range(goals.size()):
				if goals[drone_index] == point:
					draw_circle(rect.get_center(), cell * 0.27, Color(DRONE_COLORS[drone_index].r, DRONE_COLORS[drone_index].g, DRONE_COLORS[drone_index].b, 0.24))
					draw_arc(rect.get_center(), cell * 0.30, 0.0, TAU, 32, DRONE_COLORS[drone_index], 2.0)
			for drone_index in range(starts.size()):
				if starts[drone_index] == point:
					draw_arc(rect.get_center(), cell * 0.40, 0.0, TAU, 24, Color(DRONE_COLORS[drone_index], 0.35), 1.0)
	var positions: Array = _state.get("positions", [])
	for drone_index in range(positions.size()):
		var point: Vector2i = positions[drone_index]
		var center := origin + Vector2((float(point.x) + 0.5) * cell, (float(point.y) + 0.5) * cell)
		draw_circle(center, cell * 0.25, DRONE_COLORS[drone_index])
		draw_arc(center, cell * 0.33, 0.0, TAU, 32, Color.WHITE if drone_index == _selected_drone else DRONE_COLORS[drone_index], 3.0 if drone_index == _selected_drone else 1.5)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6.0, 7.0), str(drone_index + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 17, Color("#07111b"))

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // SWARM DISPATCHER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#69e4ff"))
	column.add_child(title)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_color_override("font_color", Color("#d6e5f2"))
	column.add_child(_info_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	var board_space := Control.new()
	board_space.custom_minimum_size = Vector2(500.0, 480.0)
	body.add_child(board_space)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	body.add_child(panel)
	var select_title := Label.new()
	select_title.text = "SELECT DRONE  ·  TAB TO CYCLE"
	panel.add_child(select_title)
	var select_row := HBoxContainer.new()
	for index in range(3):
		var button := Button.new()
		button.name = "SelectDrone%d" % index
		button.text = "DRONE %s" % ["A", "B", "C"][index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_select_drone.bind(index))
		select_row.add_child(button)
		_select_buttons.append(button)
	panel.add_child(select_row)
	var action_title := Label.new()
	action_title.text = "PROGRAM THE SELECTED DRONE"
	panel.add_child(action_title)
	var action_grid := GridContainer.new()
	action_grid.columns = 3
	action_grid.add_theme_constant_override("h_separation", 6)
	action_grid.add_theme_constant_override("v_separation", 6)
	for index in range(ACTIONS.size()):
		var button := Button.new()
		button.name = "Action_" + ACTIONS[index]
		button.text = ACTION_LABELS[index]
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action_pressed.bind(ACTIONS[index]))
		action_grid.add_child(button)
		_action_buttons.append(button)
	panel.add_child(action_grid)
	var control_title := Label.new()
	control_title.text = "EXECUTION"
	panel.add_child(control_title)
	var control_grid := GridContainer.new()
	control_grid.columns = 3
	control_grid.add_theme_constant_override("h_separation", 6)
	control_grid.add_theme_constant_override("v_separation", 6)
	_add_control_button(control_grid, "undo", "UNDO  ·  BACKSPACE", _on_undo_pressed)
	_add_control_button(control_grid, "clear", "CLEAR  ·  DELETE", _on_clear_pressed)
	_add_control_button(control_grid, "step", "STEP TICK  ·  ENTER", _on_step_pressed)
	_add_control_button(control_grid, "run", "RUN ALL  ·  SHIFT+ENTER", _on_run_pressed)
	_add_control_button(control_grid, "restart", "RESTART  ·  R", _on_restart_pressed)
	_add_control_button(control_grid, "next", "NEXT  ·  N", _on_next_pressed)
	panel.add_child(control_grid)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 70.0)
	_status_label.add_theme_color_override("font_color", Color("#f2c879"))
	panel.add_child(_status_label)
	var hint := Label.new()
	hint.text = "WASD / 方向鍵加入路線；Space 等待。所有無人機同步前進一格，碰撞時整個 tick 取消。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#9db0c1"))
	panel.add_child(hint)

func _add_control_button(parent: GridContainer, key: String, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = "Control_" + key
	button.text = label
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	_control_buttons[key] = button

func _refresh_ui() -> void:
	if _state.is_empty():
		return
	var level_index: int = int(_state.get("level_index", 0))
	var level: Dictionary = _rules.get_level_definition(level_index)
	var programs: Array = _state.get("programs", [])
	var cursors: Array = _state.get("cursors", [])
	var remaining: Array[int] = []
	for index in range(3):
		remaining.append(maxi(0, (programs[index] as Array).size() - int(cursors[index])))
		_select_buttons[index].text = "DRONE %s  ·  %02d" % [["A", "B", "C"][index], remaining[index]]
		_select_buttons[index].disabled = index == _selected_drone or str(_state.get("status", "")) != "playing"
	_info_label.text = "MISSION %02d / %02d  ·  %s  ·  TICK %02d  ·  CAMPAIGN %03d" % [
		level_index + 1,
		_rules.get_level_count(),
		str(level.get("title", "UNKNOWN")),
		int(_state.get("tick", 0)),
		int(_state.get("campaign_score", 0))
	]
	var status: String = str(_state.get("status", "playing"))
	if status == "passed":
		_status_label.text = "DOCKING COMPLETE  ·  三架無人機全部抵達指定泊位。按 NEXT 前往下一個任務。"
	elif status == "campaign_complete":
		_status_label.text = "FLEET CAMPAIGN COMPLETE  ·  TOTAL SCORE %03d" % int(_state.get("total_score", 0))
	else:
		_status_label.text = "選取一架無人機，先編排路線，再逐 tick 執行。碰撞會取消整個同步 tick，不會只移動其中一架。"
	for button in _action_buttons:
		button.disabled = status != "playing"
	_control_buttons["undo"].disabled = status != "playing" or remaining[_selected_drone] <= 0
	_control_buttons["clear"].disabled = status != "playing" or remaining[_selected_drone] <= 0 or int(cursors[_selected_drone]) > 0
	_control_buttons["step"].disabled = status != "playing" or _rules.get_remaining_commands(_state) <= 0
	_control_buttons["run"].disabled = status != "playing" or _rules.get_remaining_commands(_state) <= 0
	_control_buttons["restart"].disabled = status != "playing"
	_control_buttons["next"].disabled = status != "passed"
	queue_redraw()

func _on_select_drone(index: int) -> void:
	select_drone(index)

func _on_action_pressed(action: String) -> void:
	append_action(action)

func _on_undo_pressed() -> void:
	undo_action()

func _on_clear_pressed() -> void:
	clear_program()

func _on_step_pressed() -> void:
	step_tick()

func _on_run_pressed() -> void:
	run_all()

func _on_restart_pressed() -> void:
	restart_level()

func _on_next_pressed() -> void:
	advance_level()

func select_drone(index: int) -> bool:
	if index < 0 or index >= 3 or str(_state.get("status", "")) != "playing":
		return false
	_selected_drone = index
	_refresh_ui()
	return true

func append_action(action: String) -> bool:
	var result: Dictionary = _rules.append_action(_state, _selected_drone, action)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_refresh_ui()
	return true

func undo_action() -> bool:
	var result: Dictionary = _rules.undo_action(_state, _selected_drone)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_refresh_ui()
	return true

func clear_program() -> bool:
	var result: Dictionary = _rules.clear_program(_state, _selected_drone)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_refresh_ui()
	return true

func step_tick() -> bool:
	var result: Dictionary = _rules.step_tick(_state)
	if not bool(result.get("ok", false)):
		_status_label.text = "TICK BLOCKED  ·  " + str(result.get("reason", "unknown"))
		return false
	_state = result["state"]
	_refresh_ui()
	return true

func run_all() -> bool:
	var result: Dictionary = _rules.run_all(_state)
	if not bool(result.get("ok", false)):
		_status_label.text = "EXECUTION STOPPED  ·  " + str(result.get("reason", "unknown"))
		return false
	_state = result["state"]
	if str(result.get("reason", "")) == "programs_exhausted":
		_status_label.text = "PROGRAMS EXHAUSTED  ·  路線尚未讓所有無人機抵達泊位，可繼續編排。"
	_refresh_ui()
	return true

func restart_level() -> bool:
	var result: Dictionary = _rules.restart_level(_state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_selected_drone = 0
	_refresh_ui()
	return true

func advance_level() -> bool:
	var result: Dictionary = _rules.advance_level(_state)
	if not bool(result.get("ok", false)):
		return false
	_state = result["state"]
	_selected_drone = 0
	_refresh_ui()
	return true

func restart_campaign() -> bool:
	var result: Dictionary = _rules.restart_campaign()
	_state = result["state"]
	_selected_drone = 0
	_refresh_ui()
	return true

func get_current_state() -> Dictionary:
	return _state.duplicate(true)

func get_title_text() -> String:
	return _rules.get_title_text()

func get_level_count() -> int:
	return _rules.get_level_count()

func get_drone_button_count() -> int:
	return _select_buttons.size()

func get_action_button_count() -> int:
	return _action_buttons.size()

func get_control_button_count() -> int:
	return _control_buttons.size()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key: int = key_event.keycode
	match key:
		KEY_TAB:
			_selected_drone = (_selected_drone + 1) % 3
			_refresh_ui()
		KEY_ENTER, KEY_KP_ENTER:
			run_all() if key_event.shift_pressed else step_tick()
		KEY_BACKSPACE:
			undo_action()
		KEY_DELETE:
			clear_program()
		KEY_R:
			restart_level()
		KEY_N:
			advance_level()
		KEY_SPACE:
			append_action("wait")
		KEY_UP, KEY_W:
			append_action("up")
		KEY_DOWN, KEY_S:
			append_action("down")
		KEY_LEFT, KEY_A:
			append_action("left")
		KEY_RIGHT, KEY_D:
			append_action("right")
