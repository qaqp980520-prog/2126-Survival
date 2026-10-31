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
const EdgePolicyScript = preload("res://systems/SurfaceTerrainEdgePolicy.gd")

var _height_level: int = 0
var _surface_type: String = "soil"
var _revision: int = 0
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _surface_mesh: MeshInstance3D
var _interaction_area: Area3D
var _ramp_collisions: Dictionary = {}
var _ramp_visuals: Dictionary = {}
var _neighbor_edge_states: Dictionary = {}
var _neighbor_patches: Dictionary = {}

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
	_refresh_bound_neighbors()
	return true

func cycle_terrain_edit() -> Dictionary:
	if _revision >= MAX_REVISION:
		return {"ok":false,"reason":"revision_limit","state":get_world_object_state()}
	var surface_index: int = SURFACE_TYPES.find(_surface_type)
	_height_level=(_height_level+1) % (MAX_HEIGHT_LEVEL+1)
	_surface_type=SURFACE_TYPES[posmod(surface_index+1,SURFACE_TYPES.size())]
	_revision+=1
	_refresh_geometry()
	_refresh_bound_neighbors()
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
		var ramp_body := StaticBody3D.new()
		ramp_body.name="TerrainRampBody_"+side.capitalize()
		ramp_body.collision_layer=1
		ramp_body.collision_mask=0
		var ramp := CollisionShape3D.new()
		ramp.name="TerrainRampCollision_"+side.capitalize()
		_configure_ramp_collision(ramp,side,get_top_height())
		ramp_body.add_child(ramp)
		add_child(ramp_body)
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
	for side in RAMP_SIDES:
		_refresh_edge_ramp_state(side)
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
		"patch_size":PATCH_SIZE,
		"run":EDGE_RAMP_RUN,
		"rise":rise,
		"slope_length":sqrt(EDGE_RAMP_RUN*EDGE_RAMP_RUN+rise*rise),
		"collision_thickness":EDGE_RAMP_COLLISION_THICKNESS,
		"sides":RAMP_SIDES.duplicate()
	}

func bind_neighbor_patch(side: String, neighbor_patch: Node3D) -> bool:
	if not RAMP_SIDES.has(side) or not is_instance_valid(neighbor_patch) or neighbor_patch == self:
		return false
	if not neighbor_patch.is_inside_tree() or neighbor_patch.is_queued_for_deletion():
		return false
	if not neighbor_patch.has_method("get_world_object_state") or not neighbor_patch.has_method("set_neighbor_edge_state"):
		return false
	var expected_offset := Vector3.ZERO
	match side:
		"east":
			expected_offset = Vector3(PATCH_SIZE, 0.0, 0.0)
		"west":
			expected_offset = Vector3(-PATCH_SIZE, 0.0, 0.0)
		"north":
			expected_offset = Vector3(0.0, 0.0, -PATCH_SIZE)
		"south":
			expected_offset = Vector3(0.0, 0.0, PATCH_SIZE)
	var actual_offset: Vector3 = neighbor_patch.global_position - global_position
	if absf(actual_offset.x - expected_offset.x) > 0.01 or absf(actual_offset.y) > 0.01 or absf(actual_offset.z - expected_offset.z) > 0.01:
		return false
	var neighbor_state: Variant = neighbor_patch.call("get_world_object_state")
	if not (neighbor_state is Dictionary) or not set_neighbor_edge_state(side, neighbor_state):
		return false
	_neighbor_patches[side] = weakref(neighbor_patch)
	return true

func set_neighbor_edge_state(side: String, neighbor_state: Dictionary) -> bool:
	if not RAMP_SIDES.has(side) or not validate_world_object_state(neighbor_state):
		return false
	_neighbor_edge_states[side] = neighbor_state.duplicate(true)
	_refresh_edge_ramp_state(side)
	return true

func clear_neighbor_edge_state(side: String) -> bool:
	if not RAMP_SIDES.has(side):
		return false
	var reference: WeakRef = _neighbor_patches.get(side) as WeakRef
	var neighbor: Node3D = null
	if reference != null:
		neighbor = reference.get_ref() as Node3D
	_clear_neighbor_edge_state_local(side)
	if is_instance_valid(neighbor) and neighbor.has_method("_clear_neighbor_edge_state_local"):
		neighbor.call("_clear_neighbor_edge_state_local", _opposite_side(side))
	return true

func _clear_neighbor_edge_state_local(side: String) -> void:
	_neighbor_patches.erase(side)
	_neighbor_edge_states.erase(side)
	_refresh_edge_ramp_state(side)

func _refresh_bound_neighbors() -> void:
	var local_state: Dictionary = get_world_object_state()
	for side in RAMP_SIDES:
		var reference: WeakRef = _neighbor_patches.get(side) as WeakRef
		if reference == null:
			continue
		var neighbor: Node3D = reference.get_ref() as Node3D
		if not is_instance_valid(neighbor) or neighbor.is_queued_for_deletion() or not neighbor.is_inside_tree():
			_clear_neighbor_edge_state_local(side)
			continue
		if not neighbor.has_method("set_neighbor_edge_state") or not bool(neighbor.call("set_neighbor_edge_state", _opposite_side(side), local_state)):
			_clear_neighbor_edge_state_local(side)

func _opposite_side(side: String) -> String:
	match side:
		"east": return "west"
		"west": return "east"
		"north": return "south"
		"south": return "north"
		_: return ""

func get_edge_policy(side: String) -> Dictionary:
	if not RAMP_SIDES.has(side):
		return {"valid": false, "mode": "invalid", "reason": "invalid_side", "ramp_enabled": false}
	var neighbor_state: Dictionary = _neighbor_edge_states.get(side, {})
	return EdgePolicyScript.classify_edge(get_world_object_state(), neighbor_state)

func _refresh_edge_ramp_state(side: String) -> void:
	var policy: Dictionary = get_edge_policy(side)
	var ramp_enabled: bool = bool(policy.get("valid", false)) and bool(policy.get("ramp_enabled", false))
	var ramp_body := get_node_or_null("TerrainRampBody_" + side.capitalize()) as StaticBody3D
	if ramp_body != null:
		ramp_body.collision_layer = 1 if ramp_enabled else 0
		var collision := ramp_body.get_node_or_null("TerrainRampCollision_" + side.capitalize()) as CollisionShape3D
		if collision != null:
			collision.disabled = not ramp_enabled
	var visual: MeshInstance3D = _ramp_visuals.get(side) as MeshInstance3D
	if visual != null:
		visual.visible = ramp_enabled

