extends Control
const RulesScript = preload("res://rules.gd")
const GRID_SIZE: int = 7
const MOVE_ACTIONS: Array[String] = ["up","left","wait","right","down"]
const MOVE_LABELS: Array[String] = ["↑  UP","←  LEFT","WAIT","RIGHT  →","DOWN  ↓"]
var _rules: Variant
var _state: Dictionary = {}
var _move_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _info_label: Label
var _status_label: Label
var _record_button: Button
var _next_button: Button
func _ready() -> void:
	_rules = RulesScript.new()
	_state = _rules.create_state(0)
	_build_ui()
	_refresh_ui()
	queue_redraw()
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.018,0.028,0.052),true)
	if _state.is_empty():
		return
	var level: Dictionary = _rules.get_level_definition(int(_state.get("level_index",0)))
	var cell: float = maxf(24.0,minf((size.x - 80.0) / 7.0,(size.y - 300.0) / 7.0))
	var origin := Vector2((size.x - cell * 7.0) * 0.5,112.0)
	var walls: Array = level.get("walls",[])
	for y in range(7):
		for x in range(7):
			var point := Vector2i(x,y)
			var rect := Rect2(origin + Vector2(float(x) * cell,float(y) * cell),Vector2(cell - 2.0,cell - 2.0))
			var border: bool = x == 0 or y == 0 or x == 6 or y == 6
			var fill: Color = Color(0.045,0.075,0.105)
			if border or walls.has(point):
				fill = Color(0.10,0.15,0.20)
			draw_rect(rect,fill,true)
			if point == level["start"]:
				draw_rect(rect.grow(-cell * 0.30),Color(0.34,0.48,0.62),true)
			if point == level["echo_plate"]:
				draw_circle(rect.get_center(),cell * 0.27,Color(0.75,0.42,1.0))
			if point == level["player_plate"]:
				draw_circle(rect.get_center(),cell * 0.27,Color(0.42,0.95,0.67))
			if point == level["exit"]:
				draw_rect(rect.grow(-cell * 0.23),Color(1.0,0.78,0.35),true)
	var echo_pos: Vector2i = _state.get("echo_pos",level["start"])
	var player_pos: Vector2i = _state.get("player_pos",level["start"])
	draw_circle(_center(origin,cell,echo_pos),cell * 0.31,Color(0.77,0.48,1.0,0.80))
	draw_arc(_center(origin,cell,echo_pos),cell * 0.34,0.0,TAU,32,Color(0.94,0.83,1.0),2.0)
	draw_circle(_center(origin,cell,player_pos),cell * 0.22,Color(0.34,0.91,1.0))
	draw_arc(_center(origin,cell,player_pos),cell * 0.31,0.0,TAU,32,Color(0.74,0.98,1.0),2.0)
