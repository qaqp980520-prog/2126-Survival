extends Node3D
class_name MineralMiningNode

## Prototype finite vein with wall-clock regeneration, including time spent offline.
const Catalog = preload("res://systems/MineralCatalog.gd")
const OreVisual = preload("res://prototypes/minerals/MineralOreVisual.gd")
const MiningVFX = preload("res://prototypes/minerals/MineralMiningVFX.gd")

signal ore_depleted(mineral_id: String)
signal ore_mined(mineral_id: String, amount: int)

@export_enum("copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore", "coal_ore", "uranium_ore") var mineral_id: String = "iron_ore"
@export_range(0, 10000, 1) var remaining_units: int = 24
@export_range(1, 10000, 1) var max_units: int = 24
@export_range(1, 20, 1) var units_per_hit: int = 1
@export_range(1, 86400, 1) var regen_interval_seconds: int = 300
@export var inventory_bridge_path: NodePath
@export var vfx_path: NodePath

## Unix timestamp for the start of the current partial regeneration interval.
var last_regen_unix: int = 0
var _depleted_signal_sent := false

func _ready() -> void:
	max_units = clampi(max_units, 1, 10000)
	remaining_units = clampi(remaining_units, 0, max_units)
	regen_interval_seconds = clampi(regen_interval_seconds, 1, 86400)
	if not Catalog.has_mineral(mineral_id):
		push_error("MineralMiningNode has unknown mineral_id: " + mineral_id)
		return
	if last_regen_unix <= 0:
		last_regen_unix = Time.get_unix_time_from_system()
	var vfx := get_node_or_null(vfx_path)
	if vfx == null:
		var created_vfx := MiningVFX.new()
		created_vfx.name = "MineralMiningVFX"
		add_child(created_vfx)
		vfx_path = get_path_to(created_vfx)
	var visual := get_node_or_null("MineralOreVisual")
	if visual == null:
		var created_visual := OreVisual.new()
		created_visual.name = "MineralOreVisual"
		created_visual.mineral_id = mineral_id
		add_child(created_visual)
	_depleted_signal_sent = remaining_units == 0
	visible = remaining_units > 0
	apply_elapsed_regeneration()

func _process(_delta: float) -> void:
	apply_elapsed_regeneration()

## Regenerates from elapsed wall-clock seconds, including time while the game was closed.
## Supplying now_unix makes deterministic tests possible. Returns units restored.
func apply_elapsed_regeneration(now_unix: int = -1) -> int:
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	if now < 0:
		return 0
	if last_regen_unix <= 0:
		last_regen_unix = now
		return 0
	if now < last_regen_unix:
		# Clock rollback must not create stock or move the saved timestamp backwards.
		return 0
	if remaining_units >= max_units:
		remaining_units = max_units
		last_regen_unix = now
		visible = true
		_depleted_signal_sent = false
		return 0
	var elapsed_seconds := now - last_regen_unix
	var intervals := int(elapsed_seconds / regen_interval_seconds)
	if intervals <= 0:
		return 0
	var previous := remaining_units
	remaining_units = mini(max_units, remaining_units + intervals)
	if remaining_units >= max_units:
		last_regen_unix = now
	else:
		last_regen_unix += intervals * regen_interval_seconds
	if remaining_units > 0:
		visible = true
		_depleted_signal_sent = false
	return remaining_units - previous

## Call from the tool's confirmed hit event. Returns actual units transferred.
func mine_hit(hit_position: Vector3 = Vector3.ZERO) -> int:
	apply_elapsed_regeneration()
	if remaining_units <= 0 or not Catalog.has_mineral(mineral_id):
		return 0
	var bridge := get_node_or_null(inventory_bridge_path)
	if bridge == null or not bridge.has_method("collect_mined_ore"):
		return 0
	var wanted := mini(units_per_hit, remaining_units)
	# Collect one unit at a time so inventory overflow cannot consume vein stock.
	var accepted := 0
	for i in range(wanted):
		if not bool(bridge.collect_mined_ore(mineral_id, 1)):
			break
		accepted += 1
	if accepted <= 0:
		return 0
	remaining_units -= accepted
	ore_mined.emit(mineral_id, accepted)
	var vfx := get_node_or_null(vfx_path)
	if vfx != null and vfx.has_method("play_hit"):
		vfx.play_hit(mineral_id, to_global(hit_position))
	if remaining_units <= 0:
		visible = false
		if not _depleted_signal_sent:
			_depleted_signal_sent = true
			ore_depleted.emit(mineral_id)
	return accepted

func restore_vein(units: int) -> void:
	if units <= 0:
		return
	remaining_units = mini(max_units, remaining_units + units)
	if remaining_units >= max_units:
		last_regen_unix = Time.get_unix_time_from_system()
	if remaining_units > 0:
		_depleted_signal_sent = false
		visible = true

func to_save_dict() -> Dictionary:
	return {
		"schema_version": 2,
		"mineral_id": mineral_id,
		"remaining_units": clampi(remaining_units, 0, max_units),
		"max_units": max_units,
		"regen_interval_seconds": regen_interval_seconds,
		"last_regen_unix": last_regen_unix
	}

## Older schema-v1 saves without regeneration fields remain valid.
## Invalid data is rejected before any live state changes.
func load_save_dict(data: Dictionary, now_unix: int = -1) -> bool:
	var schema_value: Variant = data.get("schema_version", null)
	if not _is_integer_in_range(schema_value, 1, 2):
		return false
	var schema := int(schema_value)
	if not (data.get("mineral_id", null) is String) or str(data["mineral_id"]) != mineral_id:
		return false
	var amount_value: Variant = data.get("remaining_units", null)
	if not _is_integer_in_range(amount_value, 0, 10000):
		return false
	var amount := int(amount_value)
	var saved_max := max_units
	if schema == 2 and not data.has("max_units"):
		return false
	if data.has("max_units"):
		var max_value: Variant = data["max_units"]
		if not _is_integer_in_range(max_value, 1, 10000):
			return false
		saved_max = int(max_value)
	elif amount > saved_max:
		# Legacy saves did not store a vein maximum; infer capacity to preserve existing stock.
		saved_max = amount
	if amount > saved_max:
		return false
	var saved_interval := regen_interval_seconds
	if schema == 2 and not data.has("regen_interval_seconds"):
		return false
	if data.has("regen_interval_seconds"):
		var interval_value: Variant = data["regen_interval_seconds"]
		if not _is_integer_in_range(interval_value, 1, 86400):
			return false
		saved_interval = int(interval_value)
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	var saved_timestamp: int = now
	if schema == 2 and not data.has("last_regen_unix"):
		return false
	if data.has("last_regen_unix"):
		var timestamp_value: Variant = data["last_regen_unix"]
		var minimum_timestamp: int = 1 if schema == 2 else 0
		if not _is_integer_in_range(timestamp_value, minimum_timestamp, 4000000000):
			return false
		saved_timestamp = int(timestamp_value)

	max_units = saved_max
	remaining_units = amount
	regen_interval_seconds = saved_interval
	last_regen_unix = saved_timestamp
	_depleted_signal_sent = remaining_units == 0
	visible = remaining_units > 0
	apply_elapsed_regeneration(now)
	return true

func _is_integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	if not is_finite(number) or number < float(minimum) or number > float(maximum):
		return false
	return floorf(number) == number
