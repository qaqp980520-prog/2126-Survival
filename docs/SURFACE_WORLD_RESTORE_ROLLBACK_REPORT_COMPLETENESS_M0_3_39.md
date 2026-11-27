# M0.3.39 — SurfaceWorld Restore Rollback Report Completeness

## Purpose

Prevent a failed underground world-seed transition from inheriting a stale successful restore report. The previous implementation could return from an underground synchronization/recovery failure without updating `_last_restore_report`. The outer transaction wrapper then read the previous call's `rollback_complete=true` and could omit the world recovery barrier even though the underground chunk window had not been restored.

## Changes

- Reset the restore report to a safe preflight state before validation.
- Mark the transaction as rollback-incomplete immediately before the first world/underground mutation.
- Verify the previous world seed, player position, underground mode/depth/return position, combined loaded chunk IDs, Mineral Registry snapshot, WorldObject Registry snapshot, and underground recovery barrier after rollback.
- Combine the base WorldSessionController rollback result with the underground Director recovery result.
- Persist a world recovery barrier and the pre-restore snapshot whenever either participant cannot prove restoration.
- Add a failure-injection regression where the underground Director rejects target sync and also refuses recovery; then restore the original Director and prove retry recovery reproduces the exact prior world snapshot.

## Files

- `world/SurfaceWorld.gd`
- `tests/production_surface_world_test.gd`
- `docs/SURFACE_WORLD_RESTORE_ROLLBACK_REPORT_COMPLETENESS_M0_3_39.md`

## Dependencies

- Parent feature PR: [#452 — Production SurfaceWorld durable save/load](https://github.com/qaqp980520-prog/2126-Survival/pull/452)
- Parent HEAD at branch creation: `be9fc716ee9ac591d48edafbf9d13ac68220d01f`
- Existing M0.3.38 save-family sidecar path isolation and M0.3.37 production persistence.

## Import / Test

No new assets or external dependencies. The regression runs through the existing production SurfaceWorld test entry:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The full Godot 4.3 compatibility workflow must also pass on the exact PR HEAD.

## Limitations

- The failure is injected at the UndergroundMineDirector boundary; it does not simulate OS process termination.
- The local execution environment has no Godot binary; engine validation must be confirmed by GitHub Actions.
- This change does not add disk-persisted recovery journals or autosave.

## Next Step

Run the dedicated production save/load regression and the full Godot 4.3 compatibility gate on the exact PR HEAD. Keep the child PR Draft until both pass and the parent-first review chain is independently reviewed.
