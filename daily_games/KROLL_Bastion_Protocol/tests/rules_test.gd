extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := Rules.create_state()
	_expect(int(state["credits"]) == 100, "mission starts with 100 credits")
	_expect(int(state["lives"]) == 10, "core starts with ten lives")
	_expect(Rules.place_tower(state, Vector2i(1, 2)), "turret can be placed on a free build tile")
	_expect(int(state["credits"]) == 60, "placing a turret deducts its exact cost")
	_expect(not Rules.place_tower(state, Vector2i(1, 2)), "duplicate turret placement is rejected")
	_expect(not Rules.place_tower(state, Vector2i(1, 3)), "turret cannot block the enemy route")
	_expect(not Rules.place_tower(state, Vector2i(-1, 2)), "out-of-bounds placement is rejected")

	var poor := Rules.create_state()
	poor["credits"] = 39
	_expect(not Rules.place_tower(poor, Vector2i(0, 0)), "insufficient credits reject placement")
	_expect(int(poor["credits"]) == 39, "failed placement leaves credits unchanged")

	_expect(Rules.start_next_wave(state), "first wave can be started")
	_expect(int(state["wave"]) == 1 and str(state["phase"]) == "wave", "wave state advances exactly once")
	_expect(not Rules.start_next_wave(state), "a second wave cannot start while one is active")
	Rules.advance(state, Rules.SPAWN_INTERVAL + 0.02)
	_expect(state["enemies"].size() > 0, "active wave spawns enemies after its interval")

	var combat := Rules.create_state()
	combat["phase"] = "wave"
	combat["wave"] = 1
	combat["spawn_remaining"] = 0
	combat["enemies"] = [{
		"id": 1, "path_index": 1, "progress": 0.0,
		"hp": 1, "max_hp": 1, "speed": 0.0
	}]
	combat["towers"] = [{"cell": Vector2i(1, 2), "cooldown": 0.0, "range": 2.6, "damage": 1}]
	Rules.advance(combat, 0.01)
	_expect(combat["enemies"].is_empty(), "turret removes an enemy in range")
	_expect(int(combat["kills"]) == 1, "turret kill increments kill counter")
	_expect(int(combat["credits"]) == 100 + Rules.KILL_REWARD, "enemy kill awards the documented credits")

	var escape := Rules.create_state()
	escape["phase"] = "wave"
	escape["wave"] = 1
	escape["spawn_remaining"] = 0
	escape["enemies"] = [{
		"id": 9, "path_index": Rules.PATH_CELLS.size() - 1, "progress": 0.9,
		"hp": 3, "max_hp": 3, "speed": 1.0
	}]
	Rules.advance(escape, 0.2)
	_expect(int(escape["lives"]) == 9 and int(escape["escaped"]) == 1, "enemy reaching the end costs one core life")
	_expect(str(escape["phase"]) == "build", "surviving an empty wave returns to build phase")

	var win := Rules.create_state()
	win["phase"] = "wave"
	win["wave"] = Rules.WAVE_COUNTS.size()
	win["spawn_remaining"] = 0
	win["enemies"] = []
	Rules.advance(win, 0.01)
	_expect(str(win["phase"]) == "won", "clearing the final wave secures the core")
	_expect(not Rules.place_tower(win, Vector2i(0, 0)), "terminal mission rejects further placement")

	if failures.is_empty():
		print("KROLL Bastion Protocol rules tests passed.")
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
