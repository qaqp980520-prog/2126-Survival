extends SceneTree

const Rules = preload("res://rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Rules.get_level_count() == 3, "three authored stealth missions are available")
	for level in range(Rules.get_level_count()):
		var state: Dictionary = Rules.create_state(level)
		_expect(Rules.is_inside(state.get("start", Vector2i(-1, -1))), "mission start is inside the board")
		_expect(Rules.is_inside(state.get("exit", Vector2i(-1, -1))), "mission exit is inside the board")
		_expect(state.get("shards", []).size() == 3, "each mission contains three data shards")
		_expect(state.get("guards", []).size() >= 2, "each mission contains at least two patrols")
		_expect(not Rules.is_wall(state, state.get("start", Vector2i.ZERO)), "mission start is not blocked by a wall")
		_expect(not Rules.is_wall(state, state.get("exit", Vector2i.ZERO)), "mission exit is not blocked by a wall")
		for shard in state.get("shards", []):
			_expect(not Rules.is_wall(state, shard), "data shards are placed on walkable tiles")

	var blocked: Dictionary = Rules.create_state(0)
	_expect(not Rules.move_player(blocked, Vector2i.UP), "movement outside the board is rejected")
	_expect(int(blocked.get("turn", -1)) == 0, "blocked movement does not advance patrols")
	_expect(Rules.move_player(blocked, Vector2i.DOWN), "a valid move advances the player")
	_expect(blocked.get("player_pos") == Vector2i(0, 1), "valid movement changes the player tile")

	var wall_state: Dictionary = Rules.create_state(0)
	wall_state["player_pos"] = Vector2i(1, 0)
	_expect(not Rules.move_player(wall_state, Vector2i.RIGHT), "movement into a wall is rejected")

	var shard_state: Dictionary = Rules.create_state(0)
	shard_state["player_pos"] = Vector2i(0, 3)
	for guard in shard_state.get("guards", []):
		guard["disabled_turns"] = 10
	_expect(Rules.move_player(shard_state, Vector2i.RIGHT), "player can step onto a data shard")
	_expect(shard_state.get("collected_shards", []).has(Vector2i(1, 3)), "stepping onto a shard collects it")

	var rotation_state: Dictionary = Rules.create_state(0)
	var first_guard: Dictionary = rotation_state["guards"][0]
	var initial_facing: Vector2i = first_guard.get("facing", Vector2i.UP)
	_expect(Rules.wait_turn(rotation_state), "waiting advances one patrol turn")
	_expect(first_guard.get("facing") == Vector2i(-initial_facing.y, initial_facing.x), "active patrol rotates clockwise after a turn")

	var detection_state: Dictionary = Rules.create_state(0)
	var detection_guard: Dictionary = {
		"position": Vector2i(4, 4),
		"facing": Vector2i.UP,
		"disabled_turns": 0
	}
	detection_state["guards"] = [detection_guard]
	detection_state["walls"] = []
	detection_state["player_pos"] = Vector2i(5, 4)
	_expect(Rules.wait_turn(detection_state), "player can spend a turn while inside a patrol test fixture")
	_expect(str(detection_state.get("status", "")) == "detected", "rotating patrol sight detects the player")

	var decoy_state: Dictionary = Rules.create_state(0)
	decoy_state["guards"] = [{
		"position": Vector2i(2, 2),
		"facing": Vector2i.UP,
		"disabled_turns": 0
	}]
	decoy_state["player_pos"] = Vector2i(2, 3)
	_expect(Rules.use_decoy(decoy_state), "decoy distracts the nearest patrol within range")
	_expect(int(decoy_state.get("decoys", -1)) == 1, "successful decoy consumes exactly one charge")
	_expect(int(decoy_state["guards"][0].get("disabled_turns", -1)) == 1, "decoy keeps the patrol disabled after its deployment turn")
	var facing_while_disabled: Vector2i = decoy_state["guards"][0].get("facing", Vector2i.ZERO)
	_expect(Rules.wait_turn(decoy_state), "player can move while the patrol is distracted")
	_expect(int(decoy_state["guards"][0].get("disabled_turns", -1)) == 0, "decoy expires after two guard phases")
	_expect(decoy_state["guards"][0].get("facing") == facing_while_disabled, "distracted patrol does not rotate during its disabled phases")
	_expect(not Rules.use_decoy(decoy_state) or int(decoy_state.get("decoys", 0)) == 0, "decoy inventory never becomes negative")

	var extraction_state: Dictionary = Rules.create_state(0)
	extraction_state["guards"] = []
	extraction_state["player_pos"] = extraction_state["exit"]
	_expect(Rules.wait_turn(extraction_state), "player can wait at extraction")
	_expect(str(extraction_state.get("status", "")) == "active", "extraction stays locked while data shards are missing")
	extraction_state["collected_shards"] = extraction_state["shards"].duplicate()
	_expect(Rules.wait_turn(extraction_state), "final extraction turn is accepted")
	_expect(str(extraction_state.get("status", "")) == "complete", "all shards plus extraction completes the mission")

	var reset_state: Dictionary = Rules.create_state(1)
	reset_state["turn"] = 5
	reset_state["decoys"] = 0
	var reset_result: Dictionary = Rules.reset(reset_state)
	_expect(int(reset_result.get("level_index", -1)) == 1 and int(reset_result.get("turn", -1)) == 0, "reset restarts the current mission")
	_expect(int(reset_result.get("decoys", -1)) == Rules.MAX_DECOYS, "reset restores the mission decoy supply")
	_expect(int(Rules.next_level(reset_state).get("level_index", -1)) == 2, "next mission advances to the next authored map")

	if failures.is_empty():
		print("KROLL Shadow Courier rules tests passed.")
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
