extends SceneTree

const GameScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = GameScene.instantiate() as Control
	_check(game != null, "auction scene instantiates")
	root.add_child(game)
	await process_frame
	_check(game.find_child("InspectButton", true, false) != null, "inspection control exists")
	_check(game.find_child("StandardBidButton", true, false) != null, "standard bid control exists")
	_check(game.find_child("PassButton", true, false) != null, "pass control exists")
	_check(game.has_method("perform_action") and game.has_method("get_game_state"), "game exposes testable action and state APIs")
	var plan: Array[String] = [
		"inspect", "bid_standard",
		"pass",
		"bid_standard",
		"inspect", "bid_standard",
		"pass",
		"bid_standard",
		"inspect", "bid_standard",
		"pass",
		"bid_standard"
	]
	for action in plan:
		_check(bool(game.call("perform_action", action)), "runtime accepts campaign action: " + action)
	var state: Dictionary = game.call("get_game_state")
	_check(str(state["status"]) == "won", "runtime completes the three-market campaign")
	_check(int(state["credits"]) == 204 and int(state["wins"]) == 6, "runtime result matches rules model")
	_check(int(game.call("get_campaign_score")) == 104, "campaign score reports net credits once")
	game.call("restart_campaign")
	state = game.call("get_game_state")
	_check(str(state["status"]) == "active" and int(state["lot_index"]) == 0, "restart returns to first lot")
	_check(int(state["credits"]) == 100 and int(state["wins"]) == 0, "restart restores initial bankroll and wins")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Salvage Auction runtime smoke test passed.")
		quit(0)
	else:
		push_error("KROLL Salvage Auction runtime smoke failures: " + str(failures))
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
