extends Node3D
class_name SurfaceTerrainPatch

## Raised 2 m terrain tile with four traversable ramps and persistent material/height state.
const SURFACE_TYPES: Array[String] = ["soil", "rock", "metal"]
const MAX_HEIGHT_LEVEL: int = 2
const MAX_REVISION: int = 1000000
const PATCH_SIZE: float = 2.0
const EDGE_RAMP_RUN: float = 0.75
const EDGE_RAMP_COLLISION_THICKNESS: float = 0.04
const RAMP_SIDES: Array[String] = ["east", "west", "north", "south"]

var _height_level: int = 0
var _surface_type: String = "soil"
var _revision: int = 0
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _surface_mesh: MeshInstance3D
var _interaction_area: Area3D
var _ramp_collisions: Dictionary = {}
var _ramp_visuals: Dictionary = {}

func _ready() -> void:
	_build_collision()
	_build_interaction_area()
	if DisplayServer.get_name() != "headless":
		_build_visual()
	_refresh_geometry()

func get_world_object_state() -> Dictionary:
	return {"height_level":_height_level,"surface_type":_surface_type,"revision":_revision}

func validate_world_object_state(state: Dictionary) -> bool:
	if state.size() != 3 or not state.has("height_level") or not state.has("surface_type") or not state.has("revision"):
		return false
	var height_value: Variant = state.get("height_level",null)
	var surface_value: Variant = state.get("surface_type",null)
	var revision_value: Variant = state.get("revision",null)
	if not (height_value is int) or not (surface_value is String) or not (revision_value is int):
		return false
	if int(height_value) < 0 or int(height_value) > MAX_HEIGHT_LEVEL:
		return false
	if not SURFACE_TYPES.has(str(surface_value)):
		return false
	return int(revision_value) >= 0 and int(revision_value) <= MAX_REVISION

func apply_world_object_state(state: Dictionary) -> bool:
	if not validate_world_object_state(state):
		return false
	_height_level=int(state["height_level"])
	_surface_type=str(state["surface_type"])
	_revision=int(state["revision"])
	_refresh_geometry()
	return true

func cycle_terrain_edit() -> Dictionary:
	if _revision >= MAX_REVISION:
		return {"ok":false,"reason":"revision_limit","state":get_world_object_state()}
	var surface_index: int = SURFACE_TYPES.find(_surface_type)
	_height_level=(_height_level+1) % (MAX_HEIGHT_LEVEL+1)
	_surface_type=SURFACE_TYPES[posmod(surface_index+1,SURFACE_TYPES.size())]
	_revision+=1
	_refresh_geometry()
	return {"ok":true,"reason":"edited","state":get_world_object_state()}

func get_top_height() -> float:
	return 0.05+float(_height_level)*0.25

func _build_collision() -> void:
	_collision_body=StaticBody3D.new()
	_collision_body.name="TerrainCollisionBody"
	_collision_body.collision_layer=1
	_collision_body.collision_mask=0
	add_child(_collision_body)
	_collision_shape=CollisionShape3D.new()
	_collision_shape.name="TerrainCollisionShape"
	_collision_body.add_child(_collision_shape)
	for side in RAMP_SIDES:
		var ramp := CollisionShape3D.new()
		ramp.name="TerrainRampCollision_"+side.capitalize()
		_configure_ramp_collision(ramp,side,get_top_height())
		_collision_body.add_child(ramp)
		_ramp_collisions[side]=ramp

func _build_interaction_area() -> void:
	_interaction_area=Area3D.new()
	_interaction_area.name="InteractionArea"
	_interaction_area.collision_layer=2
	_interaction_area.collision_mask=0
	_interaction_area.monitoring=false
	var proxy_shape := CollisionShape3D.new()
	proxy_shape.name="InteractionShape"
	var box := BoxShape3D.new()
	box.size=Vector3(PATCH_SIZE*1.2,3.4,PATCH_SIZE*1.2)
	proxy_shape.shape=box
	proxy_shape.position=Vector3(0.0,1.7,0.0)
	_interaction_area.add_child(proxy_shape)
	add_child(_interaction_area)

func _build_visual() -> void:
	_surface_mesh=MeshInstance3D.new()
	_surface_mesh.name="TerrainSurfaceMesh"
	_collision_body.add_child(_surface_mesh)
	for side in RAMP_SIDES:
		var ramp_mesh := MeshInstance3D.new()
		ramp_mesh.name="TerrainRampVisual_"+side.capitalize()
		var plane := PlaneMesh.new()
		plane.size=Vector2(EDGE_RAMP_RUN,PATCH_SIZE)
		ramp_mesh.mesh=plane
		_collision_body.add_child(ramp_mesh)
		_ramp_visuals[side]=ramp_mesh

