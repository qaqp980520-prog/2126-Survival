extends SceneTree
const RulesScript = preload("res://rules.gd")
const ECHO_PATHS: Array = [["right","right","right","right"],["down","down","down","right","right","up","up","up","right","right"],["down","right","right","right","right","up"]]
const PLAYER_PATHS: Array = [["down","down","down","down","right","right","right","right"],["down","down","down","right","right","up","up","right","right","down","down","down"],["down","down","down","right","right","right","right","down"]]
const EXIT_PATHS: Array = [["left","left","left","left"],["up","up","up","left","left","down","down","down","left","left"],["up","left","left","left","left","down"]]
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var rules = RulesScript.new()
	_expect(rules.get_level_count() == 3,"three time-loop vaults are available")
	var boundary: Dictionary = rules.step_action(rules.create_state(0),"up")
	_expect(bool(boundary.get("ok",false)) and not bool(boundary.get("player_moved",true)),"boundary movement is blocked")
	_expect(not bool(rules.step_action(rules.create_state(0),"teleport").get("ok",true)),"unknown actions are rejected")
	_expect(not bool(rules.commit_echo(rules.create_state(0)).get("ok",true)),"echo cannot be recorded before reaching plate A")
	var campaign: Dictionary = rules.create_state(0)
	for index in range(3):
		var state: Dictionary = campaign.duplicate(true)
		_expect(int(state.get("level_index",-1)) == index,"campaign carries forward to vault %d" % (index + 1))
		for action in ECHO_PATHS[index]:
			var step: Dictionary = rules.step_action(state,str(action))
			_expect(bool(step.get("ok",false)),"vault %d records echo action" % (index + 1))
			if bool(step.get("ok",false)):
				state = step["state"]
		var level: Dictionary = rules.get_level_definition(index)
		_expect(state.get("player_pos",Vector2i.ZERO) == level["echo_plate"],"vault %d reaches echo plate A" % (index + 1))
		var committed: Dictionary = rules.commit_echo(state)
		_expect(bool(committed.get("ok",false)),"vault %d commits echo route" % (index + 1))
		if not bool(committed.get("ok",false)):
			break
		state = committed["state"]
		_expect(bool(state.get("echo_active",false)) and state.get("player_pos",Vector2i.ZERO) == level["start"],"vault %d rewinds and arms echo" % (index + 1))
		for action in ECHO_PATHS[index]:
			var echo_replay_step: Dictionary = rules.step_action(state,str(action))
			if bool(echo_replay_step.get("ok",false)):
				state = echo_replay_step["state"]
		_expect(state.get("player_pos",Vector2i.ZERO) == level["echo_plate"],"vault %d can revisit A while echo is active" % (index + 1))
		var second_commit: Dictionary = rules.commit_echo(state)
		_expect(not bool(second_commit.get("ok",true)) and str(second_commit.get("reason","")) == "echo_already_active","vault %d cannot overwrite an active echo" % (index + 1))
		var retry: Dictionary = rules.restart_level(state)
		_expect(bool(retry.get("ok",false)) and retry["state"].get("echo_script",[]).size() == ECHO_PATHS[index].size(),"vault %d retry preserves echo script" % (index + 1))
		state = retry["state"]
		for action in PLAYER_PATHS[index]:
			var step: Dictionary = rules.step_action(state,str(action))
			if bool(step.get("ok",false)):
				state = step["state"]
		_expect(state.get("echo_pos",Vector2i.ZERO) == level["echo_plate"],"vault %d echo holds plate A" % (index + 1))
		_expect(state.get("player_pos",Vector2i.ZERO) == level["player_plate"],"vault %d player reaches plate B" % (index + 1))
		_expect(bool(state.get("exit_unlocked",false)),"vault %d synchronizes both plates" % (index + 1))
		for action in EXIT_PATHS[index]:
			var step: Dictionary = rules.step_action(state,str(action))
			if bool(step.get("ok",false)):
				state = step["state"]
		_expect(str(state.get("status","")) == "passed","vault %d reaches exit after synchronization" % (index + 1))
		_expect(not bool(rules.restart_level(state).get("ok",true)),"passed vault cannot be replayed for score farming")
		var advanced: Dictionary = rules.advance_level(state)
		_expect(bool(advanced.get("ok",false)),"vault %d advances exactly once" % (index + 1))
		if bool(advanced.get("ok",false)):
			campaign = advanced["state"]
	_expect(str(campaign.get("status","")) == "campaign_complete","all vaults complete the campaign")
	_expect(int(campaign.get("total_score",0)) == 300,"three vaults award three hundred points")
	_expect(not bool(rules.advance_level(campaign).get("ok",true)),"completed campaign cannot advance again")
	_expect(int(rules.restart_campaign().get("campaign_score",-1)) == 0,"fresh campaign clears previous score")
	if failures.is_empty():
		print("KROLL Chrono Vault rules tests passed.")
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
