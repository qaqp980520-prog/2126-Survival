extends SceneTree

const Factory = preload("res://systems/UndergroundMineFactory.gd")
const MineralCatalog = preload("res://systems/MineralCatalog.gd")
const VEIN_POSITIONS: Array[Vector3] = [Vector3(2.5, -8.0, 6.0), Vector3(6.5, -8.0, 6.0), Vector3(6.5, -8.0, 2.5)]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var all_items: Dictionary = {}
	var all_tables: Dictionary = {}
	var stable_ids: Dictionary = {}
	var initial_window_cache_count: int = 0
	var initial_window_cache_rooms: int = 0
	var sampled_non_origin_rooms: int = 0
	var spawned_non_origin_rooms: int = 0
	var empty_non_origin_rooms: int = 0
	for y in range(-6, 7):
		for x in range(-6, 7):
			var coord := Vector2i(x, y)
			var first: Array[Dictionary] = Factory.get_cache_spawn_data(coord)
			var second: Array[Dictionary] = Factory.get_cache_spawn_data(coord)
			_expect(first == second, "cache selection is deterministic for room %d,%d" % [x, y])
			if coord == Vector2i.ZERO:
				_expect(first.size() == 2, "origin service room keeps its two fixed caches")
				_expect(str(first[0].get("node_name", "")) == "MineCache_Gold" and str(first[1].get("node_name", "")) == "MineCache_Coal", "origin cache identities remain backward compatible")
			else:
				sampled_non_origin_rooms += 1
				var should_spawn: bool = posmod(x * 31 + y * 17 + 1009, 3) != 0
				if should_spawn:
					spawned_non_origin_rooms += 1
				else:
					empty_non_origin_rooms += 1
				_expect(first.size() == (1 if should_spawn else 0), "non-origin room follows the deterministic one-third empty-room rule at %d,%d" % [x, y])
			if first.is_empty():
				continue
			if x >= -1 and x <= 1 and y >= -1 and y <= 1:
				initial_window_cache_count += first.size()
				initial_window_cache_rooms += 1
			for entry in first:
				var item_id: String = str(entry.get("item_id", ""))
				var node_name: String = str(entry.get("node_name", ""))
				var table_id: String = str(entry.get("table_id", ""))
				var position_value: Variant = entry.get("position", null)
				_expect(MineralCatalog.has_mineral(item_id), "cache item belongs to the mineral catalog")
				_expect(node_name.begins_with("MineCache_"), "cache node has a stable MineCache name")
				_expect(position_value is Vector3, "cache placement is a local Vector3")
				if position_value is Vector3:
					var cache_position: Vector3 = position_value
					for vein_position in VEIN_POSITIONS:
						_expect(cache_position.distance_to(vein_position) > 1.5, "cache placement does not overlap a mineral vein")
				if coord != Vector2i.ZERO:
					_expect(table_id == _expected_table_id(coord), "room uses the correct regional loot table")
					all_items[item_id] = true
					all_tables[table_id] = true
				var stable_id: String = "underground/mine_%d_%d/object/UndergroundMine_%d_%d/%s" % [x, y, x, y, node_name]
				_expect(not stable_ids.has(stable_id), "stable cache ID is unique across the sampled room grid")
				stable_ids[stable_id] = true
	_expect(sampled_non_origin_rooms == 168 and spawned_non_origin_rooms == 112 and empty_non_origin_rooms == 56, "13x13 sample preserves the exact two-thirds spawn / one-third empty ratio")
	_expect(initial_window_cache_count == 7, "initial 3x3 mine window contains two service caches plus five regional caches")
	_expect(initial_window_cache_rooms == 6, "initial 3x3 mine window distributes caches across six rooms")
	_expect(all_tables.size() == 4, "all four directional loot tables are exercised across the sample grid")
	_expect(all_items.size() == 7, "weighted tables can produce all seven catalog minerals across the sample grid")
	if failures.is_empty():
		print("Underground cache distribution tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)

func _expected_table_id(coord: Vector2i) -> String:
	if abs(coord.x) >= abs(coord.y):
		return "west" if coord.x < 0 else "east"
	return "north" if coord.y < 0 else "south"

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
