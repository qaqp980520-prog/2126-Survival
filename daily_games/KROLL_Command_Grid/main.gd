extends Control

const Rules = preload("res://rules.gd")

var state: Dictionary = {}
var grid: GridContainer
var status_label: Label
var stats_label: Label
var cell_buttons: Array[Button] = []

func _ready() -> void:
	state = Rules.create_state()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.028, 0.052)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // COMMAND GRID"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	layout.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(status_label)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(stats_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)

	grid = GridContainer.new()
	grid.columns = Rules.WIDTH
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	center.add_child(grid)

	for y in range(Rules.HEIGHT):
		for x in range(Rules.WIDTH):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(48, 48)
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(_on_cell_pressed.bind(cell))
			grid.add_child(button)
			cell_buttons.append(button)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)

	_add_move_button(controls, "↑", Vector2i(0, -1))
	_add_move_button(controls, "←", Vector2i(-1, 0))
	_add_move_button(controls, "↓", Vector2i(0, 1))
	_add_move_button(controls, "→", Vector2i(1, 0))

	var emp_button := Button.new()
	emp_button.text = "EMP 脈衝"
	emp_button.custom_minimum_size = Vector2(130, 42)
	emp_button.pressed.connect(use_emp)
	controls.add_child(emp_button)

	var restart_button := Button.new()
	restart_button.text = "重新開始 (R)"
	restart_button.custom_minimum_size = Vector2(150, 42)
	restart_button.pressed.connect(restart_game)
	controls.add_child(restart_button)

	var help := Label.new()
	help.text = "方向鍵／WASD 移動；Space 使用 EMP。收集全部 4 個資料核心後抵達 X。每個動作後，安全機器人會追蹤你。P=玩家  B=機器人  D=資料  #=牆"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.68, 0.76, 0.86))
	layout.add_child(help)

func _add_move_button(parent: HBoxContainer, label_text: String, delta: Vector2i) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(46, 42)
	button.pressed.connect(attempt_move.bind(delta))
	parent.add_child(button)

func _on_cell_pressed(cell: Vector2i) -> void:
	var player: Vector2i = state.get("player", Vector2i.ZERO)
	var delta := cell - player
	if absi(delta.x) + absi(delta.y) == 1:
		attempt_move(delta)

func attempt_move(delta: Vector2i) -> bool:
	var moved := Rules.try_move(state, delta)
	_refresh()
	return moved

func use_emp() -> bool:
	var used := Rules.use_emp(state)
	_refresh()
	return used

func restart_game() -> void:
	state = Rules.create_state()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_W, KEY_UP:
			attempt_move(Vector2i(0, -1))
		KEY_S, KEY_DOWN:
			attempt_move(Vector2i(0, 1))
		KEY_A, KEY_LEFT:
			attempt_move(Vector2i(-1, 0))
		KEY_D, KEY_RIGHT:
			attempt_move(Vector2i(1, 0))
		KEY_SPACE:
			use_emp()
		KEY_R:
			restart_game()

func _refresh() -> void:
	if not is_instance_valid(grid):
		return
	for index in range(cell_buttons.size()):
		var cell := Vector2i(index % Rules.WIDTH, int(index / Rules.WIDTH))
		var button := cell_buttons[index]
		button.text = Rules.cell_label(state, cell)
		button.disabled = str(state.get("status", "playing")) != "playing" or Rules.is_wall_cell(cell)
		var color := Color(0.76, 0.82, 0.9)
		match button.text:
			"P":
				color = Color(0.25, 0.95, 1.0)
			"B":
				color = Color(1.0, 0.35, 0.32)
			"D":
				color = Color(1.0, 0.78, 0.22)
			"X":
				color = Color(0.42, 1.0, 0.55)
			"#":
				color = Color(0.3, 0.34, 0.4)
		button.add_theme_color_override("font_color", color)
	var status := str(state.get("status", "playing"))
	match status:
		"won":
			status_label.text = "任務成功：資料已回收，撤離完成。"
			status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
		"lost":
			status_label.text = "任務失敗：被攔截或行動回合耗盡。按 R 重試。"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		_:
			status_label.text = "回收資料核心，避開追蹤中的安全機器人。"
			status_label.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	stats_label.text = "資料：%d/4    EMP：%d    剩餘回合：%d" % [
		int(state.get("collected", 0)),
		int(state.get("emp", 0)),
		int(state.get("turns_left", 0))
	]
