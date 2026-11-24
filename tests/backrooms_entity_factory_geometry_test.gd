extends SceneTree

const PlaygroundScene = preload("res://prototypes/BackroomsPortalPlayground.tscn")
const EntityDirector = preload("res://systems/BackroomsEntityDirector.gd")

const ENTITY_ROOT_NAMES := {
	"window": "Entity_Window",
	"smiler": "Entity_Smiler",
	"hound": "Entity_Hound",
	"skin_stealer": "Entity_SkinStealer",
	"clump": "Entity_Clump",
	"faceling": "Entity_Faceling"
}

const MINIMUM_MESH_COUNTS := {
	"window": 5,
	"smiler": 3,
	"hound": 8,
	"skin_stealer": 6,
	"clump": 7,
	"faceling": 6
}

var failures: Array[String] = []
var checked_factories: int = 0
var checked_meshes: int = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = PlaygroundScene.instantiate() as Node3D
	_expect(world != null, "Production Backrooms playground scene instantiates")
	if world == null:
		_finish()
		return

	root.add_child(world)
	await process_frame
	_expect(DisplayServer.get_name() != "headless", "Xvfb software-rendered DisplayServer is active")
	_expect(world.is_inside_tree(), "Production playground is inside the SceneTree before factory calls")
	if DisplayServer.get_name() == "headless":
		world.queue_free()
		await process_frame
		_finish()
		return

	for level_name in ["Level 1", "Level 2", "Level 3"]:
		world.set("current_level", level_name)
		world.call("_build_backrooms_room", level_name)
		await process_frame
		var level_factory_count: int = 0
		for entity_id in EntityDirector.get_allowed_entities(level_name):
			var spawn: Dictionary = _find_unloaded_spawn_cell(level_name, entity_id)
			_expect(bool(spawn.get("ok", false)), "%s has an unloaded deterministic cell for %s" % [level_name, entity_id])
			if not bool(spawn.get("ok", false)):
				continue
			var cell: Vector2i = spawn["cell"]
			world.call("_create_maze_cell", cell)
			var loaded_cells: Dictionary = world.get("_loaded_cells")
			var cell_root := loaded_cells.get(cell) as Node3D
			_expect(cell_root != null and cell_root.is_inside_tree(), "%s %s factory cell is attached to the production scene" % [level_name, entity_id])
			if cell_root == null:
				continue
			var entity_root_name: String = str(ENTITY_ROOT_NAMES.get(entity_id, ""))
			var entity_root := cell_root.get_node_or_null(entity_root_name) as Node3D
			_expect(entity_root != null, "%s production factory creates %s" % [level_name, entity_id])
			if entity_root == null:
				continue
			checked_factories += 1
			level_factory_count += 1
			_expect(str(entity_root.get_meta("backrooms_entity_id", "")) == entity_id, "%s factory preserves its stable entity ID" % entity_id)
			_expect(entity_root.get_meta("spawn_cell", Vector2i(-999, -999)) == cell, "%s factory preserves its source cell" % entity_id)
			var mesh_nodes: Array[Node] = entity_root.find_children("*", "MeshInstance3D", true, false)
			var minimum_count: int = int(MINIMUM_MESH_COUNTS.get(entity_id, 1))
			_expect(mesh_nodes.size() >= minimum_count, "%s factory builds at least %d mesh parts (found %d)" % [entity_id, minimum_count, mesh_nodes.size()])
			for mesh_node in mesh_nodes:
				var mesh_instance := mesh_node as MeshInstance3D
				_expect(mesh_instance != null and mesh_instance.is_inside_tree(), "%s mesh part is attached to the production scene" % entity_id)
				if mesh_instance == null:
					continue
				_expect(mesh_instance.mesh != null, "%s mesh part has a non-null mesh resource" % entity_id)
				_expect(mesh_instance.material_override != null, "%s mesh part has an explicit material" % entity_id)
				if mesh_instance.mesh != null:
					var bounds: AABB = mesh_instance.mesh.get_aabb()
					_expect(bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0, "%s mesh part has positive geometry bounds" % entity_id)
				checked_meshes += 1
		_expect(level_factory_count == EntityDirector.get_allowed_entities(level_name).size(), "%s validates every configured production factory" % level_name)

	world.set("current_level", "Level 0")
	world.call("_build_backrooms_room", "Level 0")
	await process_frame
	_expect(_create_entity_free_cell(Vector2i(71, 73)), "Level 0 production cell remains entity-free")

	world.set("current_level", "Unknown Level")
	world.call("_build_backrooms_room", "Unknown Level")
	await process_frame
	_expect(_create_entity_free_cell(Vector2i(-71, 73)), "Unknown level production cell fails closed")

	world.queue_free()
	await process_frame
	_finish()

func _find_unloaded_spawn_cell(level_name: String, entity_id: String) -> Dictionary:
	var loaded_cells: Dictionary = world.get("_loaded_cells")
	for z in range(-40, 41):
		for x in range(-40, 41):
			var cell := Vector2i(x, z)
			if loaded_cells.has(cell):
				continue
			var selected: Array[String] = EntityDirector.get_cell_spawns(level_name, cell)
			if not selected.has(entity_id):
				continue
			if entity_id == "window" and bool(world.call("_edge_is_open", cell, Vector2i(0, -1))):
				continue
			return {"ok": true, "cell": cell}
	return {"ok": false}

func _create_entity_free_cell(cell: Vector2i) -> bool:
	var loaded_cells: Dictionary = world.get("_loaded_cells")
	if loaded_cells.has(cell):
		return false
	world.call("_create_maze_cell", cell)
	var cell_root := loaded_cells.get(cell) as Node3D
	if cell_root == null:
		return false
	for child in cell_root.get_children():
		if str(child.name).begins_with("Entity_"):
			return false
	return true

func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _finish() -> void:
	if failures.is_empty():
		print("Backrooms production entity factory geometry tests passed: %d factories, %d mesh parts." % [checked_factories, checked_meshes])
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
