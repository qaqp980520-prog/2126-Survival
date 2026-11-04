extends Control

const Rules = preload("res://rules.gd")
const LANE_SEQUENCE := [0, 1, 2, 1, 0, 2]

var _state: Dictionary = {}
var _wave_running: bool = false
var _spawn_timer: float = 0.0
var _spawn_serial: int = 0
var _cells: Array[Button] = []
var _core_label: Label
var _stats_label: Label
var _message_label: Label
var _start_button: Button

func _ready() -> void:
	_state = Rules.create_state()
	_build_ui()
	_refresh_ui()
	set_process(true)

func _process(delta: float) -> void:
	if not _wave_running:
		return
	var safe_delta: float = maxf(delta, 0.0)
	_spawn_timer -= safe_delta
	var quota: int = Rules.wave_quota(int(_state.get("wave_index", 0)))
	if int(_state.get("spawned", 0)) < quota and _spawn_timer <= 0.0:
		var lane: int = int(LANE_SEQUENCE[int(_state.get("spawned", 0)) % LANE_SEQUENCE.size()])
		_spawn_serial += 1
		Rules.add_enemy(_state, lane, _spawn_serial)
		_spawn_timer = 1.15
	var towers: Array = _state.get("towers", [])
	for tower_index in range(towers.size()):
		var tower: Dictionary = towers[tower_index]
		var cooldown: float = maxf(0.0, float(tower.get("cooldown", 0.0)) - safe_delta)
		if cooldown <= 0.0 and Rules.fire_tower(_state, tower_index):
			cooldown = Rules.TOWER_COOLDOWN
		tower["cooldown"] = cooldown
		towers[tower_index] = tower
	_state["towers"] = towers
	Rules.advance_enemies(_state, safe_delta)
	var enemies: Array = _state.get("enemies", [])
	if bool(_state.get("game_over", false)):
		_wave_running = false
		_message_label.text = "CORE BREACHED — PRESS R TO RESTART"
	elif int(_state.get("spawned", 0)) >= quota and enemies.is_empty():
		_wave_running = false
		Rules.finish_wave(_state)
		if bool(_state.get("won", false)):
			_message_label.text = "BASTION SECURED — CAMPAIGN COMPLETE"
		else:
			_message_label.text = "WAVE CLEARED — REPOSITION OR REINFORCE"
	_refresh_ui()

func build_tower_at(lane: int, column: int) -> bool:
	var built: bool = Rules.build_tower(_state, lane, column)
	if built:
		_message_label.text = "TOWER ONLINE — LANE %d / COLUMN %d" % [lane + 1, column + 1]
	else:
		_message_label.text = "BUILD DENIED — CHECK CREDITS OR POSITION"
	_refresh_ui()
	return built

func start_wave() -> bool:
	if _wave_running or bool(_state.get("game_over", false)) or bool(_state.get("won", false)):
		return false
	var wave_index: int = int(_state.get("wave_index", 0))
	if Rules.wave_quota(wave_index) <= 0:
		return false
	_state["spawned"] = 0
	_state["enemies"] = []
	_spawn_timer = 0.12
	_wave_running = true
	_message_label.text = "INCOMING — DEFEND THE CORE"
	_refresh_ui()
	return true

func restart_campaign() -> void:
	_state = Rules.create_state()
	_wave_running = false
	_spawn_timer = 0.0
	_spawn_serial = 0
	if _message_label != null:
		_message_label.text = "BUILD TOWERS, THEN START THE WAVE"
	_refresh_ui()

func get_state_snapshot() -> Dictionary:
	return _state.duplicate(true)

