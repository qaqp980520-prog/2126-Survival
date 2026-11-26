# M0.3.34 — Underground World-save Recovery Barrier

## Purpose

Prevent the official world-session save/restore entry points from capturing or applying a world payload while the UndergroundMineDirector retains an unresolved Object/Mineral Registry-pair recovery barrier.

## Version and dependency

- Version: M0.3.34 — Underground World-save Recovery Barrier.
- Parent PR #448 / M0.3.33, exact parent HEAD `51458e133588b74a0f833cc57bfd17d3a96b423d`.
- Child PR: #449 (stacked; keep Draft until parent-first independent review and exact-head CI).
- No main changes.

## Files

- `scripts/world.gd`
- `world/SurfaceWorld.gd`
- `tests/production_surface_world_test.gd`
- `docs/UNDERGROUND_WORLD_SAVE_RECOVERY_BARRIER_M0_3_34.md`

## Implementation

- Add the base `_get_world_save_recovery_barrier_report()` hook; generic WorldSessionController instances return an empty report and retain existing behavior.
- Gate `WorldSessionController.serialize_stream_state()` before live world-object capture. A non-empty recovery report returns an empty payload.
- Gate the base `restore_stream_state()` before validation or mutation and report an incomplete recovery barrier.
- SurfaceWorld overrides the hook and fails closed if its UndergroundMineDirector is missing, lacks the pair-recovery API, or reports pending recovery.
- SurfaceWorld rejects restore before seed changes, snapshots, chunk streaming, or other side effects, with phase `registry_pair_recovery_barrier`.
- A normal save becomes available again after the original Director reports no pending pair recovery.

## Regression coverage

The production SurfaceWorld integration test injects a pending Director barrier and creates an unsaved live crate-state change. It verifies:

- serialization returns an empty payload;
- live world-object state is not captured into the Registry;
- mineral, crop, object, and inventory snapshots remain unchanged;
- restore is rejected before seed/player/chunk-window mutation;
- the restore report exposes the barrier and `rollback_complete=false`;
- serialization resumes after the original Director is restored;
- a Director missing the recovery API also fails closed.

## Import and integration

- Existing Godot resource paths only; no new package, plugin, autoload, scene, project setting, or save-schema migration.
- `scripts/world.gd` remains the shared base session controller.
- `world/SurfaceWorld.gd` supplies the UndergroundMineDirector-specific barrier report.
- Generic worlds using the base controller keep the default no-barrier behavior.

## Test status

- Exact-head Godot 4.3 Full Compatibility Gate: pending after PR creation.
- Local Godot executable unavailable; no local engine run is claimed.
- Static diff and API-path review only until the exact-head CI completes.

## Limitations

- This gates the official WorldSessionController/SurfaceWorld serialization and restore entry points; it does not prevent arbitrary direct calls to Registry `to_save_dict()` APIs outside those entry points.
- The pair barrier remains in-memory and is not a disk-backed crash-recovery journal.
- No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is claimed.

## Next

1. Complete exact-head Godot 4.3 Full Gate and inspect the complete log.
2. Add the barrier to the concrete file-save caller if a separate caller bypasses `serialize_stream_state()`.
3. Review whether save/autosave scheduling must retry automatically after pair recovery clears.
4. Keep PR #449 Draft until #448 and its parent chain are independently reviewed and integrated.
