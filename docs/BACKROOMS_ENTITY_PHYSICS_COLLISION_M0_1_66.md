# Backrooms Physics Collision Proxies — M0.1.66

## Summary

Replace direct Node3D position writes with collision-aware CharacterBody3D movement while preserving the existing cell-local ownership boundary. Add a dedicated collision factory for the six mobile entities. Window and Clump remain anchored and do not enter the mobile collision layer.

## Files

- `systems/BackroomsEntityCollisionFactory.gd` — creates entity-specific SphereShape3D/CapsuleShape3D proxies and toggles collision with runtime activation.
- `systems/BackroomsMazeCellRuntime.gd` — creates CharacterBody3D entity roots and enables/disables their collision together with cell world geometry.
- `systems/BackroomsEntityMovementDriver.gd` — uses PhysicsBody3D.move_and_collide, records partial blocking, and keeps the safe cell bounds as a second guard.
- `world/SurfaceWorld.gd` — preserves the existing player layer 1 and adds entity layer 4 to its collision mask.
- `tests/production_surface_world_test.gd` — verifies the player collision-layer contract.
- `tests/backrooms_entity_collision_factory_test.gd` — validates all mobile/stationary collision contracts and activation toggles.
- `tests/backrooms_entity_movement_driver_test.gd` — adds an actual StaticBody3D wall obstruction regression.
- `.github/workflows/godot-validation.yml` — adds file-presence and bounded Godot 4.3 collision-factory test steps.

## Dependencies and import

- Godot 4.3 built-in 3D physics; no external plugins or assets.
- World geometry remains collision layer 1; interaction proxies retain layer 2.
- Mobile entities use collision layer 4 and collision mask 1. The existing player remains on layer 1, shared with world geometry, and its mask becomes 5 (world layer 1 plus entity layer 4).
- This preserves existing Area3D/body-detection compatibility while making player/entity contact symmetric. Interaction proxies remain on layer 2 and are excluded from both physical masks.
- CharacterBody3D roots own their existing AI and Visuals children; no new per-entity process loops.
- Collision proxies are created while cells are staged but remain disabled until the Backrooms destination is activated.
- Cell retirement continues to free the complete cell root and all entity bodies.

## Collision contract

- Smiler and Deathmoth use bounded sphere proxies.
- Hound, Skin-Stealer, Faceling and Duller use capsule proxies sized for their current blockout geometry.
- Window and Clump remain anchored and have no mobile collision shape.
- Entity bodies collide with world geometry and the player through the shared layer 1; entity-to-entity collision is not enabled.
- Movement uses `move_and_collide` and retains the 0.65 m safe cell interior margin.
- A wall collision can stop movement before the target; partial movement and blocked status are reported separately.
- Patrol advances to its next deterministic waypoint after a collision to avoid repeatedly targeting an obstructed point.

## Tests

Headless commands:

```bash
godot --headless --path . --script res://tests/backrooms_entity_collision_factory_test.gd
godot --headless --path . --script res://tests/backrooms_entity_movement_driver_test.gd
```

The collision factory test verifies shape presence, layer/mask values, inactive/active toggling, anchored entity behavior and invalid ID rejection. The maze Runtime test verifies that collision remains disabled while prepared and is enabled/disabled with destination activation. The movement regression places a real StaticBody3D wall between a Hound and its same-cell target and verifies the body cannot pass through it.

## Limitations

- Collision-aware movement is still local to the owning cell; no NavigationAgent3D or wall-avoidance pathfinding is included.
- A blocked pursuer stops at the wall; it does not yet route around it.
- No cross-cell entity ownership migration or moved-position/AI persistence is enabled.
- No player attack/damage, hit reactions, animation, audio or mobile hardware performance validation.

## Review and merge guard

- This PR is stacked on PR #394's exact tested HEAD.
- Keep Draft until the exact-head Full Gate and complete-log review pass.
- Obtain independent review before integration into PR #394's feature branch.
- Do not merge to main.
