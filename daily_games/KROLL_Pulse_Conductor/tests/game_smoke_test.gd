extends SceneTree
const GameScene = preload("res://main.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.call("get_title_text") == "KROLL // PULSE CONDUCTOR", "game displays its title")
	_expect(game.call("get_chart_count") == 3, "game initializes three original pulse charts")
	_expect(game.call("get_lane_button_count") == 4, "game builds four touch-capable lane buttons")
	_expect(game.call("get_action_button_count") == 3, "game builds restart, next and campaign controls")
	_expect(game.call("get_control_button_count") == 7, "game exposes seven total controls")
	var state: Dictionary = game.call("get_current_state")
	var notes: Array = state.get("notes",[])
	_expect(notes.size() == 16, "first shift creates sixteen notes")
	if not notes.is_empty():
		var first_note: Dictionary = notes[0]
		var first_time: float = float(first_note["time"])
		var first_lane: int = int(first_note["lane"])
		_expect(not bool(game.call("press_lane_at",(first_lane + 1) % 4,first_time)), "wrong lane input is ignored")
		_expect(bool(game.call("press_lane_at",first_lane,first_time)), "correct lane input hits the first pulse")
		_expect(not bool(game.call("press_lane_at",first_lane,first_time)), "the same pulse cannot be scored twice")
		for note_index in range(1,notes.size()):
			var note: Dictionary = notes[note_index]
			_expect(bool(game.call("press_lane_at",int(note["lane"]),float(note["time"]))), "runtime hits first-shift note %d" % note_index)
	_expect(str(game.call("get_current_state").get("status","")) == "passed", "runtime clears the first shift")
	_expect(not bool(game.call("restart_chart")), "runtime locks a passed shift against score farming")
	for chart_index in range(1,3):
		_expect(bool(game.call("advance_chart")), "runtime advances to shift %d" % (chart_index + 1))
		state = game.call("get_current_state")
		notes = state.get("notes",[])
		for note_index in range(notes.size()):
			var note: Dictionary = notes[note_index]
			_expect(bool(game.call("press_lane_at",int(note["lane"]),float(note["time"]))), "runtime hits shift %d note %d" % [chart_index + 1,note_index])
		_expect(str(game.call("get_current_state").get("status","")) == "passed", "runtime passes shift %d" % (chart_index + 1))
	_expect(bool(game.call("advance_chart")), "runtime finalizes the third shift")
	state = game.call("get_current_state")
	_expect(str(state.get("status","")) == "campaign_complete", "runtime completes the full campaign")
	_expect(int(state.get("total_score",0)) == 4800, "runtime preserves the full campaign score")
	_expect(not bool(game.call("press_lane_at",0,99.0)), "completed campaign rejects further input")
	_expect(bool(game.call("restart_campaign")), "runtime can start a fresh campaign")
	_expect(int(game.call("get_current_state").get("campaign_score",-1)) == 0, "fresh campaign clears the previous score")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("KROLL Pulse Conductor runtime smoke test passed.")
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
