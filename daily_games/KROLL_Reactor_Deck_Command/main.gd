extends Control

var _rules: RefCounted
var _state: Dictionary = {}
var _message: String = "Deploy cards to keep the reactor core online."
var _card_buttons: Array[Button] = []
var _enemy_label: Label
var _status_label: Label
var _score_label: Label
var _end_turn_button: Button
var _next_button: Button
var _restart_button: Button

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Reactor Deck Command main script is unavailable.")
		return
	var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Reactor Deck Command could not load rules: " + rules_path)
		return
	_rules = rules_script.new() as RefCounted
	if _rules == null:
		push_error("Reactor Deck Command rules could not be instantiated.")
		return
	_state = _rules.create_state(10203)
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.035, 0.065)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact_layout: bool = get_viewport_rect().size.x < 620.0
	var inset: int = 10 if compact_layout else 24
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "ReactorDeckScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "KROLL // REACTOR DECK COMMAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25 if compact_layout else 34)
	title.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THREE ENCOUNTERS · THREE ENERGY · ONE CORE TO PROTECT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	column.add_child(subtitle)

	var enemy_panel := PanelContainer.new()
	column.add_child(enemy_panel)
	var enemy_margin := MarginContainer.new()
	enemy_margin.add_theme_constant_override("margin_left", 14)
	enemy_margin.add_theme_constant_override("margin_right", 14)
	enemy_margin.add_theme_constant_override("margin_top", 10)
	enemy_margin.add_theme_constant_override("margin_bottom", 10)
	enemy_panel.add_child(enemy_margin)
	_enemy_label = Label.new()
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_label.add_theme_font_size_override("font_size", 20)
	_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.46))
	enemy_margin.add_child(_enemy_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	column.add_child(_status_label)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.76))
	column.add_child(_score_label)

	var hand_title := Label.new()
	hand_title.text = "TACTICAL HAND"
	hand_title.add_theme_color_override("font_color", Color(0.58, 0.78, 1.0))
	column.add_child(hand_title)

	var hand_grid := GridContainer.new()
	hand_grid.name = "CardHand"
	hand_grid.columns = 2 if compact_layout else 5
	hand_grid.add_theme_constant_override("h_separation", 8)
	hand_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(hand_grid)
	for index in range(5):
		var card_button := Button.new()
		card_button.custom_minimum_size = Vector2(0.0, 108.0 if compact_layout else 128.0)
		card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_button.add_theme_font_size_override("font_size", 13 if compact_layout else 15)
		card_button.pressed.connect(play_card.bind(index))
		_card_buttons.append(card_button)
		hand_grid.add_child(card_button)

	var action_row := GridContainer.new()
	action_row.columns = 1 if compact_layout else 3
	action_row.add_theme_constant_override("h_separation", 8)
	action_row.add_theme_constant_override("v_separation", 8)
	column.add_child(action_row)
	_end_turn_button = _add_action_button(action_row, "END TURN  [E]", Callable(self, "end_turn"))
	_next_button = _add_action_button(action_row, "NEXT ENCOUNTER  [N]", Callable(self, "advance_encounter"))
	_restart_button = _add_action_button(action_row, "RESTART CAMPAIGN  [R]", Callable(self, "restart_campaign"))

	var help := Label.new()
	help.text = "Play cards 1–5, end the turn with E, advance after a victory with N, or restart with R. Mouse and touch users can tap the cards and action buttons."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82))
	column.add_child(help)

