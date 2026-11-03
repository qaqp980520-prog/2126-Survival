extends Control

var _rules: Variant
var _current_gallery: int = 0
var _placements: Dictionary = {}
var _placement_order: Array[int] = []
var _selected_card: int = -1
var _status: String = "playing"
var _message: String = "Choose four artifacts. Matching themes and adjacent tags increase the exhibit score."
var _total_score: int = 0
var _passed_galleries: Array[bool] = []
var _gallery_scores: Array[int] = []

var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _score_label: Label
var _card_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _recall_button: Button
var _reset_button: Button
var _next_button: Button
var _restart_button: Button

func _ready() -> void:
	var attached_script: Script = get_script() as Script
	if attached_script == null:
		push_error("Archive Curator main script is unavailable.")
		return
	var rules_path: String = attached_script.resource_path.get_base_dir().path_join("rules.gd")
	var rules_script: Script = load(rules_path) as Script
	if rules_script == null:
		push_error("Archive Curator could not load rules: " + rules_path)
		return
	_rules = rules_script.new() as RefCounted
	if _rules == null:
		push_error("Archive Curator rules instance could not be created.")
		return
	for _index in range(_rules.get_gallery_count()):
		_passed_galleries.append(false)
		_gallery_scores.append(0)
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.075)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var compact_layout: bool = get_viewport_rect().size.x < 850.0
	var scroll := ScrollContainer.new()
	scroll.name = "ArchiveScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	_title_label = Label.new()
	_title_label.text = "KROLL // ARCHIVE CURATOR"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.68, 0.9, 1.0))
	column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 17)
	_subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.94))
	column.add_child(_subtitle_label)

	var body: BoxContainer
	if compact_layout:
		body = VBoxContainer.new()
	else:
		body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)

	var card_panel := VBoxContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(card_panel)
	var card_heading := Label.new()
	card_heading.text = "ARCHIVE ITEMS  ·  SELECT ONE"
	card_heading.add_theme_font_size_override("font_size", 16)
	card_panel.add_child(card_heading)
	var card_grid := GridContainer.new()
	card_grid.columns = 1 if compact_layout else 2
	card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 10)
	card_grid.add_theme_constant_override("v_separation", 10)
	card_panel.add_child(card_grid)
	for card_index in range(6):
		var card_button := Button.new()
		card_button.custom_minimum_size = Vector2(320, 80) if compact_layout else Vector2(235, 92)
		card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_button.pressed.connect(_on_card_pressed.bind(card_index))
		_card_buttons.append(card_button)
		card_grid.add_child(card_button)

	var slot_panel := VBoxContainer.new()
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(slot_panel)
	var slot_heading := Label.new()
	slot_heading.text = "EXHIBIT CASES  ·  PLACE SELECTED ITEM"
	slot_heading.add_theme_font_size_override("font_size", 16)
	slot_panel.add_child(slot_heading)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 1 if compact_layout else 2
	slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_grid.add_theme_constant_override("h_separation", 10)
	slot_grid.add_theme_constant_override("v_separation", 10)
	slot_panel.add_child(slot_grid)
	for slot_index in range(4):
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(320, 100) if compact_layout else Vector2(220, 145)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.pressed.connect(_on_slot_pressed.bind(slot_index))
		_slot_buttons.append(slot_button)
		slot_grid.add_child(slot_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.62))
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)

	_score_label = Label.new()
	_score_label.add_theme_color_override("font_color", Color(0.68, 0.9, 1.0))
	column.add_child(_score_label)

	var action_row := GridContainer.new()
	action_row.columns = 2 if compact_layout else 4
	action_row.add_theme_constant_override("h_separation", 10)
	action_row.add_theme_constant_override("v_separation", 8)
	column.add_child(action_row)
	_recall_button = _add_action_button(action_row, "RECALL", Callable(self, "undo_last"))
	_reset_button = _add_action_button(action_row, "RESET GALLERY", Callable(self, "reset_gallery"))
	_next_button = _add_action_button(action_row, "NEXT GALLERY", Callable(self, "advance_gallery"))
	_restart_button = _add_action_button(action_row, "RESTART CAMPAIGN", Callable(self, "restart_campaign"))

