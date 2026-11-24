extends "res://prototypes/BackroomsPortalPlayground.gd"

func _create_window_entity(cell_root: Node3D, cell: Vector2i) -> void:
	_record_probe(cell_root, "window", cell)

func _create_smiler_entity(cell_root: Node3D, cell: Vector2i) -> void:
	_record_probe(cell_root, "smiler", cell)

func _create_hound_entity(cell_root: Node3D, cell: Vector2i) -> void:
	_record_probe(cell_root, "hound", cell)

func _create_skin_stealer_entity(cell_root: Node3D, cell: Vector2i) -> void:
	_record_probe(cell_root, "skin_stealer", cell)

func _create_clump_entity(cell_root: Node3D, cell: Vector2i) -> void:
	_record_probe(cell_root, "clump", cell)

func _create_faceling_entity(cell_root: Node3D, cell: Vector2i) -> void:
	_record_probe(cell_root, "faceling", cell)

func _record_probe(cell_root: Node3D, entity_id: String, cell: Vector2i) -> void:
	var marker := Node3D.new()
	marker.name = "Probe_" + entity_id
	marker.set_meta("backrooms_entity_id", entity_id)
	marker.set_meta("spawn_cell", cell)
	cell_root.add_child(marker)
