extends Node3D
class_name MineralInventoryPreview

## Reuses the same ore silhouette at compact scale for inventory slot previews.
const OreVisual = preload("res://prototypes/minerals/MineralOreVisual.gd")
@export_enum("copper_ore", "iron_ore", "gold_ore", "silver_ore", "aluminium_ore", "coal_ore", "uranium_ore") var mineral_id: String = "iron_ore"
@export_range(0.1, 1.0, 0.05) var icon_scale: float = 0.38
@export var random_seed: int = 2126

func _ready() -> void:
	refresh_preview()

func refresh_preview() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var ore := OreVisual.new()
	ore.name = "OreIconModel"
	ore.mineral_id = mineral_id
	ore.visual_scale = icon_scale
	ore.random_seed = random_seed
	add_child(ore)
