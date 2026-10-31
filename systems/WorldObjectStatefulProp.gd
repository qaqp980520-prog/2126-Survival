extends Node3D
class_name WorldObjectStatefulProp

## Small interactable prop used to exercise the stable-ID world-object lifecycle.
## The registry stores only the primitive state returned by get_world_object_state().
const MineralCatalogScript = preload("res://systems/MineralCatalog.gd")
const MAX_LOOT: int = 2
const DEFAULT_LOOT_ITEM_ID: String = "iron_ore"

var _opened: bool = false
var _loot_remaining: int = MAX_LOOT
var _loot_item_id: String = DEFAULT_LOOT_ITEM_ID

# Read-only compatibility properties: existing callers may read these names,
# but all state changes must go through the validated methods below.
var opened: bool:
	get:
		return _opened

var loot_remaining: int:
	get:
		return _loot_remaining

var loot_item_id: String:
	get:
		return _loot_item_id

var _inventory_interaction_in_progress: bool = false
var _body_mesh: MeshInstance3D
var _lid_mesh: MeshInstance3D

func _ready() -> void:
	_build_interaction_area()
	if DisplayServer.get_name() != "headless":
		_build_visuals()
	_refresh_visuals()

func _build_interaction_area() -> void:
	if get_node_or_null("InteractionArea") != null:
		return
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.55, 1.4, 1.25)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.68, 0.0)
	area.add_child(collision)
	add_child(area)

func get_world_object_state() -> Dictionary:
	return {
		"opened": _opened,
		"loot_remaining": _loot_remaining,
		"loot_item_id": _loot_item_id
	}


func validate_world_object_state(state: Dictionary) -> bool:
	if not state.has("opened") or not state.has("loot_remaining"):
		return false
	if state.size() != 2 and state.size() != 3:
		return false
	if state.size() == 3 and not state.has("loot_item_id"):
		return false
	var opened_value: Variant = state.get("opened", null)
	var loot_value: Variant = state.get("loot_remaining", null)
	if not (opened_value is bool) or not (loot_value is int):
		return false
	if int(loot_value) < 0 or int(loot_value) > MAX_LOOT:
		return false
	# Older schema-1 records contain only opened/loot_remaining. Keep accepting them.
	if state.has("loot_item_id"):
		var item_value: Variant = state.get("loot_item_id", null)
		if not (item_value is String) or not MineralCatalogScript.has_mineral(str(item_value)):
			return false
	# A closed crate must be full; any consumed loot requires the opened state.
	return bool(opened_value) == (int(loot_value) < MAX_LOOT)


func apply_world_object_state(state: Dictionary) -> bool:
	if _inventory_interaction_in_progress or not validate_world_object_state(state):
		return false
	var opened_value: bool = bool(state["opened"])
	var loot_value: int = int(state["loot_remaining"])
	var item_value: String = str(state.get("loot_item_id", _loot_item_id))
	if not MineralCatalogScript.has_mineral(item_value):
		return false
	_opened = opened_value
	_loot_remaining = loot_value
	_loot_item_id = item_value
	_refresh_visuals()
	return true


func set_loot_item(item_id: String) -> bool:
	if _inventory_interaction_in_progress or _opened or _loot_remaining != MAX_LOOT or not MineralCatalogScript.has_mineral(item_id):
		return false
	_loot_item_id = item_id
	return true


func interact_with_inventory(inventory_bridge: Node) -> Dictionary:
	if _inventory_interaction_in_progress:
		return {"ok": false, "reason": "interaction_in_progress", "item_id": _loot_item_id, "remaining": _loot_remaining}
	_inventory_interaction_in_progress = true
	var result: Dictionary = _interact_with_inventory_transaction(inventory_bridge)
	_inventory_interaction_in_progress = false
	return result


