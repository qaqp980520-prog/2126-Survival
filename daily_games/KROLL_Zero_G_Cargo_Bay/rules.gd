extends RefCounted
class_name KROLLZeroGCargoBayRules

const BOARD_SIZE: int = 5
const SUPPORT_MIN: float = 1.25
const SUPPORT_MAX: float = 3.75
const PERFECT_RADIUS: float = 0.8

const SHAPES = {
	"crate": {
		"label":"HEAVY CRATE", "symbol":"C", "mass":8,
		"cells":[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]
	},
	"bar": {
		"label":"ALLOY BAR", "symbol":"B", "mass":6,
		"cells":[Vector2i(0,0), Vector2i(1,0)]
	},
	"elbow": {
		"label":"ELBOW FRAME", "symbol":"L", "mass":7,
		"cells":[Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)]
	},
	"battery": {
		"label":"POWER CELL", "symbol":"P", "mass":3,
		"cells":[Vector2i(0,0), Vector2i(0,1)]
	},
	"block": {
		"label":"SENSOR BLOCK", "symbol":"S", "mass":4,
		"cells":[Vector2i(0,0)]
	},
	"panel": {
		"label":"SOLAR PANEL", "symbol":"H", "mass":5,
		"cells":[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
	}
}

const LEVELS = [
	{"name":"CORE COMPONENTS", "manifest":["crate","bar","elbow","battery","block"]},
	{"name":"REACTOR TRANSFER", "manifest":["panel","crate","bar","battery","elbow"]},
	{"name":"CRYO SHIPMENT", "manifest":["crate","panel","elbow","bar","block","battery"]}
]

static func level_count() -> int:
	return LEVELS.size()

static func level_at(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index].duplicate(true)

static func new_state() -> Dictionary:
	return {
		"level_index":0,
		"placements":[],
		"cursor":Vector2i(0,0),
		"rotation":0,
		"score":0,
		"completed":[false,false,false],
		"center_of_mass":Vector2.ZERO,
		"status":"active"
	}

static func shape_info(shape_id: String) -> Dictionary:
	return SHAPES.get(shape_id, {}).duplicate(true)

static func current_shape_id(state: Dictionary) -> String:
	var level: Dictionary = level_at(int(state.get("level_index", 0)))
	var manifest: Array = level.get("manifest", [])
	var placements: Array = state.get("placements", [])
	if placements.size() >= manifest.size():
		return ""
	return str(manifest[placements.size()])

static func rotated_cells(shape_id: String, rotation: int) -> Array[Vector2i]:
	var info: Dictionary = shape_info(shape_id)
	var source_cells: Array = info.get("cells", [])
	var result: Array[Vector2i] = []
	for raw_cell in source_cells:
		var cell: Vector2i = raw_cell
		for _turn in range(posmod(rotation, 4)):
			cell = Vector2i(-cell.y, cell.x)
		result.append(cell)
	if result.is_empty():
		return result
	var min_x: int = result[0].x
	var min_y: int = result[0].y
	for cell in result:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for index in range(result.size()):
		result[index] = Vector2i(result[index].x - min_x, result[index].y - min_y)
	return result

static func can_place(placements: Array, shape_id: String, rotation: int, anchor: Vector2i) -> bool:
	if not SHAPES.has(shape_id):
		return false
	var occupied: Dictionary = occupied_map(placements)
	for local_cell in rotated_cells(shape_id, rotation):
		var world_cell: Vector2i = anchor + local_cell
		if world_cell.x < 0 or world_cell.y < 0 or world_cell.x >= BOARD_SIZE or world_cell.y >= BOARD_SIZE:
			return false
		if occupied.has(world_cell):
			return false
	return true

static func occupied_map(placements: Array) -> Dictionary:
	var occupied: Dictionary = {}
	for raw_placement in placements:
		var placement: Dictionary = raw_placement
		var shape_id: String = str(placement.get("shape_id", ""))
		for raw_cell in placement.get("cells", []):
			var cell: Vector2i = raw_cell
			occupied[cell] = shape_id
	return occupied

static func calculate_center_of_mass(placements: Array) -> Vector2:
	var total_mass: float = 0.0
	var weighted_position: Vector2 = Vector2.ZERO
	for raw_placement in placements:
		var placement: Dictionary = raw_placement
		var cells: Array = placement.get("cells", [])
		var mass: float = float(placement.get("mass", 0))
		if cells.is_empty() or mass <= 0.0:
			continue
		var mass_per_cell: float = mass / float(cells.size())
		for raw_cell in cells:
			var cell: Vector2i = raw_cell
			var center := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
			weighted_position += center * mass_per_cell
			total_mass += mass_per_cell
	if total_mass <= 0.0:
		return Vector2.ZERO
	return weighted_position / total_mass

