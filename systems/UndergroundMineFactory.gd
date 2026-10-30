extends RefCounted

## Deterministic 10m underground room factory. Adjacent rooms share aligned open doorways.
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const CHUNK_SIZE: float = 10.0
const MINERAL_IDS: Array[String] = [
	"iron_ore", "copper_ore", "gold_ore", "silver_ore",
	"aluminium_ore", "coal_ore", "uranium_ore"
]
const CACHE_POSITIONS: Array[Vector3] = [
	Vector3(1.2, -8.25, 1.2),
	Vector3(8.2, -8.25, 8.0),
	Vector3(8.2, -8.25, 2.0),
	Vector3(1.2, -8.25, 8.0)
]
const CACHE_TABLES: Dictionary = {
	"west": [
		{"item_id": "iron_ore", "weight": 4},
		{"item_id": "coal_ore", "weight": 3},
		{"item_id": "copper_ore", "weight": 2}
	],
	"east": [
		{"item_id": "copper_ore", "weight": 4},
		{"item_id": "silver_ore", "weight": 2},
		{"item_id": "aluminium_ore", "weight": 3}
	],
	"north": [
		{"item_id": "aluminium_ore", "weight": 4},
		{"item_id": "silver_ore", "weight": 3},
		{"item_id": "gold_ore", "weight": 1}
	],
	"south": [
		{"item_id": "coal_ore", "weight": 4},
		{"item_id": "gold_ore", "weight": 2},
		{"item_id": "uranium_ore", "weight": 1}
	]
}

## Returns deterministic, room-specific cache entries without mutating a scene.
## The origin remains the two-cache service room; other rooms use weighted tables
## and a coordinate hash so unloading/reloading never rerolls their contents.
static func get_cache_spawn_data(coord: Vector2i) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if coord == Vector2i.ZERO:
		entries.append({
			"node_name": "MineCache_Gold",
			"item_id": "gold_ore",
			"position": Vector3(8.2, -8.25, 8.0),
			"table_id": "service"
		})
		entries.append({
			"node_name": "MineCache_Coal",
			"item_id": "coal_ore",
			"position": Vector3(8.2, -8.25, 2.0),
			"table_id": "service"
		})
		return entries

	# One third of non-origin rooms are intentionally cache-free. The decision
	# is stable per coordinate and keeps loot density below one cache per room.
	if posmod(coord.x * 31 + coord.y * 17 + 1009, 3) == 0:
		return entries

	var table_id: String = _get_cache_table_id(coord)
	var table_value: Variant = CACHE_TABLES.get(table_id, [])
	if not (table_value is Array) or table_value.is_empty():
		return entries
	var total_weight: int = 0
	for entry_value in table_value:
		if entry_value is Dictionary:
			total_weight += maxi(0, int(entry_value.get("weight", 0)))
	if total_weight <= 0:
		return entries

	var roll: int = posmod(coord.x * 97 + coord.y * 53 + 2029, total_weight)
	var selected_item_id: String = ""
	for entry_value in table_value:
		if not (entry_value is Dictionary):
			continue
		var weight: int = maxi(0, int(entry_value.get("weight", 0)))
		if roll < weight:
			selected_item_id = str(entry_value.get("item_id", ""))
			break
		roll -= weight
	if selected_item_id.is_empty() or not MINERAL_IDS.has(selected_item_id):
		return entries

	var position_index: int = posmod(coord.x * 7 + coord.y * 11 + 1, CACHE_POSITIONS.size())
	entries.append({
		"node_name": "MineCache_%s" % selected_item_id,
		"item_id": selected_item_id,
		"position": CACHE_POSITIONS[position_index],
		"table_id": table_id
	})
	return entries

static func _get_cache_table_id(coord: Vector2i) -> String:
	if abs(coord.x) >= abs(coord.y):
		return "west" if coord.x < 0 else "east"
	return "north" if coord.y < 0 else "south"