func _add_action_button(parent: GridContainer, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(150, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	_action_buttons.append(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1: _on_card_pressed(0)
		KEY_2: _on_card_pressed(1)
		KEY_3: _on_card_pressed(2)
		KEY_4: _on_card_pressed(3)
		KEY_5: _on_card_pressed(4)
		KEY_6: _on_card_pressed(5)
		KEY_Q: _place_selected_in_slot(0)
		KEY_W: _place_selected_in_slot(1)
		KEY_A: _place_selected_in_slot(2)
		KEY_S: _place_selected_in_slot(3)
		KEY_BACKSPACE, KEY_DELETE: undo_last()
		KEY_R: reset_gallery()
		KEY_N: advance_gallery()
		KEY_C: restart_campaign()

func _on_card_pressed(card_index: int) -> void:
	select_card_for_test(card_index)

func _on_slot_pressed(slot_index: int) -> void:
	place_selected_for_test(slot_index)

func select_card_for_test(card_index: int) -> bool:
	if _status != "playing" or _placements.size() >= 4 or card_index < 0 or card_index >= 6:
		return false
	if _placements.values().has(card_index):
		return false
	_selected_card = card_index
	_message = "Selected item %d. Choose an exhibit case." % (card_index + 1)
	_refresh_ui()
	return true

func place_selected_for_test(slot_index: int) -> bool:
	if _status != "playing" or _selected_card < 0:
		return false
	var result: Dictionary = _rules.place_card(_placements, _selected_card, slot_index)
	if not bool(result.get("ok", false)):
		_message = "That case is occupied or the item is already displayed."
		_refresh_ui()
		return false
	_placements = result.get("placements", {}).duplicate(true)
	_placement_order.append(slot_index)
	_selected_card = -1
	_message = "Item placed. Keep building the exhibit."
	if _placements.size() == 4:
		var report: Dictionary = _rules.calculate_score(_current_gallery, _placements)
		if bool(report.get("passed", false)):
			if not _passed_galleries[_current_gallery]:
				var earned: int = int(report.get("total_score", 0))
				_passed_galleries[_current_gallery] = true
				_gallery_scores[_current_gallery] = earned
				_total_score += earned
			_status = "won" if _current_gallery == _rules.get_gallery_count() - 1 else "gallery_clear"
			_message = "Gallery approved: %d points. %d theme items and %d adjacency links." % [
				int(report.get("total_score", 0)),
				int(report.get("theme_count", 0)),
				int(report.get("adjacency_count", 0))
			]
		else:
			_message = "Exhibit needs at least two theme items and %d points. Recall a case to adjust it." % int(report.get("target", 0))
	_refresh_ui()
	return true

func undo_last() -> bool:
	if _status != "playing" or _placement_order.is_empty():
		return false
	var slot_index: int = _placement_order.pop_back()
	var card_index: int = int(_placements.get(slot_index, -1))
	_placements.erase(slot_index)
	_selected_card = card_index
	_message = "Last case recalled. Reposition the item or choose another."
	_refresh_ui()
	return true

func reset_gallery() -> bool:
	if _status != "playing" or _passed_galleries[_current_gallery]:
		return false
	_placements.clear()
	_placement_order.clear()
	_selected_card = -1
	_message = "Gallery reset. Build a new exhibit."
	_refresh_ui()
	return true

func advance_gallery() -> bool:
	if _status != "gallery_clear" or _current_gallery >= _rules.get_gallery_count() - 1:
		return false
	_current_gallery += 1
	_placements.clear()
	_placement_order.clear()
	_selected_card = -1
	_status = "playing"
	_message = "New gallery. Match the theme and build adjacent tag links."
	_refresh_ui()
	return true

func restart_campaign() -> bool:
	_current_gallery = 0
	_placements.clear()
	_placement_order.clear()
	_selected_card = -1
	_total_score = 0
	_status = "playing"
	for index in range(_passed_galleries.size()):
		_passed_galleries[index] = false
		_gallery_scores[index] = 0
	_message = "Fresh campaign. Curate each gallery without wasting a case."
	_refresh_ui()
	return true

func _refresh_ui() -> void:
	if _rules == null or _title_label == null:
		return
	var gallery: Dictionary = _rules.get_gallery(_current_gallery)
	var cards: Array = gallery.get("cards", [])
	_title_label.text = "KROLL // ARCHIVE CURATOR"
	_subtitle_label.text = "%s  ·  THEME: %s  ·  TARGET: %d" % [
		str(gallery.get("name", "")),
		str(gallery.get("theme", "")).to_upper(),
		int(gallery.get("target", 0))
	]
	_status_label.text = _message
	var report: Dictionary = _rules.calculate_score(_current_gallery, _placements)
	_score_label.text = "CAMPAIGN %d  ·  CURRENT EXHIBIT %d / %d" % [
		_total_score,
		int(report.get("total_score", 0)),
		int(report.get("target", 0))
	]
	for card_index in range(_card_buttons.size()):
		var card: Dictionary = cards[card_index]
		var prefix: String = "▶ " if _selected_card == card_index else ""
		_card_buttons[card_index].text = "%s%d  %s\n%s  ·  BASE %d" % [
			prefix,
			card_index + 1,
			str(card.get("name", "")),
			_join_tags(card.get("tags", [])),
			int(card.get("base", 0))
		]
		_card_buttons[card_index].disabled = _status != "playing" or _placements.values().has(card_index) or _placements.size() >= 4
	for slot_index in range(_slot_buttons.size()):
		if _placements.has(slot_index):
			var placed_card: Dictionary = cards[int(_placements[slot_index])]
			_slot_buttons[slot_index].text = "CASE %s\n%s\n%s" % [
				_slot_letter(slot_index),
				str(placed_card.get("name", "")),
				_join_tags(placed_card.get("tags", []))
			]
		else:
			_slot_buttons[slot_index].text = "CASE %s\nOPEN\nChoose a card" % (_slot_letter(slot_index))
		_slot_buttons[slot_index].disabled = _status != "playing" or _selected_card < 0 or _placements.has(slot_index)
	_recall_button.disabled = _status != "playing" or _placement_order.is_empty()
	_reset_button.disabled = _status != "playing" or _passed_galleries[_current_gallery]
	_next_button.disabled = _status != "gallery_clear"
	_restart_button.disabled = false


func _slot_letter(slot_index: int) -> String:
	match slot_index:
		0: return "A"
		1: return "B"
		2: return "C"
		_: return "D"

func _join_tags(tags: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for tag_value in tags:
		parts.append(str(tag_value).to_upper())
	return " / ".join(parts)

func get_title_text() -> String:
	return "KROLL // ARCHIVE CURATOR"

func get_gallery_count() -> int:
	return _rules.get_gallery_count() if _rules != null else 0

func get_card_count() -> int:
	return 6

func get_slot_count() -> int:
	return 4

func get_card_button_count() -> int:
	return _card_buttons.size()

func get_slot_button_count() -> int:
	return _slot_buttons.size()

func get_action_button_count() -> int:
	return _action_buttons.size()

func get_status() -> String:
	return _status

func get_total_score() -> int:
	return _total_score

func get_current_gallery_index() -> int:
	return _current_gallery

func get_placed_count() -> int:
	return _placements.size()

func get_slot_card(slot_index: int) -> int:
	return int(_placements.get(slot_index, -1))

func get_selected_card() -> int:
	return _selected_card

func get_gallery_score(index: int) -> int:
	if index < 0 or index >= _gallery_scores.size():
		return 0
	return _gallery_scores[index]
