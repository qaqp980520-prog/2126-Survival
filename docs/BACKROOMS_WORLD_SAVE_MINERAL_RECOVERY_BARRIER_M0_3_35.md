# M0.3.35 — Backrooms Prototype Save/Load Recovery Barrier

## Purpose

Prevent the Backrooms prototype's direct file-backed world save/load path from serializing or applying a world envelope while its MineralVeinRegistry has an unresolved atomic-registration recovery.

## Authoritative base

- Parent PR #449 exact HEAD: `c8ea73916be1eff208594301cc614fe58804d5de`.
- Work branch: `fix/backrooms-save-recovery-barrier-2026-11-26-run449`.
- Backup branch: `backup/pr449-before-backrooms-save-recovery-barrier-2026-11-26-run449`.
- This is a stacked child of PR #449. It must not be merged before #449 and its parent-first dependency chain are independently reviewed and integrated.

## Files

- `prototypes/BackroomsPortalPlayground.gd`
- `tests/world_session_save_roundtrip_test.gd`
- `docs/BACKROOMS_WORLD_SAVE_MINERAL_RECOVERY_BARRIER_M0_3_35.md`

## Implementation

- Add `_get_world_save_recovery_barrier_report()`.
- Fail closed when the prototype's MineralVeinRegistry is missing, invalid, or lacks the recovery-state API.
- When `has_pending_atomic_registration_recovery()` is true, include the Registry's last atomic-registration report in the barrier details.
- `serialize_world_state()` returns an empty payload before reading inventory or Registry snapshots while the barrier is pending.
- `load_world_state_from_dictionary()` refuses before payload conversion, inventory restore, mineral restore, crop restore, portal mutation, or player movement.
- Existing `save_game()` and `load_game()` inherit the guard through their existing serialization/dictionary entry points. The atomic file writer and backup-recovery format are unchanged.

## Regression coverage

Extend `tests/world_session_save_roundtrip_test.gd` to inject an unresolved MineralVeinRegistry atomic-registration recovery and verify:

- Serialization is refused.
- Direct `save_game()` and `load_game()` are refused.
- Dictionary restore is refused before mutation.
- Primary save bytes remain unchanged.
- Inventory, mineral records, crop records, player position, and portal-world state remain unchanged.
- Normal serialization resumes after the recovery fixture is cleared.

## Dependencies and import

- Existing `MineralVeinRegistry.has_pending_atomic_registration_recovery()` and `get_last_atomic_registration_report()` APIs.
- Existing `SurvivalWorldBridge`, `CropRegistry`, and `BackroomsPortalDirector`.
- No new package, plugin, autoload, scene, Resource, project setting, or save-schema migration.
- Uses existing `res://` script paths; no manual import step.

## Scope correction discovered during audit

- `world/SurfaceWorld.tscn` is the project's configured main scene and uses `world/SurfaceWorld.gd`.
- `SurfaceWorld` exposes stream-state serialization/restore but this source revision does not contain a disk-backed `save_game()` / `load_game()` file writer.
- The concrete `user://backrooms_playground_save.json` file writer and F5/F9 save/load handlers belong to `prototypes/BackroomsPortalPlayground.gd`, which extends `Node3D` directly and does not inherit `WorldSessionController`.
- `tests/world_session_save_roundtrip_test.gd` actually instantiates `BackroomsPortalPlayground.tscn`; its historical filename should not be interpreted as proof that SurfaceWorld has durable file persistence.
- `BackroomsSettingsProfile.gd` separately persists user settings via ConfigFile; it is not a world-save path.

This PR hardens the existing Backrooms prototype persistence path. It does not add durable file persistence to the production SurfaceWorld.

## Validation status

- Code and test changes are pushed to the work branch.
- Godot 4.3 focused and full compatibility CI are pending PR creation.
- Local Godot executable is unavailable; no local engine run is claimed.
- No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is claimed.

## Limitations and next steps

- The barrier is in-memory; it does not survive process termination.
- This change gates the Backrooms prototype's official save/load entry points, not arbitrary external direct Registry snapshot calls.
- After exact-head CI, audit remaining direct Registry serialization callers and separately decide whether the production SurfaceWorld needs a new durable file-save feature.
- Keep the PR Draft until parent #449 and its parent chain receive independent parent-first review.