func _add_action_button(parent: GridContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1: play_card(0)
		KEY_2: play_card(1)
		KEY_3: play_card(2)
		KEY_4: play_card(3)
		KEY_5: play_card(4)
		KEY_E: end_turn()
		KEY_N: advance_encounter()
		KEY_R: restart_campaign()

func play_card(hand_index: int) -> bool:
	if _rules == null:
		return false
	var report: Dictionary = _rules.play_card(_state, hand_index)
	if not bool(report.get("ok", false)):
		_message = "Card unavailable: " + str(report.get("error", "unknown"))
		_refresh_ui()
		return false
	var card_definition: Dictionary = _rules.get_card_definition(str(report.get("card_id", "")))
	_message = "Played %s. Damage %d · Block +%d · Repair %d." % [
		str(card_definition.get("name", report.get("card_id", ""))),
		int(report.get("damage", 0)),
		int(report.get("block_gained", 0)),
		int(report.get("heal", 0))
	]
	if str(_state.get("status", "")) == "encounter_won":
		_message = "ENCOUNTER CLEARED. Advance when ready."
	elif str(_state.get("status", "")) == "victory":
		_message = "REACTOR SECURED. CAMPAIGN COMPLETE."
	elif str(_state.get("status", "")) == "defeat":
		_message = "CORE OFFLINE. Restart the campaign to try again."
	_refresh_ui()
	return true

func end_turn() -> bool:
	if _rules == null:
		return false
	var report: Dictionary = _rules.end_turn(_state)
	if not bool(report.get("ok", false)):
		_message = "The current encounter is not accepting another turn."
		_refresh_ui()
		return false
	_message = "Enemy attack: %d blocked, %d damage reached the core." % [
		int(report.get("blocked", 0)),
		int(report.get("damage_taken", 0))
	]
	if str(_state.get("status", "")) == "defeat":
		_message = "CORE OFFLINE. Restart the campaign to try again."
	_refresh_ui()
	return true

func advance_encounter() -> bool:
	if _rules == null or not bool(_rules.advance_encounter(_state)):
		return false
	_message = "New threat detected. Your core HP and remaining deck carry forward."
	_refresh_ui()
	return true

func restart_campaign() -> bool:
	if _rules == null:
		return false
	_state = _rules.restart_campaign(10203)
	_message = "Campaign restarted. Protect the reactor through all three encounters."
	_refresh_ui()
	return true

func _refresh_ui() -> void:
	if _rules == null or _state.is_empty():
		return
	var status: String = str(_state.get("status", ""))
	var enemy_name: String = str(_state.get("enemy_name", ""))
	if is_instance_valid(_enemy_label):
		_enemy_label.text = "%s\nENEMY HP %d / %d   ·   NEXT ATTACK %d" % [
			enemy_name,
			int(_state.get("enemy_hp", 0)),
			int(_state.get("enemy_max_hp", 0)),
			int(_state.get("enemy_attack", 0))
		]
	if is_instance_valid(_status_label):
		_status_label.text = "%s   ·   TURN %d   ·   STATE %s" % [
			_message,
			int(_state.get("turn", 1)),
			status.to_upper()
		]
	if is_instance_valid(_score_label):
		_score_label.text = "CORE %d / %d HP   ·   BLOCK %d   ·   ENERGY %d / %d   ·   SCORE %d / 300" % [
			int(_state.get("hp", 0)),
			int(_state.get("max_hp", 36)),
			int(_state.get("block", 0)),
			int(_state.get("energy", 0)),
			_rules.get_energy_per_turn(),
			int(_state.get("score", 0))
		]
	var hand: Array = _state.get("hand", [])
	for index in range(_card_buttons.size()):
		var button: Button = _card_buttons[index]
		if index >= hand.size():
			button.text = "EMPTY\nNo card"
			button.disabled = true
			continue
		var card_id: String = str(hand[index])
		var definition: Dictionary = _rules.get_card_definition(card_id)
		button.text = "%s\nCOST %d\n%s" % [
			str(definition.get("name", card_id)),
			int(definition.get("cost", 0)),
			str(definition.get("description", ""))
		]
		button.disabled = status != "playing" or int(_state.get("energy", 0)) < int(definition.get("cost", 0))
	if is_instance_valid(_end_turn_button):
		_end_turn_button.disabled = status != "playing"
	if is_instance_valid(_next_button):
		_next_button.disabled = status != "encounter_won"

func get_title_text() -> String:
	return "KROLL // REACTOR DECK COMMAND"

func get_encounter_count() -> int:
	return _rules.get_encounter_count() if _rules != null else 0

func get_card_button_count() -> int:
	return _card_buttons.size()

func get_hand_card_count() -> int:
	var hand: Array = _state.get("hand", [])
	return hand.size()

func get_status_text() -> String:
	return str(_state.get("status", ""))

func get_score() -> int:
	return int(_state.get("score", 0))

func get_energy() -> int:
	return int(_state.get("energy", 0))

func get_turn_number() -> int:
	return int(_state.get("turn", 0))

func get_encounter_index() -> int:
	return int(_state.get("encounter_index", -1))

func get_enemy_hp() -> int:
	return int(_state.get("enemy_hp", 0))
