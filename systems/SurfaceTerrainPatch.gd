extends Node3D
class_name SurfaceTerrainPatch

signal terrain_state_changed(patch: Node3D)

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
var _collision_segments: Dictionary = {}
var _surface_segments: Dictionary = {}
var _shared_transition_sides: Dictionary = {}

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
	terrain_state_changed.emit(self)
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
	terrain_state_changed.emit(self)
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
	for x_index in range(3):
		for z_index in range(3):
			var segment := CollisionShape3D.new()
			segment.name = "TerrainCollisionSegment_X%d_Z%d" % [x_index, z_index]
			var segment_box := BoxShape3D.new()
			segment.shape = segment_box
			segment.disabled = true
			_collision_body.add_child(segment)
			_collision_segments["%d:%d" % [x_index, z_index]] = segment
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
	var initial_box_height: float = maxf(0.05, get_top_height())
	_surface_mesh=MeshInstance3D.new()
	_surface_mesh.name="TerrainSurfaceMesh"
	var initial_surface_mesh := BoxMesh.new()
	initial_surface_mesh.size = Vector3(PATCH_SIZE, initial_box_height, PATCH_SIZE)
	_surface_mesh.mesh = initial_surface_mesh
	_collision_body.add_child(_surface_mesh)
	for x_index in range(3):
		for z_index in range(3):
			var segment := MeshInstance3D.new()
			segment.name = "TerrainSurfaceSegment_X%d_Z%d" % [x_index, z_index]
			var initial_segment_mesh := BoxMesh.new()
			initial_segment_mesh.size = Vector3(0.1, initial_box_height, 0.1)
			segment.mesh = initial_segment_mesh
			segment.visible = false
			_collision_body.add_child(segment)
			_surface_segments["%d:%d" % [x_index, z_index]] = segment
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
	_refresh_segment_geometry(box_height)
	for side in RAMP_SIDES:
		var ramp_collision: CollisionShape3D = _ramp_collisions.get(side) as CollisionShape3D
		if ramp_collision != null:
			_configure_ramp_collision(ramp_collision,side,height)
	for side in RAMP_SIDES:
		_refresh_edge_ramp_state(side)
	_refresh_collision_segmentation()
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
	_refresh_surface_segment_visuals(box_height, material)
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

func _segment_widths() -> Array[float]:
	return [EDGE_RAMP_RUN, PATCH_SIZE - EDGE_RAMP_RUN * 2.0, EDGE_RAMP_RUN]

func _segment_centers() -> Array[float]:
	var widths: Array[float] = _segment_widths()
	return [
		-PATCH_SIZE * 0.5 + widths[0] * 0.5,
		0.0,
		PATCH_SIZE * 0.5 - widths[2] * 0.5
	]

func _refresh_segment_geometry(box_height: float) -> void:
	var widths: Array[float] = _segment_widths()
	var centers: Array[float] = _segment_centers()
	for x_index in range(3):
		for z_index in range(3):
			var key: String = "%d:%d" % [x_index, z_index]
			var segment: CollisionShape3D = _collision_segments.get(key) as CollisionShape3D
			if segment != null:
				var box := segment.shape as BoxShape3D
				if box == null:
					box = BoxShape3D.new()
					segment.shape = box
				box.size = Vector3(widths[x_index], box_height, widths[z_index])
				segment.position = Vector3(centers[x_index], box_height * 0.5, centers[z_index])

func _refresh_surface_segment_visuals(box_height: float, material: StandardMaterial3D) -> void:
	var widths: Array[float] = _segment_widths()
	var centers: Array[float] = _segment_centers()
	for x_index in range(3):
		for z_index in range(3):
			var key: String = "%d:%d" % [x_index, z_index]
			var segment: MeshInstance3D = _surface_segments.get(key) as MeshInstance3D
			if segment == null:
				continue
			var mesh := BoxMesh.new()
			mesh.size = Vector3(widths[x_index], box_height, widths[z_index])
			segment.mesh = mesh
			segment.position = Vector3(centers[x_index], box_height * 0.5, centers[z_index])
			segment.material_override = material

func is_surface_base_visual_visible() -> bool:
	return _get_active_shared_transition_sides().is_empty()

func is_surface_segment_visual_visible(x_index: int, z_index: int) -> bool:
	return _is_surface_segment_visual_visible_for_sides(x_index, z_index, _get_active_shared_transition_sides())

func _get_active_shared_transition_sides() -> Dictionary:
	var active_sides: Dictionary = {}
	for side in _shared_transition_sides.keys():
		if bool(_shared_transition_sides[side]):
			active_sides[str(side)] = true
	return active_sides

func _is_surface_segment_visual_visible_for_sides(x_index: int, z_index: int, active_sides: Dictionary) -> bool:
	if x_index < 0 or x_index > 2 or z_index < 0 or z_index > 2 or active_sides.is_empty():
		return false
	var cut: bool = (
		(active_sides.has("west") and x_index == 0)
		or (active_sides.has("east") and x_index == 2)
		or (active_sides.has("north") and z_index == 0)
		or (active_sides.has("south") and z_index == 2)
	)
	return not cut

func set_shared_transition_active(side: String, active: bool) -> bool:
	if not RAMP_SIDES.has(side):
		return false
	if active:
		var policy: Dictionary = get_edge_policy(side)
		if not bool(policy.get("valid", false)) or not ["local_higher", "neighbor_higher"].has(str(policy.get("mode", ""))):
			return false
		_shared_transition_sides[side] = true
	else:
		_shared_transition_sides.erase(side)
	_refresh_collision_segmentation()
	return true

func is_shared_transition_active(side: String) -> bool:
	return RAMP_SIDES.has(side) and bool(_shared_transition_sides.get(side, false))

func _refresh_collision_segmentation() -> void:
	var active_sides: Dictionary = _get_active_shared_transition_sides()
	var has_shared_transition: bool = not active_sides.is_empty()
	if _collision_shape != null:
		_collision_shape.disabled = has_shared_transition
	if _surface_mesh != null and is_instance_valid(_surface_mesh):
		_surface_mesh.visible = not has_shared_transition
	for x_index in range(3):
		for z_index in range(3):
			var cut: bool = not _is_surface_segment_visual_visible_for_sides(x_index, z_index, active_sides) and has_shared_transition
			var key: String = "%d:%d" % [x_index, z_index]
			var collision_segment: CollisionShape3D = _collision_segments.get(key) as CollisionShape3D
			if collision_segment != null:
				collision_segment.disabled = not has_shared_transition or cut
			var surface_segment: MeshInstance3D = _surface_segments.get(key) as MeshInstance3D
			if surface_segment != null:
				surface_segment.visible = _is_surface_segment_visual_visible_for_sides(x_index, z_index, active_sides)

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
	_shared_transition_sides.erase(side)
	_refresh_edge_ramp_state(side)
	_refresh_collision_segmentation()

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
