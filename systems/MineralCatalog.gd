extends RefCounted
class_name MineralCatalog

## Stable item IDs are shared by inventory, mining drops, save data and visuals.
const MINERALS: Dictionary = {
	"copper_ore": {
		"display_name": "銅礦",
		"weight_kg": 2.8,
		"rock_color": Color(0.34, 0.20, 0.13),
		"vein_color": Color(0.95, 0.34, 0.10),
		"vein_metallic": 0.72,
		"particle_color": Color(1.0, 0.38, 0.12),
		"drop_min": 1, "drop_max": 3
	},
	"iron_ore": {
		"display_name": "鐵礦",
		"weight_kg": 3.0,
		"rock_color": Color(0.20, 0.22, 0.24),
		"vein_color": Color(0.52, 0.57, 0.61),
		"vein_metallic": 0.48,
		"particle_color": Color(0.74, 0.78, 0.82),
		"drop_min": 1, "drop_max": 3
	},
	"gold_ore": {
		"display_name": "金礦",
		"weight_kg": 3.2,
		"rock_color": Color(0.24, 0.20, 0.12),
		"vein_color": Color(1.0, 0.68, 0.08),
		"vein_metallic": 0.9,
		"particle_color": Color(1.0, 0.72, 0.16),
		"drop_min": 1, "drop_max": 2
	},
	"silver_ore": {
		"display_name": "銀礦",
		"weight_kg": 3.1,
		"rock_color": Color(0.23, 0.24, 0.27),
		"vein_color": Color(0.82, 0.87, 0.94),
		"vein_metallic": 0.92,
		"particle_color": Color(0.82, 0.89, 1.0),
		"drop_min": 1, "drop_max": 2
	},
	"aluminium_ore": {
		"display_name": "鋁礦",
		"weight_kg": 2.4,
		"rock_color": Color(0.29, 0.27, 0.24),
		"vein_color": Color(0.68, 0.72, 0.74),
		"vein_metallic": 0.58,
		"particle_color": Color(0.76, 0.82, 0.86),
		"drop_min": 1, "drop_max": 3
	},
	"coal_ore": {
		"display_name": "煤礦",
		"weight_kg": 1.4,
		"rock_color": Color(0.08, 0.08, 0.09),
		"vein_color": Color(0.16, 0.17, 0.19),
		"vein_metallic": 0.12,
		"particle_color": Color(0.22, 0.22, 0.24),
		"drop_min": 2, "drop_max": 5
	},
	"uranium_ore": {
		"display_name": "鈾礦",
		"weight_kg": 3.4,
		"rock_color": Color(0.16, 0.19, 0.15),
		"vein_color": Color(0.10, 0.86, 0.31),
		"vein_metallic": 0.35,
		"particle_color": Color(0.15, 1.0, 0.35),
		"drop_min": 1, "drop_max": 2
	}
}

static func has_mineral(item_id: String) -> bool:
	return MINERALS.has(item_id)

static func get_mineral(item_id: String) -> Dictionary:
	return MINERALS.get(item_id, {}).duplicate(true)

static func get_ids() -> Array:
	return MINERALS.keys()
