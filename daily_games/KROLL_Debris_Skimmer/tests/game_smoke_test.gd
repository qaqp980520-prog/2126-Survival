extends SceneTree

const GameScene = preload("res://main.tscn")
const Rules = preload("res://rules.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.get_sector_index() == 0, "campaign starts in sector one")
	_expect(game.find_child("Control_Thrust", true, false) != null, "touch thrust control exists")
	_expect(game.find_child("Control_TurnLeft", true, false) != null, "touch steering control exists")
	_expect(game.find_child("Control_Tractor", true, false) != null, "touch tractor control exists")
	_expect(game.find_child("Control_Dock", true, false) != null, "touch docking control exists")
	_expect(game.find_child("Control_Retry", true, false) != null, "touch retry control exists")
	_expect(game.find_child("Control_Next", true, false) != null, "touch next-sector control exists")
	_expect(game.find_child("Control_Campaign", true, false) != null, "touch campaign-reset control exists")
	var next_button: Button = game.find_child("Control_Next", true, false)
	var retry_button: Button = game.find_child("Control_Retry", true, false)
	var campaign_button: Button = game.find_child("Control_Campaign", true, false)
	_expect(game.get_hull() == 3, "ship starts with three hull points")
	for sector in range(Rules.sector_count()):
		var target: int = game.get_sector_target()
		var positions: Array[Vector2] = game.get_remaining_cargo_positions()
		_expect(positions.size() >= target, "sector has enough salvage targets")
		for index in range(target):
			game.ship_position = positions[index]
			_expect(game.activate_tractor(), "tractor secures an in-range salvage crate")
		_expect(game.get_carried_count() == target, "cargo is carried before docking")
		game.ship_position = Rules.DOCK_POSITION
		_expect(game.dock_cargo(), "dock accepts carried cargo inside its radius")
		_expect(game.get_delivered_count() == target, "delivery count reaches the sector quota")
		_expect(game.get_score() == (sector + 1) * 100, "sector clear awards one hundred points once")
		if sector == 0:
			retry_button.pressed.emit()
			_expect(game.get_score() == 100 and game.get_delivered_count() == 0, "touch retry resets the sector without erasing earned score")
			var retry_positions: Array[Vector2] = game.get_remaining_cargo_positions()
			for index in range(target):
				game.ship_position = retry_positions[index]
				game.activate_tractor()
			game.ship_position = Rules.DOCK_POSITION
			game.dock_cargo()
			_expect(game.get_score() == 100, "replaying a cleared sector cannot duplicate its reward")
		if sector < Rules.sector_count() - 1:
			next_button.pressed.emit()
			_expect(game.get_sector_index() == sector + 1, "touch next button advances exactly one sector")
	_expect(game.is_campaign_complete(), "final sector completes the campaign")
	_expect(game.get_score() == 300, "campaign score is capped at 300")
	campaign_button.pressed.emit()
	_expect(game.get_score() == 0 and game.get_sector_index() == 0, "touch campaign reset clears progress")
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("KROLL Debris Skimmer runtime smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)
