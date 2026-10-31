extends RefCounted
## Deterministic side-scrolling platformer level and progression rules.

const MOVE_SPEED: float = 260.0
const GRAVITY: float = 980.0
const JUMP_SPEED: float = 480.0
const DASH_SPEED: float = 560.0
const DASH_DURATION: float = 0.18
const DASH_COOLDOWN: float = 0.85
const MAX_JUMPS: int = 2

const LEVELS: Array[Dictionary] = [
	{
		"id": "maintenance_shaft",
		"name": "MAINTENANCE SHAFT",
		"size": Vector2i(1280, 720),
		"spawn": Vector2(70, 590),
		"checkpoint_id": "midway",
		"checkpoint_position": Vector2(760, 400),
		"exit": Rect2(1160, 520, 72, 140),
		"platforms": [
			Rect2(0, 660, 1280, 60),
			Rect2(180, 560, 180, 24),
			Rect2(430, 470, 180, 24),
			Rect2(680, 390, 180, 24),
			Rect2(930, 480, 180, 24),
			Rect2(1110, 610, 120, 24)
		],
		"cores": [
			{"id": "core_a", "position": Vector2(260, 520)},
			{"id": "core_b", "position": Vector2(520, 430)},
			{"id": "core_c", "position": Vector2(790, 350)}
		],
		"hazards": [
			Rect2(370, 625, 130, 35),
			Rect2(760, 625, 140, 35),
			Rect2(980, 445, 70, 25)
		]
	},
	{
		"id": "reactor_scaffold",
		"name": "REACTOR SCAFFOLD",
		"size": Vector2i(1440, 720),
		"spawn": Vector2(70, 590),
		"checkpoint_id": "reactor_mid",
		"checkpoint_position": Vector2(870, 330),
		"exit": Rect2(1320, 500, 72, 160),
		"platforms": [
			Rect2(0, 660, 1440, 60),
			Rect2(150, 560, 150, 22),
			Rect2(360, 480, 150, 22),
			Rect2(570, 390, 170, 22),
			Rect2(790, 300, 160, 22),
			Rect2(1010, 390, 150, 22),
			Rect2(1210, 480, 170, 22)
		],
		"cores": [
			{"id": "core_a", "position": Vector2(220, 520)},
			{"id": "core_b", "position": Vector2(650, 350)},
			{"id": "core_c", "position": Vector2(1080, 350)}
		],
		"hazards": [
			Rect2(310, 625, 100, 35),
			Rect2(740, 625, 120, 35),
			Rect2(1160, 625, 100, 35),
			Rect2(870, 275, 70, 20)
		]
	},
	{
		"id": "signal_tower",
		"name": "SIGNAL TOWER",
		"size": Vector2i(1600, 720),
		"spawn": Vector2(70, 590),
		"checkpoint_id": "upper_tower",
		"checkpoint_position": Vector2(940, 270),
		"exit": Rect2(1490, 430, 72, 230),
		"platforms": [
			Rect2(0, 660, 1600, 60),
			Rect2(170, 560, 160, 22),
			Rect2(390, 470, 160, 22),
			Rect2(610, 380, 160, 22),
			Rect2(830, 290, 180, 22),
			Rect2(1060, 380, 150, 22),
			Rect2(1270, 470, 160, 22),
			Rect2(1450, 560, 120, 22)
		],
		"cores": [
			{"id": "core_a", "position": Vector2(240, 520)},
			{"id": "core_b", "position": Vector2(900, 250)},
			{"id": "core_c", "position": Vector2(1350, 430)}
		],
		"hazards": [
			Rect2(330, 625, 110, 35),
			Rect2(770, 625, 130, 35),
			Rect2(1210, 625, 110, 35),
			Rect2(1080, 355, 90, 22)
		]
	}
]

static func level_count() -> int:
	return LEVELS.size()

static func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)].duplicate(true)

static func new_run(level_index: int = 0) -> Dictionary:
	var safe_index: int = clampi(level_index, 0, LEVELS.size() - 1)
	var level: Dictionary = get_level(safe_index)
	return {
		"level_index": safe_index,
		"level_id": str(level["id"]),
		"collected": [],
		"checkpoint_id": "start",
		"deaths": 0,
		"status": "playing"
	}

static func collect_core(state: Dictionary, core_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "playing":
		return next
	var level: Dictionary = get_level(int(next.get("level_index", 0)))
	var exists: bool = false
	for core in level.get("cores", []):
		if str(core.get("id", "")) == core_id:
			exists = true
			break
	if not exists:
		return next
	var collected: Array = next.get("collected", []).duplicate()
	if not collected.has(core_id):
		collected.append(core_id)
	next["collected"] = collected
	return next

static func activate_checkpoint(state: Dictionary, checkpoint_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) != "playing":
		return next
	var level: Dictionary = get_level(int(next.get("level_index", 0)))
	if str(level.get("checkpoint_id", "")) == checkpoint_id:
		next["checkpoint_id"] = checkpoint_id
	return next

static func record_hazard(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("status", "")) == "playing":
		next["deaths"] = int(next.get("deaths", 0)) + 1
	return next

static func required_core_count(level_index: int) -> int:
	return get_level(level_index).get("cores", []).size()

static func can_exit(state: Dictionary) -> bool:
	if str(state.get("status", "")) != "playing":
		return false
	return (state.get("collected", []) as Array).size() >= required_core_count(int(state.get("level_index", 0)))

static func complete_level(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if can_exit(next):
		next["status"] = "complete"
	return next

static func next_level(state: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "complete":
		return state.duplicate(true)
	return new_run((int(state.get("level_index", 0)) + 1) % LEVELS.size())

static func is_valid_level(level_index: int) -> bool:
	if level_index < 0 or level_index >= LEVELS.size():
		return false
	var level: Dictionary = get_level(level_index)
	var size: Vector2i = level.get("size", Vector2i.ZERO)
	var spawn: Vector2 = level.get("spawn", Vector2(-1, -1))
	if size.x <= 0 or size.y <= 0:
		return false
	if spawn.x < 0.0 or spawn.y < 0.0 or spawn.x >= float(size.x) or spawn.y >= float(size.y):
		return false
	var platforms: Array = level.get("platforms", [])
	if platforms.is_empty():
		return false
	for platform in platforms:
		if not (platform is Rect2):
			return false
		var rect: Rect2 = platform
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return false
	var core_ids: Dictionary = {}
	var cores: Array = level.get("cores", [])
	if cores.size() < 3:
		return false
	for core in cores:
		if not (core is Dictionary):
			return false
		var core_id: String = str(core.get("id", ""))
		var position: Vector2 = core.get("position", Vector2(-1, -1))
		if core_id.is_empty() or core_ids.has(core_id):
			return false
		if position.x < 0.0 or position.y < 0.0 or position.x >= float(size.x) or position.y >= float(size.y):
			return false
		core_ids[core_id] = true
	var exit_rect: Rect2 = level.get("exit", Rect2())
	return exit_rect.size.x > 0.0 and exit_rect.size.y > 0.0 and not str(level.get("checkpoint_id", "")).is_empty()
