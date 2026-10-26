extends Node3D
class_name MineralMiningNode

## Prototype bridge for one finite mineral vein.
## The owning world system is responsible for persistence and real-time regeneration.
const Catalog = preload("res://systems/MineralCatalog.gd")
const OreVisual = preload("res://prototypes/minerals/MineralOreVisual.gd")
const MiningVFX = preload("res://prototypes/minerals/MineralMiningVFX.gd")

signal ore_depleted(mineral_id: String)
signal ore_mined(mineral_id: String, amount: int)

@export_enum("copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore", "coal_ore", "uranium_ore") var mineral_id: String = "iron_ore"
@export_range(1, 10000, 1) var remaining_units: int = 24
@export_range(1, 20, 1) var units_per_hit: int = 1
@export var inventory_bridge_path: NodePath
@export var vfx_path: NodePath
var _depleted_signal_sent := false

func _ready() -> void:
	if not Catalog.has_mineral(mineral_id):
		push_error("MineralMiningNode has unknown mineral_id: " + mineral_id)
		return
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
	if remaining_units <= 0:
		remaining_units = 0
		visible = false

## Call from the tool's confirmed hit event. Returns actual units transferred.
func mine_hit(hit_position: Vector3 = Vector3.ZERO) -> int:
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
	var vfx := get_node_or_null(vfx_path)
	if vfx != null and vfx.has_method("play_hit"):
		vfx.play_hit(mineral_id, to_global(hit_position))
	ore_mined.emit(mineral_id, accepted)
	if remaining_units <= 0:
		visible = false
		if not _depleted_signal_sent:
			_depleted_signal_sent = true
			ore_depleted.emit(mineral_id)
	return accepted

func restore_vein(units: int) -> void:
	if units <= 0:
		return
	remaining_units = mini(10000, remaining_units + units)
	if remaining_units > 0:
		_depleted_signal_sent = false
		visible = true

func to_save_dict() -> Dictionary:
	return {"schema_version": 1, "mineral_id": mineral_id, "remaining_units": remaining_units}

func load_save_dict(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != 1:
		return false
	if str(data.get("mineral_id", "")) != mineral_id:
		return false
	var value: Variant = data.get("remaining_units", null)
	if not (value is int or value is float):
		return false
	var amount := float(value)
	if not is_finite(amount) or floorf(amount) != amount or amount < 0 or amount > 10000:
		return false
	remaining_units = int(amount)
	visible = remaining_units > 0
	_depleted_signal_sent = remaining_units == 0
	return true
