extends SceneTree
const GameScene = preload("res://main.tscn")
const ECHO_PATHS: Array = [["right","right","right","right"],["down","down","down","right","right","up","up","up","right","right"],["down","right","right","right","right","up"]]
const PLAYER_PATHS: Array = [["down","down","down","down","right","right","right","right"],["down","down","down","right","right","up","up","right","right","down","down","down"],["down","down","down","right","right","right","right","down"]]
const EXIT_PATHS: Array = [["left","left","left","left"],["up","up","up","left","left","down","down","down","left","left"],["up","left","left","left","left","down"]]
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // CHRONO VAULT","game displays its title")
	_expect(game.call("get_level_count") == 3,"game builds three vaults")
	_expect(game.call("get_move_button_count") == 5,"game builds five touch movement buttons")
	_expect(game.call("get_action_button_count") == 3,"game builds three action buttons")
	_expect(game.call("get_control_button_count") == 8,"game exposes eight controls")
	for index in range(3):
		if index > 0:
			_expect(bool(game.call("advance_level")),"runtime advances to vault %d" % (index + 1))
		for action in ECHO_PATHS[index]:
			_expect(bool(game.call("step_action",str(action)),"runtime records echo route"))
		_expect(bool(game.call("commit_echo")),"runtime commits echo")
		_expect(bool(game.call("restart_level")),"runtime restarts and preserves echo")
		for action in PLAYER_PATHS[index]:
			_expect(bool(game.call("step_action",str(action)),"runtime executes player route"))
		_expect(bool(game.call("get_current_state").get("exit_unlocked",false),"runtime synchronizes both plates"))
		for action in EXIT_PATHS[index]:
			_expect(bool(game.call("step_action",str(action)),"runtime reaches exit"))
		_expect(str(game.call("get_current_state").get("status","")) == "passed","runtime clears vault %d" % (index + 1))
	_expect(bool(game.call("advance_level")),"runtime finalizes third vault")
	var final_state: Dictionary = game.call("get_current_state")
	_expect(str(final_state.get("status","")) == "campaign_complete","runtime completes campaign")
	_expect(game.call("get_restart_button_text") == "RESTART CAMPAIGN  ·  C","campaign completion changes the restart control into a campaign restart")
	_expect(int(final_state.get("total_score",0)) == 300,"runtime preserves campaign score")
	_expect(not bool(game.call("step_action","left")),"completed campaign rejects movement")
	_expect(bool(game.call("restart_campaign")),"runtime starts fresh campaign")
	_expect(int(game.call("get_current_state").get("campaign_score",-1)) == 0,"fresh campaign clears score")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Chrono Vault runtime smoke test passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
