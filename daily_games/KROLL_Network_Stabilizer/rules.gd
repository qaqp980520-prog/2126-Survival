extends RefCounted

const BOARD_COLUMNS := 10
const BOARD_ROWS := 8
const RELAY_COST := 40
const SPAWN_INTERVAL := 0.72
const SCAN_RANGE := 2.6
const SCAN_COOLDOWN := 0.68
const CLEAN_REWARD := 12
const WAVE_COUNTS: Array[int] = [8, 10, 12]
const PATH_CELLS: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(3, 2), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1),
	Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
	Vector2i(7, 4), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)
]

static func create_state() -> Dictionary:
	return {
		"credits": 100,
		"integrity": 10,
		"wave": 0,
		"phase": "build",
		"spawn_remaining": 0,
		"spawn_clock": 0.0,
		"next_packet_id": 1,
		"cleaned": 0,
		"breaches": 0,
		"relays": [],
		"packets": []
	}

static func is_path_cell(cell: Vector2i) -> bool:
	return PATH_CELLS.has(cell)

static func can_place_relay(state: Dictionary, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_COLUMNS or cell.y >= BOARD_ROWS:
		return false
	if str(state.get("phase", "lost")) in ["won", "lost"]:
		return false
	if is_path_cell(cell) or int(state.get("credits", 0)) < RELAY_COST:
		return false
	for relay_value in state.get("relays", []):
		var relay: Dictionary = relay_value
		if relay.get("cell", Vector2i(-1, -1)) == cell:
			return false
	return true

static func place_relay(state: Dictionary, cell: Vector2i) -> bool:
	if not can_place_relay(state, cell):
		return false
	state["credits"] = int(state["credits"]) - RELAY_COST
	state["relays"].append({
		"cell": cell,
		"scan_cooldown": 0.0,
		"scan_range": SCAN_RANGE,
		"cleanse_power": 1
	})
	return true

static func start_next_wave(state: Dictionary) -> bool:
	if str(state.get("phase", "")) != "build" or int(state.get("wave", 0)) >= WAVE_COUNTS.size():
		return false
	state["wave"] = int(state["wave"]) + 1
	state["spawn_remaining"] = WAVE_COUNTS[int(state["wave"]) - 1]
	state["spawn_clock"] = 0.0
	state["phase"] = "wave"
	return true

static func packet_grid_position(packet: Dictionary) -> Vector2:
	var path_index: int = clampi(int(packet.get("path_index", 0)), 0, PATH_CELLS.size() - 1)
	var current: Vector2 = Vector2(PATH_CELLS[path_index])
	if path_index >= PATH_CELLS.size() - 1:
		return current
	var next_cell: Vector2 = Vector2(PATH_CELLS[path_index + 1])
	return current.lerp(next_cell, clampf(float(packet.get("progress", 0.0)), 0.0, 1.0))

static func advance(state: Dictionary, delta: float) -> void:
	if delta <= 0.0 or str(state.get("phase", "")) in ["won", "lost"]:
		return
	if str(state.get("phase", "")) == "wave":
		state["spawn_clock"] = float(state["spawn_clock"]) + delta
		while int(state["spawn_remaining"]) > 0 and float(state["spawn_clock"]) >= SPAWN_INTERVAL:
			state["spawn_clock"] = float(state["spawn_clock"]) - SPAWN_INTERVAL
			var wave_number: int = int(state["wave"])
			var packet_checks: int = wave_number + 1
			state["packets"].append({
				"id": int(state["next_packet_id"]),
				"path_index": 0,
				"progress": 0.0,
				"checks": packet_checks,
				"max_checks": packet_checks,
				"speed": 0.95 + float(wave_number) * 0.10
			})
			state["next_packet_id"] = int(state["next_packet_id"]) + 1
			state["spawn_remaining"] = int(state["spawn_remaining"]) - 1

		var packets: Array = state["packets"]
		for packet_index in range(packets.size() - 1, -1, -1):
			var packet: Dictionary = packets[packet_index]
			packet["progress"] = float(packet["progress"]) + float(packet["speed"]) * delta
			while float(packet["progress"]) >= 1.0:
				packet["progress"] = float(packet["progress"]) - 1.0
				packet["path_index"] = int(packet["path_index"]) + 1
				if int(packet["path_index"]) >= PATH_CELLS.size():
					state["integrity"] = int(state["integrity"]) - 1
					state["breaches"] = int(state["breaches"]) + 1
					packets.remove_at(packet_index)
					break

		for relay_value in state["relays"]:
			var relay: Dictionary = relay_value
			relay["scan_cooldown"] = maxf(0.0, float(relay["scan_cooldown"]) - delta)
			if float(relay["scan_cooldown"]) > 0.0:
				continue
			var target_index := -1
			var nearest_distance := float(relay["scan_range"])
			for packet_index in range(packets.size()):
				var packet: Dictionary = packets[packet_index]
				var distance: float = Vector2(relay["cell"]).distance_to(packet_grid_position(packet))
				if distance <= nearest_distance:
					nearest_distance = distance
					target_index = packet_index
			if target_index >= 0:
				var target: Dictionary = packets[target_index]
				target["checks"] = int(target["checks"]) - int(relay["cleanse_power"])
				relay["scan_cooldown"] = SCAN_COOLDOWN
				if int(target["checks"]) <= 0:
					packets.remove_at(target_index)
					state["cleaned"] = int(state["cleaned"]) + 1
					state["credits"] = int(state["credits"]) + CLEAN_REWARD

		if int(state["integrity"]) <= 0:
			state["phase"] = "lost"
		elif int(state["spawn_remaining"]) == 0 and packets.is_empty():
			state["phase"] = "won" if int(state["wave"]) >= WAVE_COUNTS.size() else "build"
