extends Control

const Rules = preload("res://rules.gd")
const BACKGROUND := Color("#07131d")
const ACCENT := Color("#77e8df")
const TEXT_COLOR := Color("#dcebf0")
const WARN := Color("#f3c46d")

var blueprint_index: int = 0
var state: Dictionary = {}
var _status_label: Label
var _budget_label: Label
var _message_label: Label
var _deck_buttons: Array[Button] = []
var _brace_buttons: Array[Button] = []
var _test_button: Button

func _ready() -> void:
	_build_ui()
	_start_blueprint(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_T:
			_run_load_test()
		KEY_R:
			_start_blueprint(blueprint_index)
		KEY_N:
			_start_blueprint(blueprint_index + 1)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 22.0
	layout.offset_top = 20.0
	layout.offset_right = -22.0
	layout.offset_bottom = -20.0
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var title := Label.new()
	title.text = "KROLL // SPAN ENGINEER"
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", ACCENT)
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "DESIGN A FIVE-SPAN BRIDGE. CART LOAD = 3. BUDGET = 12. TEST, LEARN, REBUILD."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#9bb9c6"))
	layout.add_child(subtitle)
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", TEXT_COLOR)
	layout.add_child(_status_label)
	_budget_label = Label.new()
	_budget_label.name = "Budget"
	_budget_label.add_theme_font_size_override("font_size", 16)
	_budget_label.add_theme_color_override("font_color", WARN)
	layout.add_child(_budget_label)
	var bridge := HBoxContainer.new()
	bridge.name = "SpanCards"
	bridge.add_theme_constant_override("separation", 8)
	layout.add_child(bridge)
	for span in range(Rules.SPAN_COUNT):
		var card := VBoxContainer.new()
		card.name = "SpanCard%d" % span
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 8)
		bridge.add_child(card)
		var title_label := Label.new()
		title_label.text = "SPAN %d" % (span + 1)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", ACCENT)
		card.add_child(title_label)
		var deck_button := Button.new()
		deck_button.name = "DeckButton%d" % span
		deck_button.custom_minimum_size = Vector2(0, 104)
		deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_button.focus_mode = Control.FOCUS_NONE
		deck_button.pressed.connect(_on_deck_pressed.bind(span))
		card.add_child(deck_button)
		_deck_buttons.append(deck_button)
		var brace_button := Button.new()
		brace_button.name = "BraceButton%d" % span
		brace_button.custom_minimum_size = Vector2(0, 76)
		brace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brace_button.focus_mode = Control.FOCUS_NONE
		brace_button.pressed.connect(_on_brace_pressed.bind(span))
		card.add_child(brace_button)
		_brace_buttons.append(brace_button)
	_message_label = Label.new()
	_message_label.name = "Message"
	_message_label.custom_minimum_size = Vector2(0, 80)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", TEXT_COLOR)
	layout.add_child(_message_label)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	_test_button = Button.new()
	_test_button.name = "LoadTestButton"
	_test_button.text = "RUN LOAD TEST (T)"
	_test_button.custom_minimum_size = Vector2(0, 52)
	_test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_button.pressed.connect(_run_load_test)
	actions.add_child(_test_button)
	_add_action_button(actions, "RESET (R)", func(): _start_blueprint(blueprint_index))
	_add_action_button(actions, "NEXT BLUEPRINT (N)", func(): _start_blueprint(blueprint_index + 1))
	var help := Label.new()
	help.text = "Standard deck: capacity 2, cost 1. Reinforced deck: capacity 3, cost 3. An anchored brace adds capacity 1, cost 1. Only spans marked with anchors can be braced."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#9bb9c6"))
	layout.add_child(help)

func _add_action_button(parent: HBoxContainer, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)

func _start_blueprint(index: int) -> void:
	blueprint_index = posmod(index, Rules.SEEDS.size())
	state = Rules.new_blueprint(Rules.SEEDS[blueprint_index])
	_render()

func _on_deck_pressed(span: int) -> void:
	var decks: Array = state.get("decks", [])
	if span < 0 or span >= decks.size():
		return
	var next_kind: String
	match str(decks[span]):
		Rules.DECK_EMPTY:
			next_kind = Rules.DECK_STANDARD
		Rules.DECK_STANDARD:
			next_kind = Rules.DECK_REINFORCED
		_:
			next_kind = Rules.DECK_EMPTY
	_set_deck_kind(span, next_kind)

func _set_deck_kind(span: int, deck_kind: String) -> void:
	_apply_action(Rules.set_deck(state, span, deck_kind))

func _on_brace_pressed(span: int) -> void:
	_toggle_brace(span)

func _toggle_brace(span: int) -> void:
	_apply_action(Rules.toggle_brace(state, span))

func _run_load_test() -> void:
	_apply_action(Rules.run_load_test(state))

func _apply_action(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_message_label.text = "ACTION BLOCKED: " + str(result.get("reason", "unknown"))
		return
	state = result.get("state", state)
	_render()

func _render() -> void:
	if state.is_empty() or _status_label == null:
		return
	var terminal: bool = str(state.get("status", "building")) == "won"
	_status_label.text = "BLUEPRINT %d  |  %s  |  LOAD %d" % [blueprint_index + 1, str(state.get("status", "building")).to_upper(), Rules.CART_LOAD]
	_budget_label.text = "MATERIAL BUDGET: %d / %d USED   |   TESTS: %d" % [int(state.get("budget_used", 0)), Rules.BUDGET, int(state.get("test_count", 0))]
	_message_label.text = str(state.get("message", ""))
	var anchors: Array = state.get("anchor_spans", [])
	var decks: Array = state.get("decks", [])
	var braces: Array = state.get("braces", [])
	for span in range(Rules.SPAN_COUNT):
		var deck_kind: String = str(decks[span])
		var next_kind: String = Rules.DECK_STANDARD if deck_kind == Rules.DECK_EMPTY else (Rules.DECK_REINFORCED if deck_kind == Rules.DECK_STANDARD else Rules.DECK_EMPTY)
		var capacity: int = Rules.capacity_for_span(state, span)
		_deck_buttons[span].text = "%s\nCAPACITY %d\nTap: %s" % [deck_kind.to_upper(), capacity, next_kind.to_upper()]
		_deck_buttons[span].disabled = terminal
		_brace_buttons[span].text = ("ANCHOR\n" if anchors.has(span) else "NO ANCHOR\n") + ("BRACE ON" if bool(braces[span]) else "BRACE OFF")
		_brace_buttons[span].disabled = terminal or not anchors.has(span) or deck_kind == Rules.DECK_EMPTY
	_test_button.disabled = terminal