static func total_mass(placements: Array) -> int:
	var total: int = 0
	for raw_placement in placements:
		var placement: Dictionary = raw_placement
		total += int(placement.get("mass", 0))
	return total

static func is_stable(center: Vector2) -> bool:
	return (
		center.x >= SUPPORT_MIN and center.x <= SUPPORT_MAX
		and center.y >= SUPPORT_MIN and center.y <= SUPPORT_MAX
	)

static func score_for_center(center: Vector2) -> int:
	if not is_stable(center):
		return 0
	return 100 if center.distance_to(Vector2(2.5, 2.5)) <= PERFECT_RADIUS else 75

static func perform_action(state: Dictionary, action: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var status: String = str(next.get("status", "active"))
	if action == "restart":
		return {"accepted":true,"state":new_state(),"reason":"restarted"}
	if status == "campaign_won":
		return _rejected(next, "campaign_finished")
	if status == "won" and action != "next":
		return _rejected(next, "level_finished")
	if status == "unstable" and action != "undo":
		return _rejected(next, "undo_required")

	var level_index: int = int(next.get("level_index", 0))
	var level: Dictionary = level_at(level_index)
	if level.is_empty():
		return _rejected(next, "invalid_level")
	var placements: Array = next.get("placements", []).duplicate(true)
	var manifest: Array = level.get("manifest", [])

	match action:
		"move_up", "move_down", "move_left", "move_right":
			if status != "active":
				return _rejected(next, "level_not_active")
			var cursor: Vector2i = next.get("cursor", Vector2i.ZERO)
			match action:
				"move_up":
					cursor.y -= 1
				"move_down":
					cursor.y += 1
				"move_left":
					cursor.x -= 1
				"move_right":
					cursor.x += 1
			next["cursor"] = Vector2i(
				clampi(cursor.x, 0, BOARD_SIZE - 1),
				clampi(cursor.y, 0, BOARD_SIZE - 1)
			)
			return _accepted(next, "cursor_moved")
		"rotate":
			if status != "active" or current_shape_id(next).is_empty():
				return _rejected(next, "no_current_cargo")
			next["rotation"] = posmod(int(next.get("rotation", 0)) + 1, 4)
			return _accepted(next, "rotated")
		"place":
			if status != "active":
				return _rejected(next, "level_not_active")
			var shape_id: String = current_shape_id(next)
			if shape_id.is_empty():
				return _rejected(next, "manifest_complete")
			var rotation: int = posmod(int(next.get("rotation", 0)), 4)
			var anchor: Vector2i = next.get("cursor", Vector2i.ZERO)
			if not can_place(placements, shape_id, rotation, anchor):
				return _rejected(next, "invalid_placement")
			var absolute_cells: Array[Vector2i] = []
			for local_cell in rotated_cells(shape_id, rotation):
				absolute_cells.append(anchor + local_cell)
			var info: Dictionary = shape_info(shape_id)
			placements.append({
				"shape_id":shape_id,
				"mass":int(info.get("mass", 0)),
				"cells":absolute_cells,
				"anchor":anchor,
				"rotation":rotation
			})
			next["placements"] = placements
			next["rotation"] = 0
			if placements.size() == manifest.size():
				var center: Vector2 = calculate_center_of_mass(placements)
				next["center_of_mass"] = center
				if is_stable(center):
					var completed: Array = next.get("completed", []).duplicate(true)
					if not bool(completed[level_index]):
						next["score"] = int(next.get("score", 0)) + score_for_center(center)
						completed[level_index] = true
					next["completed"] = completed
					next["status"] = "won"
					return _accepted(next, "stable")
				next["status"] = "unstable"
				return _accepted(next, "unstable")
			return _accepted(next, "cargo_placed")
		"undo":
			if placements.is_empty() or not ["active","unstable"].has(status):
				return _rejected(next, "nothing_to_undo")
			placements.pop_back()
			next["placements"] = placements
			next["status"] = "active"
			next["rotation"] = 0
			next["center_of_mass"] = Vector2.ZERO
			return _accepted(next, "last_cargo_removed")
		"next":
			if status != "won":
				return _rejected(next, "level_not_stable")
			if level_index >= LEVELS.size() - 1:
				next["status"] = "campaign_won"
				return _accepted(next, "campaign_complete")
			next["level_index"] = level_index + 1
			next["placements"] = []
			next["cursor"] = Vector2i(0,0)
			next["rotation"] = 0
			next["center_of_mass"] = Vector2.ZERO
			next["status"] = "active"
			return _accepted(next, "next_manifest")
		_:
			return _rejected(next, "unknown_action")

static func _accepted(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted":true,"state":state,"reason":reason}

static func _rejected(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted":false,"state":state.duplicate(true),"reason":reason}
