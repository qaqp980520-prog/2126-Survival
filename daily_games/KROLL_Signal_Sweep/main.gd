extends Control

const GRID_SIZE := 8
const CACHE_COUNT := 3
const SCAN_LIMIT := 22

var cache_cells: Array[Vector2i] = []
var scanned_cells: Dictionary = {}
var found_cells: Dictionary = {}
var scan_count := 0
var finished := false

var status_label: Label
var counter_label: Label
var grid: GridContainer

func _ready() -> void:
	_build_ui()
	_start_game()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#0b1220")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "KROLL // SIGNAL SWEEP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#68e1fd"))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "掃描廢棄設施，找回 3 個資料核心。每次掃描會顯示最近核心的曼哈頓距離。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#c5d2e4"))
	layout.add_child(subtitle)

	counter_label = Label.new()
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_label.add_theme_font_size_override("font_size", 18)
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
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#f4f7fb"))
	layout.add_child(status_label)

	var new_game_button := Button.new()
	new_game_button.text = "重新部署"
	new_game_button.custom_minimum_size = Vector2(180, 42)
	new_game_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_game_button.pressed.connect(_start_game)
	layout.add_child(new_game_button)

func _start_game() -> void:
	cache_cells.clear()
	scanned_cells.clear()
	found_cells.clear()
	scan_count = 0
	finished = false
	while cache_cells.size() < CACHE_COUNT:
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
			button.custom_minimum_size = Vector2(64, 38)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.text = "?"
			button.tooltip_text = "座標 %d, %d" % [x + 1, y + 1]
			button.add_theme_font_size_override("font_size", 17)
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
		status_label.text = "資料核心回收成功！還剩 %d 個。" % (CACHE_COUNT - found_cells.size())
	else:
		var nearest := 999
		for cache in cache_cells:
			nearest = mini(nearest, absi(cell.x - cache.x) + absi(cell.y - cache.y))
		button.text = str(nearest)
		button.add_theme_color_override("font_disabled_color", Color("#9eb2cc"))
		status_label.text = "掃描完成：數字代表距離最近資料核心的格數。"
	_update_counter()
	if found_cells.size() == CACHE_COUNT:
		finished = true
		status_label.text = "任務成功！在 %d 次掃描內找回全部資料核心。" % scan_count
	elif scan_count >= SCAN_LIMIT:
		finished = true
		status_label.text = "掃描配額用盡，任務失敗。按「重新部署」再試一次。"
	for child in grid.get_children():
		if child is Button and child.text == "?":
			child.disabled = finished

func _update_counter() -> void:
	counter_label.text = "掃描 %d / %d     |     已回收 %d / %d" % [scan_count, SCAN_LIMIT, found_cells.size(), CACHE_COUNT]