## A thin BoxShape3D slab gives the static terrain ramp a stable top face at every
## height, including the shallow 5 cm step that proved numerically fragile as a convex wedge.
func _configure_ramp_collision(ramp: CollisionShape3D,side: String,height: float) -> void:
	var angle: float = atan(height/EDGE_RAMP_RUN)
	var slope_length: float = sqrt(EDGE_RAMP_RUN*EDGE_RAMP_RUN+height*height)
	var half: float = PATCH_SIZE*0.5
	var offset: float = half+EDGE_RAMP_RUN*0.5
	var half_thickness: float = EDGE_RAMP_COLLISION_THICKNESS*0.5
	var box := BoxShape3D.new()
	box.size=Vector3(slope_length,EDGE_RAMP_COLLISION_THICKNESS,PATCH_SIZE) if side == "east" or side == "west" else Vector3(PATCH_SIZE,EDGE_RAMP_COLLISION_THICKNESS,slope_length)
	ramp.shape=box
	match side:
		"east":
			ramp.rotation=Vector3(0.0,0.0,-angle)
			ramp.position=Vector3(offset-sin(angle)*half_thickness,height*0.5-cos(angle)*half_thickness,0.0)
		"west":
			ramp.rotation=Vector3(0.0,0.0,angle)
			ramp.position=Vector3(-offset+sin(angle)*half_thickness,height*0.5-cos(angle)*half_thickness,0.0)
		"north":
			ramp.rotation=Vector3(-angle,0.0,0.0)
			ramp.position=Vector3(0.0,height*0.5-cos(angle)*half_thickness,-offset+sin(angle)*half_thickness)
		"south":
			ramp.rotation=Vector3(angle,0.0,0.0)
			ramp.position=Vector3(0.0,height*0.5-cos(angle)*half_thickness,offset-sin(angle)*half_thickness)

func _refresh_geometry() -> void:
	var height: float = get_top_height()
	var box_height: float = maxf(0.05,height)
	var box := BoxShape3D.new()
	box.size=Vector3(PATCH_SIZE,box_height,PATCH_SIZE)
	_collision_shape.shape=box
	_collision_shape.position=Vector3(0.0,box_height*0.5,0.0)
	for side in RAMP_SIDES:
		var ramp_collision: CollisionShape3D = _ramp_collisions.get(side) as CollisionShape3D
		if ramp_collision != null:
			_configure_ramp_collision(ramp_collision,side,height)
	if _surface_mesh == null or not is_instance_valid(_surface_mesh):
		return
	var material := StandardMaterial3D.new()
	match _surface_type:
		"soil": material.albedo_color=Color("#8b6848")
		"rock": material.albedo_color=Color("#78828b")
		"metal": material.albedo_color=Color("#39a6b8")
	var mesh := BoxMesh.new()
	mesh.size=Vector3(PATCH_SIZE,box_height,PATCH_SIZE)
	_surface_mesh.mesh=mesh
	_surface_mesh.position=_collision_shape.position
	_surface_mesh.material_override=material
	var angle: float = atan(height/EDGE_RAMP_RUN)
	var slope_length: float = sqrt(EDGE_RAMP_RUN*EDGE_RAMP_RUN+height*height)
	var half: float = PATCH_SIZE*0.5
	var offset: float = half+EDGE_RAMP_RUN*0.5
	for side in RAMP_SIDES:
		var ramp_visual: MeshInstance3D = _ramp_visuals.get(side) as MeshInstance3D
		if ramp_visual == null:
			continue
		ramp_visual.material_override=material
		var plane := ramp_visual.mesh as PlaneMesh
		if plane != null:
			plane.size=Vector2(slope_length,PATCH_SIZE) if side == "east" or side == "west" else Vector2(PATCH_SIZE,slope_length)
		match side:
			"east":
				ramp_visual.position=Vector3(offset,height*0.5,0.0)
				ramp_visual.rotation=Vector3(0.0,0.0,-angle)
			"west":
				ramp_visual.position=Vector3(-offset,height*0.5,0.0)
				ramp_visual.rotation=Vector3(0.0,0.0,angle)
			"north":
				ramp_visual.position=Vector3(0.0,height*0.5,-offset)
				ramp_visual.rotation=Vector3(-angle,0.0,0.0)
			"south":
				ramp_visual.position=Vector3(0.0,height*0.5,offset)
				ramp_visual.rotation=Vector3(angle,0.0,0.0)

func get_edge_ramp_profile() -> Dictionary:
	var rise: float = get_top_height()
	return {
		"run":EDGE_RAMP_RUN,
		"rise":rise,
		"slope_length":sqrt(EDGE_RAMP_RUN*EDGE_RAMP_RUN+rise*rise),
		"collision_thickness":EDGE_RAMP_COLLISION_THICKNESS,
		"sides":RAMP_SIDES.duplicate()
	}
