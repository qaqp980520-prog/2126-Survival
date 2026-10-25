extends Area3D

## Reusable 3D visual/interaction shell for a portal produced by BackroomsPortalDirector.
## The world controller owns level switching and consumes the portal ID.
signal portal_entered(body: Node3D, portal_id: int)

@export var portal_id: int = 0

var _player_in_range: Node3D
@onready var _prompt: Label3D = get_node_or_null("InteractPrompt")

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

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
    global_position = Vector3(saved_position.x, ground_y, saved_position.y)
    return true

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        _player_in_range = body
        if _prompt != null:
            _prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
    if body == _player_in_range:
        _player_in_range = null
        if _prompt != null:
            _prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if _player_in_range == null:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        portal_entered.emit(_player_in_range, portal_id)
        get_viewport().set_input_as_handled()
