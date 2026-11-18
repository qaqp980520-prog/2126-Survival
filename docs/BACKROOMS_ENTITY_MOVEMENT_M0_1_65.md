# Backrooms Cell-Local Entity Movement — M0.1.65

## Summary

Add a bounded, SurfaceWorld-owned locomotion driver that converts existing Backrooms Entity Brain intents into deterministic cell-local movement. Mobile entities can patrol, approach, pursue, investigate, observe, avoid and retreat within their owning maze cell. Window and Clump remain stationary.

This is deliberately a cell-local first movement stage. Cross-cell roaming is not enabled because entity ownership migration, streamed-cell retirement and moving-entity save/restore must be designed together; allowing entities to leave their owning cell now would risk losing or duplicating them when the 3×3 stream window changes.

## Files

- `systems/BackroomsEntityMovementDriver.gd` — bounded 10 Hz movement scheduler, 12-entity per-tick budget, deterministic patrol waypoints, cell bounds, intent-specific movement and fail-closed cross-cell target handling.
- `systems/BackroomsEntityBrain.gd` — retains player targets for approach/pursue/observe and avoidance/retreat; sound targets retain priority for investigate/pursue.
- `systems/BackroomsPerceptionDriver.gd` — always includes the current player position so unseen approach and avoidance states have a valid local movement target.
- `systems/BackroomsMazeCellRuntime.gd` — exposes each cell's size as runtime metadata for safe movement bounds.
- `world/SurfaceWorld.gd` — owns, ticks and resets the movement driver alongside perception on entry, return and inactive-runtime paths.
- `tests/backrooms_entity_movement_driver_test.gd` — pursuit, cross-cell rejection, avoidance, patrol bounds, round-robin budget and invalid/inactive runtime tests.
- `tests/production_surface_world_test.gd` — verifies SurfaceWorld owns the movement driver and ticks it after perception while Backrooms is active.
- `.github/workflows/godot-validation.yml` — file-presence and bounded Godot 4.3 movement test step.
- `docs/BACKROOMS_ENTITY_MOVEMENT_M0_1_65.md` — this version record.

## Dependencies and import

- Godot 4.3.
- No external plugins, assets, autoloads or manual import steps.
- SurfaceWorld preloads `BackroomsEntityMovementDriver.gd` and creates one RefCounted driver for the active world.
- Entity roots continue to be owned by their original maze-cell Node3D. The driver reads the existing child `AI` brain snapshot and the owning cell's `backrooms_cell_size` metadata.
- No per-entity `_process` or `_physics_process` loop is created.

## Movement contract

- Movement cadence: 10 Hz.
- Maximum work: 12 mobile entities per movement tick, round-robin.
- A single frame delta is capped at 0.5 s and per-entity catch-up movement is capped at 0.25 s to avoid large frame-hitch teleports.
- Mobile IDs: Smiler, Hound, Skin-Stealer, Faceling, Duller and Deathmoth.
- Window and Clump remain anchored.
- Hound and Skin-Stealer patrol deterministically inside their owning cell when no target is available.
- Deathmoth uses a deterministic four-point aerial patrol with bounded vertical movement.
- Approach, pursue, investigate and observe move toward the brain's current target with intent-specific stop distances.
- Avoid and retreat move away from the current player target and clamp the result to the safe interior of the owning cell.
- Same-cell targets are accepted. Targets outside the owning cell are rejected without moving the entity.
- A 0.65 m interior margin prevents the kinematic mover from crossing a wall boundary.
- Patrol phase is derived from spawn cell and world seed, then retained per live entity by the driver.
- Movement is kinematic XZ movement (and bounded Y movement for Deathmoth); it is not yet a CharacterBody3D/physics collision controller.

## Save and streaming safety

- Entity roots are not reparented or migrated between cell roots.
- The driver never moves an entity outside its owning cell.
- This avoids the current deterministic spawn and cell-retirement lifecycle from losing or duplicating a roaming entity.
- AI state and movement phase remain transient and are not added to the combined world-save envelope in this version.
- Cross-cell pursuit, roaming-entity ownership migration, persistence across streamed-cell unload/reload, and AI save/restore are explicitly deferred to a coordinated follow-up.

## Tests

Headless command:

```bash
godot --headless --path . --script res://tests/backrooms_entity_movement_driver_test.gd
```

The test verifies:

- Hound moves toward a same-cell pursuit target.
- Cross-cell target is rejected and entity position remains unchanged.
- Faceling retains player position without line of sight and moves away.
- Hound patrol moves while remaining inside the safe cell bounds.
- Window and Clump remain stationary and are excluded from the mobile scheduling budget.
- Deathmoth aerial patrol changes altitude within its owning cell.
- Smiler approaches an unseen player while the cell is dark.
- Duller retreats from a nearby player without line of sight.
- With 13 entities, each tick processes 12 and defers one; the rotating cursor services the previously deferred entity on the next tick while deferring the next entity.
- Non-finite delta and inactive runtime are rejected; a 2 s frame hitch is capped to five 100 ms scheduler ticks.
- Production SurfaceWorld handoff integration verifies that the world-owned driver advances its scheduler after perception.

The complete Godot 4.3 Full Gate is required before this PR can be marked Ready for Review. Local Godot availability is checked separately; no engine pass is claimed from static inspection.

## Limitations

- No physics collision body, wall raycast, NavigationAgent3D or cross-cell pathfinding.
- No attack, damage, hit reactions, animation, audio or combat cooldowns.
- Entities cannot follow the player into another cell yet.
- AI state and patrol phase are not persisted.
- Hardware GPU, mobile renderer, iPhone and real-device performance are not tested.

## Review and merge guard

- This PR is stacked on PR #393's exact tested HEAD and targets only PR #393's feature branch.
- Do not merge to main.
- Keep Draft until exact-head Full Gate and complete-log review pass.
- Obtain independent review before integrating this child into PR #393's feature branch; rerun the parent chain after integration.
