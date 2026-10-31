extends RefCounted

## Deterministic 10m underground room factory with explicit vertical mine layers.
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const LiftScript = preload("res://systems/UndergroundMineLift.gd")
const CHUNK_SIZE: float = 10.0
const LAYER_SPACING: float = 20.0
const MAX_LAYER_INDEX: int = 8
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
const CACHE_TABLE_RESOURCE_PATH: String = "res://systems/data/underground_loot_tables.json"
const LEGACY_WORLD_SEED: int = 0
const MAX_WORLD_SEED: int = 2147483647
static var _cache_tables_initialized: bool = false
static var _cache_tables_cache: Dictionary = {}

## Loads and validates the editable regional loot-table resource.
## Invalid/missing data fails closed: no regional cache is generated.
static func load_cache_tables(force_reload: bool = false) -> Dictionary:
	if _cache_tables_initialized and not force_reload:
		return _cache_tables_cache.duplicate(true)
	_cache_tables_initialized = true
	_cache_tables_cache = {}
	if not FileAccess.file_exists(CACHE_TABLE_RESOURCE_PATH):
		return {}
	var file := FileAccess.open(CACHE_TABLE_RESOURCE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	_cache_tables_cache = validate_cache_tables(parser.get_data())
	return _cache_tables_cache.duplicate(true)

## Pure validation entry point so malformed authoring data can be regression-tested
## without mutating the shipped resource file.
static func validate_cache_tables(payload: Variant) -> Dictionary:
	if not (payload is Dictionary) or int(payload.get("schema_version", 0)) != 1:
		return {}
	var raw_tables: Variant = payload.get("tables", null)
	if not (raw_tables is Dictionary) or raw_tables.size() != 4:
		return {}
	for table_id in ["west", "east", "north", "south"]:
		var raw_entries: Variant = raw_tables.get(table_id, null)
		if not (raw_entries is Array) or raw_entries.is_empty():
			return {}
		var seen_items: Dictionary = {}
		for raw_entry in raw_entries:
			if not (raw_entry is Dictionary):
				return {}
			var item_id: String = str(raw_entry.get("item_id", ""))
			var weight_value: Variant = raw_entry.get("weight", null)
			if not MINERAL_IDS.has(item_id) or not (weight_value is int or weight_value is float) or float(weight_value) <= 0.0 or not is_equal_approx(float(weight_value), roundf(float(weight_value))) or seen_items.has(item_id):
				return {}
			seen_items[item_id] = true
	return raw_tables.duplicate(true)


## Returns deterministic room-specific cache entries. Layer zero's service caches
## retain their original names and contents for save compatibility.
static func get_cache_spawn_data(coord: Vector2i, layer_index: int = 0, world_seed: int = LEGACY_WORLD_SEED) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if layer_index < 0 or layer_index > MAX_LAYER_INDEX or world_seed < 0 or world_seed > MAX_WORLD_SEED:
		return entries
	if coord == Vector2i.ZERO and layer_index == 0:
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

	var spawn_hash: int = coord.x * 31 + coord.y * 17 + layer_index * 43 + world_seed * 13 + 1009
	if posmod(spawn_hash, 3) == 0:
		return entries

	var table_id: String = _get_cache_table_id(coord, layer_index)
	var table_value: Variant = load_cache_tables().get(table_id, [])
	if not (table_value is Array) or table_value.is_empty():
		return entries
	var total_weight: int = 0
	for entry_value in table_value:
		if entry_value is Dictionary:
			total_weight += maxi(0, int(entry_value.get("weight", 0)))
	if total_weight <= 0:
		return entries

	var roll: int = posmod(coord.x * 97 + coord.y * 53 + layer_index * 101 + world_seed * 193 + 2029, total_weight)
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

	var position_index: int = posmod(coord.x * 7 + coord.y * 11 + layer_index * 3 + world_seed * 7 + 1, CACHE_POSITIONS.size())
	entries.append({
		"node_name": "MineCache_%s" % selected_item_id,
		"item_id": selected_item_id,
		"position": CACHE_POSITIONS[position_index],
		"table_id": table_id
	})
	return entries

static func _get_cache_table_id(coord: Vector2i, layer_index: int = 0) -> String:
	if coord == Vector2i.ZERO:
		return "north" if posmod(layer_index, 2) == 1 else "south"
	if abs(coord.x) >= abs(coord.y):
		return "west" if coord.x < 0 else "east"
	return "north" if coord.y < 0 else "south"

## Keep timestamp first and coordinate second for Run 52 callers; layer is optional.
static func make_chunk(now_unix: int = -1, coord: Vector2i = Vector2i.ZERO, layer_index: int = 0, world_seed: int = LEGACY_WORLD_SEED) -> Node3D:
	if layer_index < 0 or layer_index > MAX_LAYER_INDEX or world_seed < 0 or world_seed > MAX_WORLD_SEED:
		return null
	var root := Node3D.new()
	root.name = "UndergroundMine_%d_%d" % [coord.x, coord.y] if layer_index == 0 else "UndergroundMine_L%d_%d_%d" % [layer_index, coord.x, coord.y]
	root.position = Vector3(float(coord.x) * CHUNK_SIZE, -float(layer_index) * LAYER_SPACING, float(coord.y) * CHUNK_SIZE)
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

	var seed_value: int = posmod(coord.x * 31 + coord.y * 17 + layer_index * 43 + 1009, MINERAL_IDS.size())
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

	for cache_data in get_cache_spawn_data(coord, layer_index, world_seed):
		var cache_position_value: Variant = cache_data.get("position", null)
		if not (cache_position_value is Vector3):
			root.free()
			return null
		var cache_position: Vector3 = cache_position_value
		if not _add_salvage_cache(root, str(cache_data.get("node_name", "")), str(cache_data.get("item_id", "")), cache_position):
			root.free()
			return null

	if coord == Vector2i.ZERO:
		_add_lift_anchor(root, layer_index)
	return root

static func _add_lift_anchor(parent: Node3D, layer_index: int) -> void:
	var anchor: Node3D = LiftScript.new()
	anchor.name = "MineLiftAnchor"
	anchor.position = Vector3(1.5, -8.25, 7.5)
	anchor.set("layer_index", layer_index)
	parent.add_child(anchor)

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