func _interact_with_inventory_transaction(inventory_bridge: Node) -> Dictionary:
	if _loot_remaining <= 0:
		return {"ok": false, "reason": "empty", "item_id": _loot_item_id, "remaining": 0}
	if inventory_bridge == null or not is_instance_valid(inventory_bridge):
		return {"ok": false, "reason": "inventory_unavailable", "item_id": _loot_item_id, "remaining": _loot_remaining}
	for method_name in ["collect_world_item", "serialize_inventory", "restore_inventory"]:
		if not inventory_bridge.has_method(method_name):
			return {"ok": false, "reason": "inventory_contract", "item_id": _loot_item_id, "remaining": _loot_remaining}
	var inventory_snapshot: Variant = inventory_bridge.call("serialize_inventory")
	if not (inventory_snapshot is Dictionary) or inventory_snapshot.is_empty():
		return {"ok": false, "reason": "inventory_snapshot_invalid", "item_id": _loot_item_id, "remaining": _loot_remaining}
	if not bool(inventory_bridge.call("collect_world_item", _loot_item_id, 1)):
		# Treat the bridge call as an untrusted transaction boundary: an adapter may
		# mutate before returning false. Restore the pre-call snapshot before leaving.
		var rejection_rollback_ok: bool = bool(inventory_bridge.call("restore_inventory", inventory_snapshot))
		if not rejection_rollback_ok:
			return {"ok": false, "reason": "inventory_rollback_failed", "item_id": _loot_item_id, "remaining": _loot_remaining}
		return {"ok": false, "reason": "inventory_rejected", "item_id": _loot_item_id, "remaining": _loot_remaining}
	var next_state: Dictionary = get_world_object_state()
	next_state["opened"] = true
	next_state["loot_remaining"] = _loot_remaining - 1
	if not validate_world_object_state(next_state):
		var rollback_ok: bool = bool(inventory_bridge.call("restore_inventory", inventory_snapshot))
		if not rollback_ok:
			push_error("Salvage crate failed to roll back inventory after rejecting its state transition.")
		return {"ok": false, "reason": "state_rejected", "item_id": _loot_item_id, "remaining": _loot_remaining}
	# Commit internally while public state-mutating APIs remain locked against bridge callbacks.
	_opened = bool(next_state["opened"])
	_loot_remaining = int(next_state["loot_remaining"])
	_loot_item_id = str(next_state.get("loot_item_id", _loot_item_id))
	_refresh_visuals()
	return {
		"ok": true,
		"reason": "collected",
		"item_id": _loot_item_id,
		"amount": 1,
		"remaining": _loot_remaining
	}


func interact() -> bool:
	if _inventory_interaction_in_progress:
		return false
	if _loot_remaining <= 0:
		return false
	_opened = true
	_loot_remaining -= 1
	_refresh_visuals()
	return true

func _build_visuals() -> void:
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "CrateBody"
	var body := BoxMesh.new()
	body.size = Vector3(1.1, 0.65, 0.8)
	_body_mesh.mesh = body
	_body_mesh.position = Vector3(0.0, 0.34, 0.0)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#8c633e")
	body_material.metallic = 0.18
	_body_mesh.material_override = body_material
	add_child(_body_mesh)

	_lid_mesh = MeshInstance3D.new()
	_lid_mesh.name = "CrateLid"
	var lid := BoxMesh.new()
	lid.size = Vector3(1.16, 0.14, 0.86)
	_lid_mesh.mesh = lid
	_lid_mesh.position = Vector3(0.0, 0.72, 0.0)
	var lid_material := StandardMaterial3D.new()
	lid_material.albedo_color = Color("#d49a50")
	lid_material.metallic = 0.22
	_lid_mesh.material_override = lid_material
	add_child(_lid_mesh)

func _refresh_visuals() -> void:
	if _lid_mesh == null or not is_instance_valid(_lid_mesh):
		return
	_lid_mesh.rotation.x = -0.95 if _opened else 0.0
	_lid_mesh.position = Vector3(0.0, 0.72, -0.28 if _opened else 0.0)
	if _body_mesh != null and is_instance_valid(_body_mesh):
		var material := _body_mesh.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("#6d5038") if _loot_remaining == 0 else Color("#8c633e")