func is_wave_running() -> bool:
	return _wave_running

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.075)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "BastionPanel"
	panel.custom_minimum_size = Vector2(820.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "KROLL BASTION ARRAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	layout.add_child(title)

	_core_label = Label.new()
	_core_label.name = "CoreLabel"
	_core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_core_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(_core_label)

	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_stats_label)

	var board := GridContainer.new()
	board.name = "BoardGrid"
	board.columns = Rules.COLUMN_COUNT
	board.add_theme_constant_override("h_separation", 7)
	board.add_theme_constant_override("v_separation", 7)
	layout.add_child(board)

	for lane in range(Rules.LANE_COUNT):
		for column in range(Rules.COLUMN_COUNT):
			var cell := Button.new()
			cell.name = "Cell_%d_%d" % [lane, column]
			cell.custom_minimum_size = Vector2(140.0, 82.0)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.focus_mode = Control.FOCUS_NONE
			cell.pressed.connect(_on_cell_pressed.bind(lane, column))
			board.add_child(cell)
			_cells.append(cell)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_message_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)

	_start_button = Button.new()
	_start_button.name = "StartWaveButton"
	_start_button.text = "SPACE  START WAVE"
	_start_button.custom_minimum_size = Vector2(0.0, 52.0)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(start_wave)
	actions.add_child(_start_button)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "R  RESTART CAMPAIGN"
	restart_button.custom_minimum_size = Vector2(0.0, 52.0)
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(restart_campaign)
	actions.add_child(restart_button)

	var controls := Label.new()
	controls.name = "ControlsLabel"
	controls.text = "Click / touch an empty cell in columns 2–4 to build (40 CR). SPACE starts a wave. R restarts."
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	layout.add_child(controls)

func _on_cell_pressed(lane: int, column: int) -> void:
	build_tower_at(lane, column)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_SPACE:
			start_wave()
		KEY_R:
			restart_campaign()
		KEY_1:
			build_tower_at(0, 1)
		KEY_2:
			build_tower_at(0, 2)
		KEY_3:
			build_tower_at(0, 3)
		KEY_4:
			build_tower_at(1, 1)
		KEY_5:
			build_tower_at(1, 2)
		KEY_6:
			build_tower_at(1, 3)
		KEY_7:
			build_tower_at(2, 1)
		KEY_8:
			build_tower_at(2, 2)
		KEY_9:
			build_tower_at(2, 3)

func _refresh_ui() -> void:
	if _core_label == null:
		return
	var wave_index: int = int(_state.get("wave_index", 0))
	var wave_text: String = "CAMPAIGN COMPLETE" if bool(_state.get("won", false)) else "WAVE %d / %d" % [mini(wave_index + 1, Rules.wave_count()), Rules.wave_count()]
	_core_label.text = "CORE INTEGRITY %d / %d     %s" % [int(_state.get("core_hp", 0)), Rules.STARTING_CORE_HP, wave_text]
	var towers: Array = _state.get("towers", [])
	var enemies: Array = _state.get("enemies", [])
	_stats_label.text = "CREDITS %d     TOWERS %d     KILLS %d     LEAKS %d     SCORE %d / 300" % [
		int(_state.get("credits", 0)),
		towers.size(),
		int(_state.get("kills", 0)),
		int(_state.get("leaks", 0)),
		int(_state.get("score", 0))
	]
	for lane in range(Rules.LANE_COUNT):
		for column in range(Rules.COLUMN_COUNT):
			var cell_index: int = lane * Rules.COLUMN_COUNT + column
			var button: Button = _cells[cell_index]
			var tower: Dictionary = {}
			for candidate in towers:
				if int(candidate.get("lane", -1)) == lane and int(candidate.get("column", -1)) == column:
					tower = candidate
					break
			var enemy_count: int = 0
			for enemy in enemies:
				if int(enemy.get("lane", -1)) == lane and clampi(roundi(float(enemy.get("x", 0.0))), 0, Rules.COLUMN_COUNT - 1) == column:
					enemy_count += 1
			if column == 0:
				button.text = "ENTRY\nENEMIES %d" % enemy_count
			elif column == Rules.COLUMN_COUNT - 1:
				button.text = "CORE\nENEMIES %d" % enemy_count
			elif not tower.is_empty():
				button.text = "TOWER\nLEVEL %d\nENEMIES %d" % [int(tower.get("level", 1)), enemy_count]
			else:
				button.text = "BUILD TOWER\n40 CREDITS\nENEMIES %d" % enemy_count
			button.disabled = column == 0 or column == Rules.COLUMN_COUNT - 1 or not tower.is_empty() or int(_state.get("credits", 0)) < Rules.TOWER_COST or bool(_state.get("game_over", false)) or bool(_state.get("won", false))
	_start_button.disabled = _wave_running or bool(_state.get("game_over", false)) or bool(_state.get("won", false))
	if bool(_state.get("game_over", false)):
		_start_button.text = "CORE BREACHED"
	elif bool(_state.get("won", false)):
		_start_button.text = "CAMPAIGN COMPLETE"
	else:
		_start_button.text = "SPACE  START WAVE %d" % mini(wave_index + 1, Rules.wave_count())
