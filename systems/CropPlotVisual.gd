extends Node3D
class_name CropPlotVisual

## Scene-backed plot visual. CropRegistry remains the authoritative data source.
const CropRegistryScript = preload("res://systems/CropRegistry.gd")
const WATER_AMOUNT := 35.0
const GROWTH_TICK_SECONDS := 120.0
const DRY_THRESHOLD := 30.0

var controller: Node
var stable_id: String = ""
var crop_id: String = "wheat"
var plot_index: int = 1
var status_text: String = ""
var _marker_material: StandardMaterial3D
var _fruit_material: StandardMaterial3D

@onready var _stem: MeshInstance3D = get_node("CropStem") as MeshInstance3D
@onready var _fruit: MeshInstance3D = get_node("CropFruit") as MeshInstance3D
@onready var _marker: MeshInstance3D = get_node("CropTypeMarker") as MeshInstance3D

func _ready() -> void:
    _marker_material = _marker.material_override as StandardMaterial3D
    _fruit_material = _fruit.material_override as StandardMaterial3D
    _apply_crop_color()
    refresh()

func can_configure(value: Node, id: String, kind: String, index: int) -> bool:
    if value == null or not is_instance_valid(value):
        return false
    for method_name in ["get_crop", "plant_crop", "water_crop", "advance_crop", "harvest_crop"]:
        if not value.has_method(method_name):
            return false
    if id.is_empty() or id != id.strip_edges() or id.length() > 160:
        return false
    if id.find("/") <= 0 or id.contains(" ") or id.contains("\t") or id.contains("\n") or id.contains("\r") or id.contains("//") or id.contains(".."):
        return false
    if not CropRegistryScript.SUPPORTED_CROP_IDS.has(kind) or index < 1:
        return false
    return true

func configure(value: Node, id: String, kind: String, index: int) -> bool:
    if not can_configure(value, id, kind, index):
        return false
    controller = value
    stable_id = id
    crop_id = kind
    plot_index = index
    if is_node_ready():
        _apply_crop_color()
        refresh()
    return true

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
            message = "Watered plot %02d. Press E or tap INTERACT again to advance growth." % plot_index
        "advanced":
            message = "Advanced plot %02d by one bounded growth interval." % plot_index
        "harvested":
            message = "Harvested plot %02d; the next crop cycle is ready." % plot_index
    return _result(true, action, message)

func refresh() -> void:
    if not is_node_ready() or _stem == null or _fruit == null:
        return
    var record: Dictionary = {}
    if controller != null and not stable_id.is_empty():
        record = controller.call("get_crop", stable_id)
    if record.is_empty():
        _stem.visible = false
        _fruit.visible = false
        status_text = "PLOT %02d | EMPTY | E / TAP: PLANT" % plot_index
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
        "E / TAP: HARVEST" if mature else ("E / TAP: WATER" if moisture < DRY_THRESHOLD else "E / TAP: GROW")
    ]

func _apply_crop_color() -> void:
    if _marker_material != null:
        _marker_material.albedo_color = _crop_color()
    if _fruit_material != null:
        _fruit_material.albedo_color = _crop_color()

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
