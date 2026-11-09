extends "res://systems/SurfaceTerrainPatch.gd"

var fail_activation_on_call: int = -1
var activation_call_count: int = 0


func set_shared_transition_active(side: String, active: bool) -> bool:
    if active:
        activation_call_count += 1
        if activation_call_count == fail_activation_on_call:
            return false
    return super.set_shared_transition_active(side, active)