## Keep timestamp as the first argument for compatibility with Run 52 callers.
static func make_chunk(now_unix: int = -1, coord: Vector2i = Vector2i.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = "UndergroundMine_%d_%d" % [coord.x, coord.y]
	root.position = Vector3(float(coord.x) * CHUNK_SIZE, 0.0, float(coord.y) * CHUNK_SIZE)
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	_add_box_body(root, "MineFloor", Vector3(5.0, -8.5, 5.0), Vector3(10.0, 0.5, 10.0), Color(0.12, 0.14, 0.17))
	_add_box_body(root, "MineCeiling", Vector3(5.0, -4.0, 5.0), Vector3(10.0, 0.5, 10.0), Color(0.065, 0.075, 0.09))
	_add_wall_with_door(root, "West", Vector3(-0.25, -6.25, 0.0), true)
	_add_wall_with_door(root, "East", Vector3(10.25, -6.25, 0.0), true)
	_add_wall_with_door(root, "North", Vector3(0.0, -6.25, -0.25), false)
	_add_wall_with_door(root, "South", Vector3(0.0, -6.25, 10.25), false)
	var lamp := OmniLight3D.new()
	lamp.name = "MineLamp"
	lamp.position = Vector3(5.0, -4.8, 5.0)
	lamp.light_color = Color(0.48, 0.72, 1.0)
	lamp.light_energy = 1.8
	lamp.omni_range = 13.0
	lamp.shadow_enabled = false
	root.add_child(lamp)

	var seed_value: int = posmod(coord.x * 31 + coord.y * 17 + 1009, MINERAL_IDS.size())
	var positions: Array[Vector3] = [
		Vector3(2.5, -8.0, 6.0),
		Vector3(6.5, -8.0, 6.0),
		Vector3(6.5, -8.0, 2.5)
	]
	for index in range(positions.size()):
		var vein: Node3D = MiningNodeScript.new()
		vein.name = "Vein_%d" % index
		vein.set("mineral_id", MINERAL_IDS[posmod(seed_value + index * 2, MINERAL_IDS.size())])
		vein.set("max_units", 12)
		vein.set("remaining_units", 12)
		vein.set("units_per_hit", 1)
		vein.set("regen_interval_seconds", 300)
		vein.set("last_regen_unix", timestamp)
		vein.set("inventory_bridge_path", NodePath("../../../SurvivalWorldBridge"))
		vein.position = positions[index]
		root.add_child(vein)

	for cache_data in get_cache_spawn_data(coord):
		var cache_position_value: Variant = cache_data.get("position", null)
		if not (cache_position_value is Vector3):
			root.free()
			return null
		var cache_position: Vector3 = cache_position_value
		if not _add_salvage_cache(root, str(cache_data.get("node_name", "")), str(cache_data.get("item_id", "")), cache_position):
			root.free()
			return null
	return root

static func _add_salvage_cache(parent: Node3D, node_name: String, item_id: String, position: Vector3) -> bool:
	var cache: Node3D = StatefulPropScript.new()
	cache.name = node_name
	if not bool(cache.call("set_loot_item", item_id)):
		cache.free()
		return false
	cache.position = position
	parent.add_child(cache)
	return true

static func _add_wall_with_door(parent: Node3D, wall_name: String, origin: Vector3, vertical_wall: bool) -> void:
	var first_center: Vector3
	var second_center: Vector3
	var segment_size: Vector3
	if vertical_wall:
		first_center = origin + Vector3(0.0, 0.0, 2.0)
		second_center = origin + Vector3(0.0, 0.0, 8.0)
		segment_size = Vector3(0.5, 4.5, 4.0)
	else:
		first_center = origin + Vector3(2.0, 0.0, 0.0)
		second_center = origin + Vector3(8.0, 0.0, 0.0)
		segment_size = Vector3(4.0, 4.5, 0.5)
	var color := Color(0.09, 0.11, 0.14)
	_add_box_body(parent, "MineWall%s_A" % wall_name, first_center, segment_size, color)
	_add_box_body(parent, "MineWall%s_B" % wall_name, second_center, segment_size, color)

static func _add_box_body(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if DisplayServer.get_name() != "headless":
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.94
		visual.material_override = material
		body.add_child(visual)
	parent.add_child(body)
