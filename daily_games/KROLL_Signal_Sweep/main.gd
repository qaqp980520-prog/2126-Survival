extends Control

const Rules = preload("res://rules.gd")
const GRID_SIZE := Rules.GRID_SIZE

var target_count := 3
var scan_limit := 22
var cache_cells: Array[Vector2i] = []
var scanned_cells: Dictionary = {}
var found_cells: Dictionary = {}
var scan_count := 0
var finished := false

var status_label: Label
var counter_label: Label
var grid: GridContainer
var difficulty_picker: OptionButton

func _ready() -> void:
	randomize()
	_build_ui()
	_start_game()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#0b1220")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // SIGNAL SWEEP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#68e1fd"))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "掃描廢棄設施，找回隱藏的資料核心。空格顯示到最近核心的格數。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#c5d2e4"))
	layout.add_child(subtitle)

	var difficulty_row := HBoxContainer.new()
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_row.add_theme_constant_override("separation", 8)
	layout.add_child(difficulty_row)

	var difficulty_label := Label.new()
	difficulty_label.text = "難度"
	difficulty_label.add_theme_color_override("font_color", Color("#f4f7fb"))
	difficulty_row.add_child(difficulty_label)

	difficulty_picker = OptionButton.new()
	difficulty_picker.custom_minimum_size = Vector2(130, 36)
	for difficulty in Rules.DIFFICULTIES:
		difficulty_picker.add_item("%s（%d 核心／%d 次）" % [difficulty.name, difficulty.cores, difficulty.scans])
	difficulty_picker.select(1)
	difficulty_picker.item_selected.connect(_on_difficulty_selected)
	difficulty_row.add_child(difficulty_picker)

	counter_label = Label.new()
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_label.add_theme_font_size_override("font_size", 17)
	counter_label.add_theme_color_override("font_color", Color("#f4f7fb"))
	layout.add_child(counter_label)

	grid = GridContainer.new()
	grid.columns = GRID_SIZE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	layout.add_child(grid)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#f4f7fb"))
	layout.add_child(status_label)

	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 12)
	layout.add_child(buttons_row)

	var new_game_button := Button.new()
	new_game_button.text = "重新部署"
	new_game_button.custom_minimum_size = Vector2(150, 40)
	new_game_button.pressed.connect(_start_game)
	buttons_row.add_child(new_game_button)

	var instructions := Label.new()
	instructions.text = "提示：每個數字是該格到最近核心的曼哈頓距離。"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color("#8fa7c4"))
	layout.add_child(instructions)

func _on_difficulty_selected(index: int) -> void:
	if index < 0 or index >= Rules.DIFFICULTIES.size():
		return
	target_count = int(Rules.difficulty(index).cores)
	scan_limit = int(Rules.difficulty(index).scans)
	_start_game()

func _start_game() -> void:
	if difficulty_picker != null and difficulty_picker.selected >= 0:
		var selected: Dictionary = Rules.difficulty(difficulty_picker.selected)
		target_count = int(selected.cores)
		scan_limit = int(selected.scans)
	cache_cells.clear()
	scanned_cells.clear()
	found_cells.clear()
	scan_count = 0
	finished = false
	while cache_cells.size() < target_count:
		var cell := Vector2i(randi_range(0, GRID_SIZE - 1), randi_range(0, GRID_SIZE - 1))
		if not cache_cells.has(cell):
			cache_cells.append(cell)
	_rebuild_grid()
	status_label.text = "任務開始：選擇任意格子進行掃描。"
	_update_counter()

func _rebuild_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(64, 36)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.text = "?"
			button.tooltip_text = "座標 %d, %d" % [x + 1, y + 1]
			button.add_theme_font_size_override("font_size", 16)
			button.add_theme_color_override("font_color", Color("#e8f3ff"))
			button.pressed.connect(_scan_cell.bind(cell, button))
			grid.add_child(button)

func _scan_cell(cell: Vector2i, button: Button) -> void:
	if finished or scanned_cells.has(cell):
		return
	scanned_cells[cell] = true
	scan_count += 1
	button.disabled = true
	if cache_cells.has(cell):
		found_cells[cell] = true
		button.text = "CORE"
		button.add_theme_color_override("font_color", Color("#7dffb3"))
		button.add_theme_color_override("font_disabled_color", Color("#7dffb3"))
		status_label.text = "資料核心回收成功！還剩 %d 個。" % (target_count - found_cells.size())
	else:
		var nearest := Rules.nearest_core_distance(cell, cache_cells)
		button.text = str(nearest)
		button.add_theme_color_override("font_disabled_color", Color("#9eb2cc"))
		status_label.text = "掃描完成：依照數字推理核心位置。"
	_update_counter()
	if found_cells.size() == target_count:
		finished = true
		status_label.text = "任務成功！在 %d 次掃描內找回全部資料核心。" % scan_count
	elif scan_count >= scan_limit:
		finished = true
		status_label.text = "掃描配額用盡，任務失敗。按「重新部署」再試一次。"
	for child in grid.get_children():
		if child is Button and child.text == "?":
			child.disabled = finished

func _update_counter() -> void:
	counter_label.text = "掃描 %d / %d     |     已回收 %d / %d" % [scan_count, scan_limit, found_cells.size(), target_count]