func _center(origin: Vector2, cell: float, point: Vector2i) -> Vector2:
	return origin + Vector2((float(point.x) + 0.5) * cell,(float(point.y) + 0.5) * cell)
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",22)
	margin.add_theme_constant_override("margin_right",22)
	margin.add_theme_constant_override("margin_top",14)
	margin.add_theme_constant_override("margin_bottom",14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "KROLL // CHRONO VAULT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_color_override("font_color",Color(0.62,0.90,1.0))
	column.add_child(title)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size",16)
	_info_label.add_theme_color_override("font_color",Color(0.80,0.88,0.96))
	column.add_child(_info_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var move_row := HBoxContainer.new()
	move_row.add_theme_constant_override("separation",7)
	for index in range(MOVE_ACTIONS.size()):
		var button := Button.new()
		button.name = "MoveButton_" + MOVE_ACTIONS[index]
		button.text = MOVE_LABELS[index]
		button.custom_minimum_size = Vector2(0.0,48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_move_pressed.bind(MOVE_ACTIONS[index]))
		move_row.add_child(button)
		_move_buttons.append(button)
	column.add_child(move_row)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation",7)
	_record_button = Button.new()
	_record_button.name = "RecordEchoButton"
	_record_button.text = "RECORD ECHO  ·  R"
	_record_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_record_button.pressed.connect(_on_record_pressed)
	action_row.add_child(_record_button)
	_action_buttons.append(_record_button)
	var restart_button := Button.new()
	restart_button.name = "RestartLevelButton"
	restart_button.text = "RESTART VAULT  ·  C"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_on_restart_pressed)
	action_row.add_child(restart_button)
	_action_buttons.append(restart_button)
	_next_button = Button.new()
	_next_button.name = "NextLevelButton"
	_next_button.text = "NEXT VAULT  ·  N"
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(_on_next_pressed)
	action_row.add_child(_next_button)
	_action_buttons.append(_next_button)
	column.add_child(action_row)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color",Color(0.91,0.80,0.55))
	column.add_child(_status_label)
func _refresh_ui() -> void:
	if _state.is_empty():
		return
	var index: int = int(_state.get("level_index",0))
	var level: Dictionary = _rules.get_level_definition(index)
	_info_label.text = "VAULT %02d / %02d   ·   %s   ·   TURNS %02d   ·   CAMPAIGN %03d" % [index + 1,_rules.get_level_count(),str(level.get("title","UNKNOWN")),int(_state.get("turn_count",0)),int(_state.get("campaign_score",0))]
	var status: String = str(_state.get("status","playing"))
	if status == "playing":
		_status_label.text = "ECHO REPLAYING  ·  紫色回聲重走 A 路線；你要同步站上綠色 B 板，再走到出口。"
		if not bool(_state.get("echo_active",false)):
			_status_label.text = "先走到紫色 A 板，按 RECORD ECHO / R 錄下路線並倒帶。"
	elif status == "passed":
		_status_label.text = "VAULT OPEN  ·  雙重壓力板已同步，按 NEXT VAULT 前往下一區。"
	else:
		_status_label.text = "CAMPAIGN COMPLETE  ·  TOTAL SCORE %03d" % int(_state.get("total_score",0))
	var player_pos: Vector2i = _state.get("player_pos",Vector2i.ZERO)
	var can_record: bool = status == "playing" and player_pos == level.get("echo_plate",Vector2i(-1,-1)) and not _state.get("recording",[]).is_empty()
	_record_button.disabled = not can_record
	_next_button.disabled = status != "passed"
	for button in _move_buttons:
		button.disabled = status != "playing"
func _on_move_pressed(action: String) -> void:
	step_action(action)
func _on_record_pressed() -> void:
	commit_echo()
func _on_restart_pressed() -> void:
	restart_level()
func _on_next_pressed() -> void:
	advance_level()
func step_action(action: String) -> bool:
	var result: Dictionary = _rules.step_action(_state,action)
	if not bool(result.get("ok",false)):
		return false
	_state = result["state"]
	_refresh_ui()
	queue_redraw()
	return true
func commit_echo() -> bool:
	var result: Dictionary = _rules.commit_echo(_state)
	if not bool(result.get("ok",false)):
		return false
	_state = result["state"]
	_refresh_ui()
	queue_redraw()
	return true
func restart_level() -> bool:
	var result: Dictionary = _rules.restart_level(_state)
	if not bool(result.get("ok",false)):
		return false
	_state = result["state"]
	_refresh_ui()
	queue_redraw()
	return true
func advance_level() -> bool:
	var result: Dictionary = _rules.advance_level(_state)
	if not bool(result.get("ok",false)):
		return false
	_state = result["state"]
	_refresh_ui()
	queue_redraw()
	return true
func restart_campaign() -> bool:
	_state = _rules.restart_campaign()
	_refresh_ui()
	queue_redraw()
	return not _state.is_empty()
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_W, KEY_UP: step_action("up")
		KEY_S, KEY_DOWN: step_action("down")
		KEY_A, KEY_LEFT: step_action("left")
		KEY_D, KEY_RIGHT: step_action("right")
		KEY_SPACE: step_action("wait")
		KEY_R: commit_echo()
		KEY_C: restart_level()
		KEY_N: advance_level()
	get_viewport().set_input_as_handled()
func get_title_text() -> String:
	return "KROLL // CHRONO VAULT"
func get_level_count() -> int:
	return _rules.get_level_count()
func get_move_button_count() -> int:
	return _move_buttons.size()
func get_action_button_count() -> int:
	return _action_buttons.size()
func get_control_button_count() -> int:
	return _move_buttons.size() + _action_buttons.size()
func get_current_state() -> Dictionary:
	return _state.duplicate(true)
