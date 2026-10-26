extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	assert(Rules.judge_timing(0.0) == "PERFECT")
	assert(Rules.judge_timing(0.075) == "PERFECT")
	assert(Rules.judge_timing(0.10) == "GOOD")
	assert(Rules.judge_timing(-0.15) == "GOOD")
	assert(Rules.judge_timing(0.161) == "MISS")
	assert(Rules.score_for("PERFECT") == 300)
	assert(Rules.score_for("GOOD") == 100)
	assert(Rules.score_for("MISS") == 0)
	assert(Rules.lane_from_x(0.0) == 0)
	assert(Rules.lane_from_x(479.0) == 1)
	assert(Rules.lane_from_x(720.0) == 3)
	assert(Rules.lane_from_x(2000.0) == 3)
	assert(Rules.lane_from_x(-50.0) == 0)
	print("KROLL Pulse Rhythm rules tests passed.")
	quit(0)
