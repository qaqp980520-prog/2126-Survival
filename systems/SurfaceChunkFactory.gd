extends RefCounted

## Shared deterministic surface-chunk factory for the playable world and prototype.
const MiningNodeScript = preload("res://systems/MineralMiningNode.gd")
const CropPlotVisualScene = preload("res://systems/CropPlotVisual.tscn")
const StatefulPropScript = preload("res://systems/WorldObjectStatefulProp.gd")
const CHUNK_SIZE: float = 10.0
const MINERAL_IDS: Array[String] = ["iron_ore", "copper_ore", "gold_ore"]
const SALVAGE_LOOT_IDS: Array[String] = ["copper_ore", "iron_ore", "coal_ore", "silver_ore"]
const CROP_KINDS: Array[String] = ["wheat", "tomato"]

static func make_chunk(coord: Vector2i, now_unix: int = -1) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = Vector3(float(coord.x) * CHUNK_SIZE, 0.0, float(coord.y) * CHUNK_SIZE)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	chunk.add_child(ground)
	var box_size := Vector3(CHUNK_SIZE, 0.5, CHUNK_SIZE)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	collision.shape = box_shape
	collision.position = Vector3(CHUNK_SIZE * 0.5, -0.25, CHUNK_SIZE * 0.5)
	ground.add_child(collision)
	if DisplayServer.get_name() != "headless":
		var ground_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box_size
		ground_mesh.mesh = box_mesh
		ground_mesh.position = collision.position
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.10, 0.15, 0.19) if (coord.x + coord.y) % 2 == 0 else Color(0.13, 0.18, 0.22)
		ground_mesh.material_override = material
		ground.add_child(ground_mesh)
	var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var ore: Node3D = MiningNodeScript.new()
	ore.name = "Ore_%d_%d" % [coord.x, coord.y]
	ore.mineral_id = str(MINERAL_IDS[posmod(coord.x + coord.y, MINERAL_IDS.size())])
	ore.max_units = 6
	ore.remaining_units = 6
	ore.regen_interval_seconds = 60
	ore.last_regen_unix = timestamp
	ore.inventory_bridge_path = NodePath("../../../SurvivalWorldBridge")
	ore.position = Vector3(CHUNK_SIZE * 0.5, -3.0, CHUNK_SIZE * 0.5)
	chunk.add_child(ore)
	var crate: Node3D = StatefulPropScript.new()
	crate.name = "SalvageCrate"
	var loot_index: int = posmod(coord.x * 31 + coord.y * 17 + 1009, SALVAGE_LOOT_IDS.size())
	if not bool(crate.call("set_loot_item", SALVAGE_LOOT_IDS[loot_index])):
		chunk.free()
		return null
	crate.position = Vector3(CHUNK_SIZE * 0.55, 0.0, CHUNK_SIZE * 0.62)
	chunk.add_child(crate)
	for plot_index in range(CROP_KINDS.size()):
		var plot := CropPlotVisualScene.instantiate() as Node3D
		if plot == null:
			chunk.free()
			return null
		plot.name = "CropPlot_" + str(plot_index)
		plot.set("crop_id", CROP_KINDS[plot_index])
		plot.set("plot_index", plot_index + 1)
		plot.position = Vector3(2.4 + float(plot_index) * 5.0, 0.0, 2.4)
		chunk.add_child(plot)
	return chunk
