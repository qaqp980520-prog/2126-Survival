# Backrooms Bounded Perception Driver — M0.1.63

## Summary

Add a SurfaceWorld-owned, bounded-rate perception driver that turns the M0.1.62 decision-only entity brains into live sensor consumers. It samples loaded entity roots every 0.2 seconds, processes at most 12 entities per sensor tick with a stable round-robin cursor, raycasts against Backrooms world-geometry layer 1, evaluates the player camera view cone, and forwards movement-noise snapshots through the existing `BackroomsMazeCellRuntime.submit_entity_perception()` gate.

## Files

- `systems/BackroomsPerceptionDriver.gd` — bounded scheduler, loaded-cell enumeration, line-of-sight raycasts, player view-cone test, movement-noise gating, and per-entity elapsed-time accounting.
- `systems/BackroomsEntityBrain.gd` — behavior version 2 distinguishes entity-to-player line of sight from `player_looking_at_entity`; Window and Smiler use the latter.
- `world/SurfaceWorld.gd` — owns one driver, calls it from `_physics_process_backrooms()`, and resets it on successful entry/return.
- `tests/backrooms_perception_driver_test.gd` — real physics-ray occlusion, camera gaze, walking/sprint noise, 0.2-second cadence, 12-entity budget, round-robin drain, invalid-input rejection and inactive-runtime reset.
- `tests/backrooms_entity_brain_test.gd` — regression coverage for the separate gaze signal and atomic rejection of invalid gaze values.
- `.github/workflows/godot-validation.yml` — file-presence and bounded headless test steps.

## Dependencies and import

No manual import, plugin, autoload or project setting is required. SurfaceWorld preloads `res://systems/BackroomsPerceptionDriver.gd`; the driver uses the existing Brain and Runtime contracts. The driver is called only from the existing SurfaceWorld physics callback and does not create per-entity `_process()` loops.

## Sensor contract

- `has_line_of_sight` means the entity has an unobstructed physics ray to the player camera.
- `player_looking_at_entity` means the camera forward vector falls inside the entity's view cone and the same world-geometry ray is clear.
- `noise_strength` is a movement-noise proxy: 0.45 while actually walking and 0.8 while actually sprinting; it is zero while stationary and is range-gated by the entity profile.
- `is_dark` is currently passed as false. SurfaceWorld still shares the KrollSun/SurfaceWorld environment; there is no dedicated Backrooms darkness/light sampler yet. Smiler therefore remains dormant until the lighting system supplies a real darkness signal.
- Window ray targets are offset from the north/west wall into the owning cell so the wall-mounted visual does not self-occlude.

## Scheduling and safety

- Sensor cadence: 5 Hz (0.2 seconds).
- Maximum work per sensor tick: 12 entity samples.
- Stable key ordering and round-robin cursor prevent a loaded entity from being starved when the window contains more than 12 entities.
- Per-entity elapsed decision time accounts for skipped sensor ticks.
- Only loaded entity roots with an `AI` child are sampled; the Runtime still rejects inactive destinations and unloaded identities.
- Raycasts query collision layer 1 only and exclude the player body RID.
- No save schema, spawn algorithm, entity visual geometry, or `daily_games/` file is changed.

## Test command

    godot --headless --path . --script res://tests/backrooms_perception_driver_test.gd

CI runs Godot 4.3 with `timeout -k 5s 60s` and requires the exact success marker.

## Validation

Pending exact-head PR CI. Local Godot executable is not available in this run; no local engine pass is claimed.

## Limitations

No navigation, physical entity movement, collision bodies, animation, attack/damage, audio playback, acoustic occlusion/propagation, or real darkness/light sampling is added. Movement noise is a gameplay proxy rather than a sound-emission system. The view-cone test uses the Camera3D FOV as a circular cone approximation. Mesa llvmpipe and iPhone/hardware-GPU testing are not repeated because this change does not modify visual geometry.

## Next steps

1. Obtain independent review for PR #390/#391; this PR is stacked on the exact #391 HEAD and is not a merge into main.
2. Add a dedicated Backrooms lighting profile and actual darkness sampling before enabling Smiler behavior in gameplay.
3. Add navigation/movement as a separate bounded world-owned update phase; do not add an unbounded process loop per entity.
4. Add audio event emission and acoustic propagation when player movement/interaction sound sources are defined.
5. Add graphical interaction tests for the sensor/AI loop after collision and navigation are implemented.