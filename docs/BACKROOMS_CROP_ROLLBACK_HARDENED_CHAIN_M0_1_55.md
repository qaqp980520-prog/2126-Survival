# M0.1.55 — Exact Crop Snapshot Rollback Port to Hardened Backrooms Chain

## Purpose

Port the already-tested underground seed-change crop rollback correction from PR #379 onto the newer PR #381 branch, which includes the complete root Godot test output and hard-kill safeguards. This avoids leaving the crop fix on a sibling branch that would otherwise need a later manual merge.

## Source and destination

- Source PR #379 exact HEAD: `1a31bb85a939fa51241cf74dcb392d700be9012f`.
- Source PR #379 Full Gate: [#43977135005](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43977135005), 555/555 steps; complete-log scan recorded zero actual Godot Runtime diagnostics.
- Destination parent PR #381 exact HEAD at branch creation: `200a226bf199f0d511bec41e8e94dae5422caaa5`.
- The destination `world/SurfaceWorld.gd` and `tests/production_surface_world_test.gd` were verified byte-identical to PR #377's versions before porting; the source #379 files contain only the crop rollback extension relative to that parent.
- New child branch: `integration/backrooms-maze-stream-core-and-crop-rollback-2026-11-17`.

## Runtime change

- Deep-copy and validate the pre-restore crop payload before mutating the live world.
- Pass the exact crop snapshot through seed-change mine-window recovery and initial mine snapshot restoration.
- Reapply the pre-transaction crop registry payload after final SurfaceWorld streaming, because chunk registration can advance crop records after the earlier base restore.
- Include `crops_restored` in the aggregate rollback result and detailed report.
- Refresh crop plots after restoring the mine snapshot.

## Regression coverage

The production test changes the candidate world seed, supplies a matching Backrooms portal envelope and injects a one-shot SurfaceChunkFactory failure after the candidate seed and mine window have been applied. It then verifies:

- the failure actually occurred after the seed change;
- the failed restore reports the stream-sync phase and complete rollback;
- the original non-empty crop snapshot is restored exactly;
- player/mine position, layer, return anchor and loaded chunk sets match the baseline;
- the original portal director instance, seed identity, active portal ID and portal position are preserved;
- mine-origin loaded state matches the original baseline.

The regression remains in the existing all-layer Production SurfaceWorld suite and runs at rollback layers 2 and 8.

## Files

- `world/SurfaceWorld.gd` — crop snapshot validation, propagation and final rollback reapplication.
- `tests/production_surface_world_test.gd` — seed-change crop rollback regression.
- `docs/BACKROOMS_CROP_ROLLBACK_HARDENED_CHAIN_M0_1_55.md` — this version record.

## Dependencies and import

- Godot 4.3.
- Existing SurfaceWorld, CropRegistry, SurfaceChunkController, UndergroundMineDirector, BackroomsPortalDirector and SurfaceChunkFactory.
- No third-party packages, new scenes, Project Settings, autoloads or input mappings.
- Import: `godot --headless --path . --editor --quit`.
- Focused regression: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.
- Full validation: PR-triggered GitHub Actions Godot 4.3 Full Compatibility Gate on this exact branch.

## Validation status

- Source files were ported from PR #379 after confirming the destination base files were identical to PR #377's parent files.
- PR #379's source-head Full Gate passed 555/555; this is historical source evidence, not validation of the new combined PR #384 head.
- New exact-head Full Gate and complete-log scan are pending. No new engine pass is claimed.
- Local Godot executable is unavailable.

## Next steps

1. Complete the new combined PR #384 exact-head Full Gate and full-log scan.
2. Review the crop rollback port and the maze/stream-state range guards together.
3. Obtain independent review before integrating this child into PR #381.
4. After integration, rerun PR #381 and then its parent chain in order.
5. No main merge.
