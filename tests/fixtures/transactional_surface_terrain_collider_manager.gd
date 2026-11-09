extends "res://systems/SurfaceTerrainTransitionColliderManager.gd"

var last_staged_edge_ref: WeakRef
var last_staged_corner_ref: WeakRef


func _stage_edge(edge_key: String, edge: Dictionary, corner_junctions: Array = [], reuse_signature: Array = []) -> Dictionary:
    var staged: Dictionary = super._stage_edge(edge_key, edge, corner_junctions, reuse_signature)
    var body: StaticBody3D = staged.get("body") as StaticBody3D
    if is_instance_valid(body):
        last_staged_edge_ref = weakref(body)
    return staged


func _stage_corner_cap(cap_key: String, spec: Dictionary, corner_entry: Dictionary, reuse_signature: Array = []) -> Dictionary:
    var staged: Dictionary = super._stage_corner_cap(cap_key, spec, corner_entry, reuse_signature)
    var body: StaticBody3D = staged.get("body") as StaticBody3D
    if is_instance_valid(body):
        last_staged_corner_ref = weakref(body)
    return staged
