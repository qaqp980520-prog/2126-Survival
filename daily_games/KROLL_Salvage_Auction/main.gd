extends Control

const Rules = preload("res://rules.gd")

var _state: Dictionary = {}
var _message: String = "Inspect one lot per market, then bid carefully."
var _buttons: Dictionary = {}
var _title_label: Label
var _round_label: Label
var _lot_label: Label
var _estimate_label: Label
var _credits_label: Label
var _scan_label: Label
var _status_label: Label
var _message_label: Label

func _ready() -> void:
	_build_ui()
	_state = Rules.new_state()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			perform_action("inspect")
		KEY_2:
			perform_action("bid_low")
		KEY_3:
			perform_action("bid_standard")
		KEY_4:
			perform_action("bid_aggressive")
		KEY_5:
			perform_action("pass")
		KEY_R:
			restart_campaign()

func perform_action(action: String) -> bool:
	var result: Dictionary = Rules.perform_action(_state, action)
	_state = result.get("state", _state)
	_message = _message_for_result(result)
	_update_ui()
	return bool(result.get("accepted", false))

func restart_campaign() -> void:
	_state = Rules.new_state()
	_message = "New auction opened. Inspect strategically."
	_update_ui()

func get_game_state() -> Dictionary:
	return _state.duplicate(true)

func get_campaign_score() -> int:
	return maxi(0, int(_state.get("credits", Rules.INITIAL_CREDITS)) - Rules.INITIAL_CREDITS)

func _message_for_result(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if not bool(result.get("accepted", false)):
		match reason:
			"no_scan_tokens":
				return "No inspection token remains this market."
			"lot_already_inspected":
				return "This lot has already been inspected."
			"insufficient_credits":
				return "Insufficient credits for that bid."
			"campaign_finished":
				return "The campaign is finished. Press R to restart."
			_:
				return "Action rejected: " + reason
	if reason == "inspected":
		return "Inspection complete. The true resale value is now visible."
	if reason == "passed":
		return "Lot passed. No credits spent."
	if reason == "won":
		return "Lot won. The salvage value has been added to your balance."
	if reason == "outbid":
		return "Rival bidder won this lot. Your credits are unchanged."
	return "Action accepted."

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.075)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "GameTitle"
	_title_label.text = "KROLL  /  SALVAGE AUCTION"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	column.add_child(_title_label)

	_round_label = _make_label("MarketStatus", 18, Color(0.9, 0.94, 1.0))
	column.add_child(_round_label)
	_lot_label = _make_label("LotTitle", 25, Color(1.0, 0.83, 0.48))
	column.add_child(_lot_label)
	_estimate_label = _make_label("LotEstimate", 17, Color(0.72, 0.83, 0.92))
	column.add_child(_estimate_label)
	_credits_label = _make_label("CreditsStatus", 19, Color(0.5, 0.95, 0.72))
	column.add_child(_credits_label)
	_scan_label = _make_label("InspectionStatus", 16, Color(0.76, 0.84, 0.9))
	column.add_child(_scan_label)

	var action_row := HBoxContainer.new()
	action_row.name = "AuctionActions"
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)
	_add_button(action_row, "InspectButton", "INSPECT  [1]", "inspect")
	_add_button(action_row, "LowBidButton", "LOW BID  [2]", "bid_low")
	_add_button(action_row, "StandardBidButton", "STANDARD  [3]", "bid_standard")
	_add_button(action_row, "AggressiveBidButton", "AGGRESSIVE  [4]", "bid_aggressive")
	_add_button(action_row, "PassButton", "PASS  [5]", "pass")

	_message_label = _make_label("AuctionMessage", 16, Color(0.86, 0.9, 0.96))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)

	_status_label = _make_label("CampaignResult", 20, Color(0.5, 0.95, 0.72))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

	var footer := HBoxContainer.new()
	footer.name = "FooterActions"
	column.add_child(footer)
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "RESTART CAMPAIGN  [R]"
	restart.custom_minimum_size = Vector2(230, 48)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(restart_campaign)
	footer.add_child(restart)

func _make_label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_button(parent: Node, button_name: String, text_value: String, action: String) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = text_value
	button.custom_minimum_size = Vector2(150, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: perform_action(action))
	parent.add_child(button)
	_buttons[action] = button

func _update_ui() -> void:
	var lot_index: int = int(_state.get("lot_index", 0))
	var credits: int = int(_state.get("credits", Rules.INITIAL_CREDITS))
	var wins: int = int(_state.get("wins", 0))
	var status: String = str(_state.get("status", "active"))
	_credits_label.text = "CREDITS  %d     WINS  %d / %d     NET  %+d" % [credits, wins, Rules.TARGET_WINS, credits - Rules.INITIAL_CREDITS]
	_message_label.text = _message
	if status == "active" and lot_index < Rules.lot_count():
		var lot: Dictionary = Rules.lot_at(lot_index)
		var round_number: int = floori(float(lot_index) / 3.0) + 1
		_round_label.text = "MARKET %d / 3     LOT %d / %d" % [round_number, lot_index + 1, Rules.lot_count()]
		_lot_label.text = str(lot["name"])
		_estimate_label.text = "RESERVE %d     ESTIMATED VALUE %d–%d" % [int(lot["reserve"]), int(lot["estimate_min"]), int(lot["estimate_max"])]
		var inspection_value: int = int(_state.get("inspection_value", -1))
		if inspection_value >= 0:
			_estimate_label.text += "     VERIFIED VALUE %d" % inspection_value
		_scan_label.text = "INSPECTION TOKENS  %d     ONE SCAN PER MARKET" % int(_state.get("scan_tokens", 0))
		_status_label.text = "OBJECTIVE: Finish with at least %d credits and %d won lots." % [Rules.TARGET_CREDITS, Rules.TARGET_WINS]
	else:
		_round_label.text = "AUCTION CAMPAIGN COMPLETE"
		_lot_label.text = "FINAL BALANCE  %d CREDITS" % credits
		_estimate_label.text = "NET RESULT  %+d     LOTS WON  %d" % [credits - Rules.INITIAL_CREDITS, wins]
		_scan_label.text = "ALL NINE LOTS RESOLVED"
		_status_label.text = "CONTRACT SECURED" if status == "won" else "CONTRACT MISSED — PRESS R TO RETRY"
	for action in _buttons.keys():
		var button: Button = _buttons[action]
		button.disabled = status != "active"
	if status == "active" and lot_index < Rules.lot_count():
		var lot_now: Dictionary = Rules.lot_at(lot_index)
		_buttons["inspect"].disabled = int(_state.get("scan_tokens", 0)) <= 0 or bool(_state.get("inspected", false))
		_buttons["bid_low"].disabled = int(lot_now["reserve"]) > credits
		_buttons["bid_standard"].disabled = Rules.bid_price(lot_now, "standard") > credits
		_buttons["bid_aggressive"].disabled = Rules.bid_price(lot_now, "aggressive") > credits

func _unhandled_key_input(_event: InputEvent) -> void:
	pass
