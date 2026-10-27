extends SceneTree

const Rules = preload("res://rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := Rules.create_state()
	_expect(int(state["credits"]) == 100, "mission starts with 100 credits")
	_expect(int(state["integrity"]) == 10, "core starts with ten integrity")
	_expect(Rules.place_relay(state, Vector2i(1, 2)), "relay can be placed on a free build tile")
	_expect(int(state["credits"]) == 60, "placing a relay deducts its exact cost")
	_expect(not Rules.place_relay(state, Vector2i(1, 2)), "duplicate relay placement is rejected")
	_expect(not Rules.place_relay(state, Vector2i(1, 3)), "relay cannot block the packet route")
	_expect(not Rules.place_relay(state, Vector2i(-1, 2)), "out-of-bounds placement is rejected")

	var poor := Rules.create_state()
	poor["credits"] = 39
	_expect(not Rules.place_relay(poor, Vector2i(0, 0)), "insufficient credits reject placement")
	_expect(int(poor["credits"]) == 39, "failed placement leaves credits unchanged")

	_expect(Rules.start_next_wave(state), "first wave can be started")
	_expect(int(state["wave"]) == 1 and str(state["phase"]) == "wave", "wave state advances exactly once")
	_expect(not Rules.start_next_wave(state), "a second wave cannot start while one is active")
	Rules.advance(state, Rules.SPAWN_INTERVAL + 0.02)
	_expect(state["packets"].size() > 0, "active wave spawns packets after its interval")

	var combat := Rules.create_state()
	combat["phase"] = "wave"
	combat["wave"] = 1
	combat["spawn_remaining"] = 0
	combat["packets"] = [{
		"id": 1, "path_index": 1, "progress": 0.0,
		"checks": 1, "max_checks": 1, "speed": 0.0
	}]
	combat["relays"] = [{"cell": Vector2i(1, 2), "scan_cooldown": 0.0, "scan_range": 2.6, "cleanse_power": 1}]
	Rules.advance(combat, 0.01)
	_expect(combat["packets"].is_empty(), "relay clears a corrupted packet in scan range")
	_expect(int(combat["cleaned"]) == 1, "clearing a packet increments the cleaned counter")
	_expect(int(combat["credits"]) == 100 + Rules.CLEAN_REWARD, "clearing a packet awards the documented credits")

	var escape := Rules.create_state()
	escape["phase"] = "wave"
	escape["wave"] = 1
	escape["spawn_remaining"] = 0
	escape["packets"] = [{
		"id": 9, "path_index": Rules.PATH_CELLS.size() - 1, "progress": 0.9,
		"checks": 3, "max_checks": 3, "speed": 1.0
	}]
	Rules.advance(escape, 0.2)
	_expect(int(escape["integrity"]) == 9 and int(escape["breaches"]) == 1, "packet reaching the endpoint reduces core integrity by one")
	_expect(str(escape["phase"]) == "build", "surviving an empty wave returns to build phase")

	var win := Rules.create_state()
	win["phase"] = "wave"
	win["wave"] = Rules.WAVE_COUNTS.size()
	win["spawn_remaining"] = 0
	win["packets"] = []
	Rules.advance(win, 0.01)
	_expect(str(win["phase"]) == "won", "clearing the final wave secures the core")
	_expect(not Rules.place_relay(win, Vector2i(0, 0)), "terminal mission rejects further placement")

	if failures.is_empty():
		print("KROLL Network Stabilizer rules tests passed.")
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
