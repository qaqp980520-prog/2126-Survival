extends RefCounted
class_name BackroomsCellNavigationFactory

## Builds one bounded navigation region per loaded maze cell and one agent per mobile entity.
## Cell regions deliberately do not connect automatically; the loaded-cell route planner
## and transactional owner transfer remain the only cross-cell traversal authority.
const FACTORY_VERSION: int = 1
const NAVIGATION_LAYER: int = 1
const CELL_EDGE_INSET: float = 0.65
const NAVIGATION_SURFACE_Y: float = 0.02
const MIN_CELL_SIZE: float = 1.4
const TARGET_POSITION_UPDATE_DISTANCE: float = 0.25
const MIN_TARGET_DESIRED_DISTANCE: float = 0.5
const MOBILE_ENTITY_RADII := {
	"smiler": 0.30,
	"hound": 0.32,
	"skin_stealer": 0.30,
	"faceling": 0.28,
	"duller": 0.30,
	"deathmoth": 0.38
}

static func is_mobile_entity(entity_id: String) -> bool:
	return MOBILE_ENTITY_RADII.has(entity_id)

static func create_cell_region(cell_size: float) -> NavigationRegion3D:
	if not is_finite(cell_size) or cell_size < MIN_CELL_SIZE or cell_size > 1024.0:
		return null
	var half_extent: float = cell_size * 0.5 - CELL_EDGE_INSET
	if not is_finite(half_extent) or half_extent <= 0.1:
		return null
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = PackedVector3Array([
		Vector3(-half_extent, NAVIGATION_SURFACE_Y, half_extent),
		Vector3(half_extent, NAVIGATION_SURFACE_Y, half_extent),
		Vector3(half_extent, NAVIGATION_SURFACE_Y, -half_extent),
		Vector3(-half_extent, NAVIGATION_SURFACE_Y, -half_extent)
	])
	navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.name = "CellNavigation"
	region.navigation_mesh = navigation_mesh
	region.navigation_layers = NAVIGATION_LAYER
	region.use_edge_connections = false
	region.enabled = false
	region.set_meta("backrooms_cell_navigation_version", FACTORY_VERSION)
	region.set_meta("backrooms_navigation_half_extent", half_extent)
	return region

static func attach_agent(entity_root: CharacterBody3D, entity_id: String) -> bool:
	if entity_root == null or not is_instance_valid(entity_root):
		return false
	if not is_mobile_entity(entity_id):
		return false
	if entity_root.get_node_or_null("NavigationAnchor") != null:
		return false
	var navigation_anchor := Node3D.new()
	navigation_anchor.name = "NavigationAnchor"
	# NavigationAgent3D is a Node, so its parent Node3D provides the floor-aligned
	# transform while the CharacterBody3D remains at capsule-center height.
	navigation_anchor.position.y = NAVIGATION_SURFACE_Y - entity_root.position.y
	entity_root.add_child(navigation_anchor)
	var agent := NavigationAgent3D.new()
	agent.name = "NavigationAgent"
	agent.navigation_layers = NAVIGATION_LAYER
	agent.radius = float(MOBILE_ENTITY_RADII[entity_id])
	agent.avoidance_enabled = false
	# The central driver clamps each movement step to the current waypoint distance.
	# A tighter 0.2 m acceptance prevents cutting obstacle corners at the 10 Hz cadence.
	agent.path_desired_distance = 0.2
	agent.target_desired_distance = MIN_TARGET_DESIRED_DISTANCE
	navigation_anchor.add_child(agent)
	navigation_anchor.set_meta("backrooms_navigation_anchor_version", FACTORY_VERSION)
	entity_root.set_meta("backrooms_navigation_agent_version", FACTORY_VERSION)
	return true

static func get_agent(entity_root: Node3D) -> NavigationAgent3D:
	if entity_root == null or not is_instance_valid(entity_root):
		return null
	return entity_root.get_node_or_null("NavigationAnchor/NavigationAgent") as NavigationAgent3D

static func set_region_enabled(cell_root: Node3D, enabled: bool) -> bool:
	if cell_root == null or not is_instance_valid(cell_root):
		return false
	var region := cell_root.get_node_or_null("CellNavigation") as NavigationRegion3D
	if region == null:
		return false
	region.enabled = enabled
	return region.enabled == enabled

static func set_agent_target(
	agent: NavigationAgent3D,
	target_position: Vector3,
	desired_distance: float
) -> bool:
	if agent == null or not is_instance_valid(agent) or not agent.is_inside_tree():
		return false
	if not _is_finite_vector3(target_position) or not is_finite(desired_distance) or desired_distance < 0.0:
		return false
	var safe_desired_distance: float = maxf(MIN_TARGET_DESIRED_DISTANCE, desired_distance)
	if absf(agent.target_desired_distance - safe_desired_distance) > 0.01:
		agent.target_desired_distance = safe_desired_distance
	var should_update_target: bool = true
	if agent.has_meta("backrooms_navigation_target_position"):
		var previous_value: Variant = agent.get_meta("backrooms_navigation_target_position")
		if previous_value is Vector3:
			var previous_position: Vector3 = previous_value
			should_update_target = previous_position.distance_to(target_position) > TARGET_POSITION_UPDATE_DISTANCE
	if should_update_target:
		agent.target_position = target_position
		agent.set_meta("backrooms_navigation_target_position", target_position)
	return true

static func get_next_waypoint(agent: NavigationAgent3D) -> Dictionary:
	if agent == null or not is_instance_valid(agent) or not agent.is_inside_tree():
		return {"ok": false, "reason": "navigation_agent_unavailable"}
	# This call advances NavigationAgent3D's internal path cursor. The owning
	# movement scheduler bounds calls to its existing 10 Hz movement cadence.
	var next_position: Vector3 = agent.get_next_path_position()
	if not _is_finite_vector3(next_position):
		return {"ok": false, "reason": "navigation_waypoint_invalid"}
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.is_empty():
		return {"ok": false, "reason": "navigation_path_unavailable"}
	return {
		"ok": true,
		"next_path_position": next_position,
		"path_point_count": path.size(),
		"finished": agent.is_navigation_finished(),
		"target_reachable": agent.is_target_reachable()
	}

static func _is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
