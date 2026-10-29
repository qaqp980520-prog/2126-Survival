extends Node3D
class_name WorldObjectStatefulProp

## Small interactable prop used to exercise the stable-ID world-object lifecycle.
## The registry stores only the primitive state returned by get_world_object_state().
const MAX_LOOT: int = 2

var opened: bool = false
var loot_remaining: int = MAX_LOOT
var _body_mesh: MeshInstance3D
var _lid_mesh: MeshInstance3D

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_build_visuals()
	_refresh_visuals()

func get_world_object_state() -> Dictionary:
	return {
		"opened": opened,
		"loot_remaining": loot_remaining
	}

func validate_world_object_state(state: Dictionary) -> bool:
	if state.size() != 2 or not state.has("opened") or not state.has("loot_remaining"):
		return false
	var opened_value: Variant = state.get("opened", null)
	var loot_value: Variant = state.get("loot_remaining", null)
	if not (opened_value is bool) or not (loot_value is int):
		return false
	if int(loot_value) < 0 or int(loot_value) > MAX_LOOT:
		return false
	# A never-opened crate cannot already have been marked open with its full contents.
	return not (bool(opened_value) and int(loot_value) == MAX_LOOT)

func apply_world_object_state(state: Dictionary) -> bool:
	if not validate_world_object_state(state):
		return false
	var opened_value: bool = bool(state["opened"])
	var loot_value: int = int(state["loot_remaining"])
	opened = opened_value
	loot_remaining = int(loot_value)
	_refresh_visuals()
	return true

func interact_with_inventory(inventory_bridge: Node) -> Dictionary:
	if loot_remaining <= 0:
		return {"ok": false, "reason": "empty", "remaining": 0}
	if inventory_bridge == null or not is_instance_valid(inventory_bridge):
		return {"ok": false, "reason": "inventory_unavailable", "remaining": loot_remaining}
	for method_name in ["collect_world_item", "serialize_inventory", "restore_inventory"]:
		if not inventory_bridge.has_method(method_name):
			return {"ok": false, "reason": "inventory_contract", "remaining": loot_remaining}
	var inventory_snapshot: Variant = inventory_bridge.call("serialize_inventory")
	if not (inventory_snapshot is Dictionary) or inventory_snapshot.is_empty():
		return {"ok": false, "reason": "inventory_snapshot_invalid", "remaining": loot_remaining}
	if not bool(inventory_bridge.call("collect_world_item", "iron_ore", 1)):
		return {"ok": false, "reason": "inventory_rejected", "remaining": loot_remaining}
	var next_state: Dictionary = get_world_object_state()
	next_state["opened"] = true
	next_state["loot_remaining"] = loot_remaining - 1
	if not apply_world_object_state(next_state):
		var rollback_ok: bool = bool(inventory_bridge.call("restore_inventory", inventory_snapshot))
		if not rollback_ok:
			push_error("Salvage crate failed to roll back inventory after rejecting its state transition.")
		return {"ok": false, "reason": "state_rejected", "remaining": loot_remaining}
	return {
		"ok": true,
		"reason": "collected",
		"item_id": "iron_ore",
		"amount": 1,
		"remaining": loot_remaining
	}

func interact() -> bool:
	if loot_remaining <= 0:
		return false
	opened = true
	loot_remaining -= 1
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
	_lid_mesh.rotation.x = -0.95 if opened else 0.0
	_lid_mesh.position = Vector3(0.0, 0.72, -0.28 if opened else 0.0)
	if _body_mesh != null and is_instance_valid(_body_mesh):
		var material := _body_mesh.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("#6d5038") if loot_remaining == 0 else Color("#8c633e")
