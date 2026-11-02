extends RefCounted
class_name SurfaceTerrainCornerConflictResolver

## Deterministically identifies perpendicular ramp pairs that must retain the safe step fallback.
## This resolver reports topology only; it does not create or mutate collision geometry.
const VALID_SIDES: Array[String] = ["east", "west", "north", "south"]
const SIDE_ORDER: Dictionary = {"east":0,"south":1,"west":2,"north":3}

static func resolve(candidates: Dictionary) -> Dictionary:
	var sides_by_patch: Dictionary = {}
	for edge_key_value in candidates.keys():
		var edge_key: String = str(edge_key_value)
		if edge_key.is_empty():
			return {"ok":false,"error":"invalid_edge_key"}
		var edge_value: Variant = candidates[edge_key_value]
		if not (edge_value is Dictionary):
			return {"ok":false,"error":"invalid_edge_descriptor"}
		var edge: Dictionary = edge_value
		for required in ["first_id", "second_id", "first_side", "second_side"]:
			if not edge.has(required):
				return {"ok":false,"error":"missing_" + required}
		var first_id: String = str(edge["first_id"])
		var second_id: String = str(edge["second_id"])
		var first_side: String = str(edge["first_side"])
		var second_side: String = str(edge["second_side"])
		if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
			return {"ok":false,"error":"invalid_patch_ids"}
		if not VALID_SIDES.has(first_side) or not VALID_SIDES.has(second_side):
			return {"ok":false,"error":"invalid_patch_side"}
		_record_side(sides_by_patch, first_id, first_side, edge_key)
		_record_side(sides_by_patch, second_id, second_side, edge_key)

	var blocked_edges: Dictionary = {}
	var reports: Array[Dictionary] = []
	var patch_ids: Array = sides_by_patch.keys()
	patch_ids.sort()
	for stable_id_value in patch_ids:
		var stable_id: String = str(stable_id_value)
		var entries: Array = sides_by_patch[stable_id]
		entries.sort_custom(_entry_less)
		var seen_sides: Dictionary = {}
		for entry_value in entries:
			var side: String = str(entry_value["side"])
			if seen_sides.has(side):
				var duplicate_keys: Array[String] = [str(seen_sides[side]), str(entry_value["edge_key"])]
				duplicate_keys.sort()
				return {
					"ok":false,
					"error":"duplicate_patch_side",
					"stable_id":stable_id,
					"side":side,
					"edge_keys":duplicate_keys
				}
			seen_sides[side] = str(entry_value["edge_key"])
		for first_index in range(entries.size()):
			for second_index in range(first_index + 1, entries.size()):
				var first_entry: Dictionary = entries[first_index]
				var second_entry: Dictionary = entries[second_index]
				var corner: String = _corner_for_sides(str(first_entry["side"]), str(second_entry["side"]))
				if corner.is_empty():
					continue
				var first_edge: String = str(first_entry["edge_key"])
				var second_edge: String = str(second_entry["edge_key"])
				blocked_edges[first_edge] = true
				blocked_edges[second_edge] = true
				var edge_keys: Array[String] = [first_edge, second_edge]
				edge_keys.sort()
				reports.append({
					"stable_id":stable_id,
					"corner":corner,
					"edge_keys":edge_keys,
					"policy":"step_fallback"
				})
	reports.sort_custom(_report_less)
	return {"ok":true,"blocked_edges":blocked_edges,"reports":reports}

static func _record_side(target: Dictionary, stable_id: String, side: String, edge_key: String) -> void:
	if not target.has(stable_id):
		target[stable_id] = []
	target[stable_id].append({"side":side,"edge_key":edge_key})

static func _entry_less(first: Dictionary, second: Dictionary) -> bool:
	var first_order: int = int(SIDE_ORDER.get(str(first["side"]), 99))
	var second_order: int = int(SIDE_ORDER.get(str(second["side"]), 99))
	if first_order != second_order:
		return first_order < second_order
	return str(first["edge_key"]) < str(second["edge_key"])

static func _report_less(first: Dictionary, second: Dictionary) -> bool:
	if str(first["stable_id"]) != str(second["stable_id"]):
		return str(first["stable_id"]) < str(second["stable_id"])
	var corner_order: Array[String] = ["north_east", "south_east", "south_west", "north_west"]
	var first_order: int = corner_order.find(str(first["corner"]))
	var second_order: int = corner_order.find(str(second["corner"]))
	if first_order != second_order:
		return first_order < second_order
	return str(first["edge_keys"]) < str(second["edge_keys"])

static func _corner_for_sides(first_side: String, second_side: String) -> String:
	if first_side == second_side or _opposite_side(first_side) == second_side:
		return ""
	var pair: Array[String] = [first_side, second_side]
	pair.sort()
	var key: String = "%s|%s" % [pair[0], pair[1]]
	match key:
		"east|north": return "north_east"
		"east|south": return "south_east"
		"north|west": return "north_west"
		"south|west": return "south_west"
		_: return ""

static func _opposite_side(side: String) -> String:
	match side:
		"east": return "west"
		"west": return "east"
		"north": return "south"
		"south": return "north"
		_: return ""
