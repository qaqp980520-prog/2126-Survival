extends Area3D

## Reusable 3D visual/interaction shell for a portal produced by BackroomsPortalDirector.
## The world controller owns level switching and consumes the portal ID.
signal portal_entered(body: Node3D, portal_id: int)

const INTERACTION_RANGE: float = 3.25

@export var portal_id: int = 0

var _player_in_range: Node3D
var _external_interaction_router_enabled: bool = false
@onready var _prompt: Label3D = get_node_or_null("InteractPrompt")

func _ready() -> void:
    add_to_group("backrooms_portal")
    var ancestor: Node = get_parent()
    while ancestor != null:
        if ancestor.is_in_group("production_surface_world"):
            _external_interaction_router_enabled = true
            break
        ancestor = ancestor.get_parent()
    if _external_interaction_router_enabled and _prompt != null:
        _prompt.visible = false
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func set_external_interaction_router_enabled(enabled: bool) -> void:
    _external_interaction_router_enabled = enabled
    if enabled and _prompt != null:
        _prompt.visible = false

func get_interaction_range() -> float:
    return INTERACTION_RANGE

func interact(body: Node3D) -> bool:
    if body == null or not is_instance_valid(body) or not is_inside_tree() or is_queued_for_deletion():
        return false
    if not body.is_inside_tree() or not body.is_in_group("player") or portal_id < 1:
        return false
    if global_position.distance_to(body.global_position) > INTERACTION_RANGE:
        return false
    portal_entered.emit(body, portal_id)
    return true

func configure_from_director(portal_data: Dictionary, ground_y: float = 0.0) -> bool:
    var saved_id: Variant = portal_data.get("id", null)
    var saved_position: Variant = portal_data.get("position", null)
    if not (saved_id is int or saved_id is float):
        return false
    var numeric_id := float(saved_id)
    if not is_finite(numeric_id) or numeric_id < 1.0 or floorf(numeric_id) != numeric_id:
        return false
    if not (saved_position is Vector2) or not is_finite(ground_y):
        return false
    portal_id = int(numeric_id)
    var target_position := Vector3(saved_position.x, ground_y + 1.0, saved_position.y)
    # Detached/headless tests can validate configuration without a RenderingServer tree.
    if is_inside_tree():
        global_position = target_position
    else:
        position = target_position
    return true

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        _player_in_range = body
        if _prompt != null and not _external_interaction_router_enabled:
            _prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
    if body == _player_in_range:
        _player_in_range = null
        if _prompt != null:
            _prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if _external_interaction_router_enabled:
        return
    if _player_in_range == null or not is_instance_valid(_player_in_range):
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        if interact(_player_in_range):
            get_viewport().set_input_as_handled()
