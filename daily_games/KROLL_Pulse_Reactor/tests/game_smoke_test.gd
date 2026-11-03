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
	_expect(game.get_relay_state() == "playing", "scene starts in the first active relay")
	_expect(game.find_child("LaneButton_0", true, false) != null, "left lane has a visible input button")
	_expect(game.find_child("LaneButton_1", true, false) != null, "center lane has a visible input button")
	_expect(game.find_child("LaneButton_2", true, false) != null, "right lane has a visible input button")
	var relay: Dictionary = Rules.get_relay(0)
	var lanes: Array = relay["lanes"]
	var interval: float = Rules.beat_interval(int(relay["bpm"]))
	for beat in range(Rules.BEATS_PER_RELAY):
		var target_time: float = Rules.LEAD_IN_SECONDS + float(beat) * interval
		var result: Dictionary = game.submit_lane_hit(int(lanes[beat]), target_time)
		_expect(str(result.get("grade", "")) == "perfect", "authored lane can be hit on its exact beat")
	_expect(game.get_relay_state() == "complete", "twelve accurate inputs clear the relay")
	_expect(game.get_score() == 100, "first clear awards one hundred points")
	_expect(not bool(game.submit_lane_hit(0, 99.0).get("accepted", true)), "completed relay rejects additional scoring inputs")
	_expect(game.next_relay(), "cleared relay advances to the next relay")
	_expect(game.get_relay_index() == 1, "next relay index advances exactly once")
	game.restart_campaign()
	_expect(game.get_relay_index() == 0 and game.get_score() == 0, "campaign restart resets progress and score")
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("KROLL Pulse Reactor runtime smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
