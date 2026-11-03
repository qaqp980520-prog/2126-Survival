extends Control

const Rules = preload("res://rules.gd")

var level_index: int = 0
var level_data: Dictionary = {}
var orientations: Array = []
var moves: int = 0
var score: int = 0
var completed_levels: Dictionary = {}
var level_completed: bool = false
var campaign_finished: bool = false
var beam_path: Array = []

var level_label: Label
var score_label: Label
var moves_label: Label
var status_label: Label
var grid: GridContainer
var fire_button: Button
var reset_button: Button
var next_button: Button

func _ready() -> void:
	_build_ui()
	_restart_campaign()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#08121f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // PRISM BEAM LAB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#79e4ff"))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "旋轉鏡片，讓光束繞過隔板並抵達接收器。每次旋轉都會消耗一步。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#c3d3e5"))
	layout.add_child(subtitle)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 26)
	layout.add_child(header)

	level_label = Label.new()
	level_label.add_theme_color_override("font_color", Color("#f1f6ff"))
	header.add_child(level_label)

	score_label = Label.new()
	score_label.add_theme_color_override("font_color", Color("#7dffb3"))
	header.add_child(score_label)

	moves_label = Label.new()
	moves_label.add_theme_color_override("font_color", Color("#ffd28a"))
	header.add_child(moves_label)

	grid = GridContainer.new()
	grid.columns = Rules.GRID_SIZE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	layout.add_child(grid)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#f1f6ff"))
	layout.add_child(status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)

	fire_button = Button.new()
	fire_button.text = "發射光束"
	fire_button.custom_minimum_size = Vector2(140, 40)
	fire_button.pressed.connect(_fire_beam)
	actions.add_child(fire_button)

	reset_button = Button.new()
	reset_button.text = "重置本關"
	reset_button.custom_minimum_size = Vector2(120, 40)
	reset_button.pressed.connect(_reset_level)
	actions.add_child(reset_button)

	next_button = Button.new()
	next_button.text = "下一關"
	next_button.custom_minimum_size = Vector2(120, 40)
	next_button.pressed.connect(_next_level)
	actions.add_child(next_button)

	var campaign_button := Button.new()
	campaign_button.text = "重開戰役"
	campaign_button.custom_minimum_size = Vector2(120, 40)
	campaign_button.pressed.connect(_restart_campaign)
	actions.add_child(campaign_button)

	var instructions := Label.new()
	instructions.text = "操作：點擊鏡片旋轉；1–4 旋轉鏡片；Space 發射；R 重置；N 下一關；C 重開戰役。／ 為斜鏡，\\ 為反斜鏡。"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_color_override("font_color", Color("#8fa7c4"))
	layout.add_child(instructions)

func _restart_campaign() -> void:
	level_index = 0
	score = 0
	completed_levels.clear()
	campaign_finished = false
	_load_level(level_index)

func _load_level(index: int) -> void:
	level_index = index
	level_data = Rules.get_level(level_index)
	orientations = Rules.get_initial_orientations(level_data)
	moves = 0
	level_completed = false
	campaign_finished = false
	beam_path.clear()
	status_label.text = "任務開始：調整四片鏡片，再發射光束。"
	_update_ui()

func _rotate_mirror(index: int) -> bool:
	if level_completed or campaign_finished or index < 0 or index >= orientations.size():
		return false
	var next_orientation: int = Rules.rotate_orientation(int(orientations[index]))
	if next_orientation < 0:
		return false
	orientations[index] = next_orientation
	moves += 1
	beam_path.clear()
	status_label.text = "鏡片 %d 已旋轉。準備好後發射光束。" % (index + 1)
	_update_ui()
	return true

