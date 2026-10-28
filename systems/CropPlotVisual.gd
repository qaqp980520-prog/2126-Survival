extends Node3D
class_name CropPlotVisual

## Lightweight surface plot visual. CropRegistry remains the authoritative data source.
const WATER_AMOUNT := 35.0
const GROWTH_TICK_SECONDS := 120.0
const DRY_THRESHOLD := 30.0

var controller: Node
var stable_id: String = ""
var crop_id: String = "wheat"
var plot_index: int = 1
var status_text: String = ""
var _built := false
var _stem: MeshInstance3D
var _fruit: MeshInstance3D
var _marker: MeshInstance3D
var _stem_mesh: CylinderMesh
var _fruit_material: StandardMaterial3D

func _ready() -> void:
    _build_visuals()
    refresh()

func configure(value: Node, id: String, kind: String, index: int) -> void:
    controller = value
    stable_id = id
    crop_id = kind
    plot_index = index
    _build_visuals()
    refresh()

func _build_visuals() -> void:
    if _built:
        return
    _built = true

    var soil := MeshInstance3D.new()
    soil.name = "SoilBed"
    var soil_mesh := BoxMesh.new()
    soil_mesh.size = Vector3(1.4, 0.2, 1.4)
    soil.mesh = soil_mesh
    soil.position = Vector3(0.0, 0.1, 0.0)
    var soil_material := StandardMaterial3D.new()
    soil_material.albedo_color = Color("#503c2d")
    soil_material.roughness = 1.0
    soil.material_override = soil_material
    add_child(soil)

    _marker = MeshInstance3D.new()
    _marker.name = "CropTypeMarker"
    var marker_mesh := BoxMesh.new()
    marker_mesh.size = Vector3(0.22, 0.22, 0.22)
    _marker.mesh = marker_mesh
    _marker.position = Vector3(-0.48, 0.31, -0.48)
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = _crop_color()
    marker_material.roughness = 0.7
    _marker.material_override = marker_material
    add_child(_marker)

    _stem = MeshInstance3D.new()
    _stem.name = "CropStem"
    _stem_mesh = CylinderMesh.new()
    _stem_mesh.top_radius = 0.055
    _stem_mesh.bottom_radius = 0.11
    _stem_mesh.height = 1.0
    _stem.mesh = _stem_mesh
    var stem_material := StandardMaterial3D.new()
    stem_material.albedo_color = Color("#64a75a")
    stem_material.roughness = 0.9
    _stem.material_override = stem_material
    add_child(_stem)

    _fruit = MeshInstance3D.new()
    _fruit.name = "CropFruit"
    var fruit_mesh := SphereMesh.new()
    fruit_mesh.radius = 0.18
    fruit_mesh.height = 0.36
    _fruit.mesh = fruit_mesh
    _fruit_material = StandardMaterial3D.new()
    _fruit_material.albedo_color = _crop_color()
    _fruit_material.roughness = 0.65
    _fruit.material_override = _fruit_material
    add_child(_fruit)

func interact(now_unix: int = -1) -> Dictionary:
    if controller == null or stable_id.is_empty():
        return _result(false, "unbound", "This crop plot is not connected to the world.")
    var timestamp: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
    var record: Dictionary = controller.call("get_crop", stable_id)
    var action := ""
    var ok := false

    if record.is_empty():
        ok = bool(controller.call("plant_crop", stable_id, crop_id, 60.0, timestamp))
        action = "planted"
    elif int(record.get("growth_stage", 0)) >= 4 and float(record.get("growth_progress", 0.0)) >= 1.0:
        var receipt: Dictionary = controller.call("harvest_crop", stable_id, timestamp)
        ok = bool(receipt.get("ok", false))
        action = "harvested"
    elif float(record.get("moisture", 0.0)) < DRY_THRESHOLD:
        ok = bool(controller.call("water_crop", stable_id, WATER_AMOUNT, timestamp))
        action = "watered"
    else:
        ok = bool(controller.call("advance_crop", stable_id, GROWTH_TICK_SECONDS, timestamp))
        action = "advanced"

    refresh()
    if not ok:
        return _result(false, "operation_rejected", "Action rejected; the crop record was not changed.")
    var message := ""
    match action:
        "planted":
            message = "Planted %s in plot %02d." % [crop_id, plot_index]
        "watered":
            message = "Watered plot %02d. Press E again to advance growth." % plot_index
        "advanced":
            message = "Advanced plot %02d by one bounded growth interval." % plot_index
        "harvested":
            message = "Harvested plot %02d; the next crop cycle is ready." % plot_index
    return _result(true, action, message)

func refresh() -> void:
    if not _built or _stem == null or _fruit == null:
        return
    var record: Dictionary = {}
    if controller != null and not stable_id.is_empty():
        record = controller.call("get_crop", stable_id)
    if record.is_empty():
        _stem.visible = false
        _fruit.visible = false
        status_text = "PLOT %02d | EMPTY | E: PLANT" % plot_index
        return

    var stage := int(record.get("growth_stage", 0))
    var moisture := float(record.get("moisture", 0.0))
    var mature := stage >= 4 and float(record.get("growth_progress", 0.0)) >= 1.0
    var height_scale := 0.25 + float(stage) * 0.18
    _stem.visible = true
    _stem.scale = Vector3(1.0, height_scale, 1.0)
    _stem.position = Vector3(0.0, 0.2 + height_scale * 0.5, 0.0)
    _fruit.visible = mature
    _fruit.position = Vector3(0.0, 0.2 + height_scale + 0.16, 0.0)
    status_text = "PLOT %02d | %s %d/4 | H2O %.0f | %s" % [
        plot_index, crop_id.to_upper(), stage, moisture,
        "E: HARVEST" if mature else ("E: WATER" if moisture < DRY_THRESHOLD else "E: GROW")
    ]

func _crop_color() -> Color:
    match crop_id:
        "tomato":
            return Color("#e85d55")
        "carrot":
            return Color("#f0a34a")
        "corn":
            return Color("#f0d35a")
        "potato":
            return Color("#c4a47b")
        _:
            return Color("#d8d88a")

func _result(ok: bool, action: String, message: String) -> Dictionary:
    return {"ok": ok, "action": action, "message": message}