func _fire_beam() -> bool:
	if level_completed or campaign_finished:
		return false
	var report: Dictionary = Rules.trace(level_data, orientations)
	beam_path = report.get("path", [])
	if bool(report.get("success", false)):
		level_completed = true
		if not completed_levels.has(level_index):
			completed_levels[level_index] = Rules.score_for_moves(moves, int(level_data.get("par", 0)))
		score = 0
		for reward in completed_levels.values():
			score += int(reward)
		status_label.text = "光束已抵達接收器！本關獲得 %d 分。" % int(completed_levels[level_index])
	else:
		status_label.text = "光束中斷：%s。調整鏡片後再試一次。" % str(report.get("reason", "unknown"))
	_update_ui()
	return bool(report.get("success", false))

func _reset_level() -> bool:
	if level_completed or campaign_finished:
		return false
	orientations = Rules.get_initial_orientations(level_data)
	moves = 0
	beam_path.clear()
	status_label.text = "本關已重置。"
	_update_ui()
	return true

func _next_level() -> bool:
	if campaign_finished or not level_completed:
		return false
	if level_index >= Rules.level_count() - 1:
		campaign_finished = true
		status_label.text = "三座設施全部重新連線！戰役完成，總分 %d / 300。" % score
		_update_ui()
		return true
	_load_level(level_index + 1)
	return true

func _update_ui() -> void:
	if level_data.is_empty():
		return
	level_label.text = "LEVEL %d / %d  |  %s" % [level_index + 1, Rules.level_count(), str(level_data.get("name", ""))]
	score_label.text = "分數 %d / 300" % score
	moves_label.text = "旋轉 %d 步" % moves
	fire_button.disabled = level_completed or campaign_finished
	reset_button.disabled = level_completed or campaign_finished
	next_button.disabled = not level_completed or campaign_finished
	next_button.text = "完成戰役" if level_index == Rules.level_count() - 1 else "下一關"
	_render_grid()

func _render_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var emitter: Vector2i = level_data.get("emitter", Vector2i.ZERO)
	var direction: Vector2i = level_data.get("direction", Vector2i.ZERO)
	var receiver: Vector2i = level_data.get("receiver", Vector2i.ZERO)
	var walls: Array = level_data.get("walls", [])
	var mirror_positions: Array = level_data.get("mirror_positions", [])
	for y in range(Rules.GRID_SIZE):
		for x in range(Rules.GRID_SIZE):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(58, 58)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 23)
			button.add_theme_color_override("font_color", Color("#eaf3ff"))
			button.add_theme_color_override("font_disabled_color", Color("#eaf3ff"))
			var mirror_index: int = mirror_positions.find(cell)
			if cell == emitter:
				button.text = "E" + Rules.direction_glyph(direction)
				button.add_theme_color_override("font_color", Color("#72d9ff"))
				button.add_theme_color_override("font_disabled_color", Color("#72d9ff"))
			elif cell == receiver:
				button.text = "RX"
				button.add_theme_color_override("font_color", Color("#7dffb3"))
				button.add_theme_color_override("font_disabled_color", Color("#7dffb3"))
			elif walls.has(cell):
				button.text = "■"
				button.add_theme_color_override("font_color", Color("#718096"))
				button.add_theme_color_override("font_disabled_color", Color("#718096"))
			elif mirror_index >= 0:
				button.text = "/" if int(orientations[mirror_index]) == 0 else "\\"
				button.disabled = level_completed or campaign_finished
				button.add_theme_color_override("font_color", Color("#ffd28a"))
				button.add_theme_color_override("font_disabled_color", Color("#ffd28a"))
				button.pressed.connect(_rotate_mirror.bind(mirror_index))
				button.tooltip_text = "鏡片 %d：點擊旋轉" % (mirror_index + 1)
			elif beam_path.has(cell):
				button.text = "•"
				button.add_theme_color_override("font_color", Color("#ffe17a"))
				button.add_theme_color_override("font_disabled_color", Color("#ffe17a"))
			else:
				button.text = ""
			if mirror_index < 0:
				button.disabled = true
			grid.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_rotate_mirror(event.keycode - KEY_1)
	elif event.keycode == KEY_SPACE:
		_fire_beam()
	elif event.keycode == KEY_R:
		_reset_level()
	elif event.keycode == KEY_N:
		_next_level()
	elif event.keycode == KEY_C:
		_restart_campaign()
