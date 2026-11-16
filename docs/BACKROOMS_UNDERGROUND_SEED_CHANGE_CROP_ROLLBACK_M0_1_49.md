# M0.1.49 — Underground Seed-Change Crop Snapshot Rollback

## Purpose

Port the unique crop-registry rollback correction from the older PR #341 stack onto the current reconciled underground save branch. The production restore transaction can change the world seed, rebuild the mine window, and then fail during the final SurfaceWorld stream sync. In that sequence, crop registration during the stream sync can advance crop records after the earlier base restore. A failed transaction must restore the exact pre-attempt crop snapshot after all streaming has completed.

## GitHub delivery

- Repository: qaqp980520-prog/2126-Survival.
- Parent PR: #377 — Underground Surface Return Window.
- Parent exact HEAD at branch creation:  ccf4146f3b0609b7a1d08e1d1f2ed1635c6739b4.
- Branch: fix/backrooms-underground-seed-change-crop-rollback-2026-11-17.
- Source reference: PR #341, originally based on PR #340. This branch ports only the crop snapshot rollback fix and its production regression onto the newer #377 runtime; it does not merge the stale #339–#341 stack.
- Runtime file: world/SurfaceWorld.gd.
- Test file: tests/production_surface_world_test.gd.
- Version file: docs/BACKROOMS_UNDERGROUND_SEED_CHANGE_CROP_ROLLBACK_M0_1_49.md.

## Runtime change

- Validate and deep-copy the pre-restore crop payload before mutating the live world.
- Pass the exact crop snapshot through seed-change mine-window recovery and the initial mine snapshot restore.
- After the final SurfaceWorld stream rollback completes, reapply the original crop registry payload so chunk registration cannot leave time-advanced records behind.
- Include crops_restored in the aggregate rollback_complete result and the detailed rollback report.
- Refresh crop plots after the mine-window snapshot is restored.

## Regression coverage

The existing underground base-stream failure test now deliberately changes the candidate world seed, supplies a matching Backrooms portal envelope, and injects a one-shot SurfaceChunkFactory failure. The test records the candidate seed at the moment of failure to prove the seed-change branch was actually entered.

It then verifies:
- the failed restore reports stream_sync and a complete rollback;
- the crop snapshot is non-empty before the attempt and exactly matches after rollback;
- the original world seed, player/mine position, mine layer, surface return anchor and loaded chunk sets are restored;
- the original portal director instance, seed identity, active portal ID and exact portal position are preserved;
- the mine-origin chunk's loaded state matches the baseline rather than assuming it is always loaded.

This test runs within the existing all-layer suite at the established rollback layers (2 and 8), not on every layer.

## Dependencies and import

- Godot 4.3.
- Existing SurfaceWorld, CropRegistry, SurfaceChunkController, UndergroundMineDirector, BackroomsPortalDirector, and the production SurfaceChunkFactory.
- No third-party packages, new scenes, Project Settings, autoloads, or input mappings.
- Import: godot --headless --path . --editor --quit.
- Focused regression: godot --headless --path . --script res://tests/production_surface_world_test.gd.

## Validation status at creation

- Static source audit: all _restore_mine_snapshots and _recover_underground_window call sites were updated to pass the crop snapshot; the final rollback path reports and includes crops_restored.
- Exact-head Godot 4.3 Full Compatibility Gate is pending for this branch. No engine-test pass is claimed.
- Parent PR #377's ancestry-synchronized HEAD ccf4146f3b0609b7a1d08e1d1f2ed1635c6739b4 is independently running its own Full Gate [#43976746150](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43976746150); that run does not validate this child branch.
- Local Godot executable is unavailable; engine validation must run through GitHub Actions.

## Limitations and next steps

1. Complete the parent #377 exact-head gate and full-log scan.
2. Complete this branch's own exact-head Full Gate and full-log scan.
3. Review the crop rollback diff and obtain independent review.
4. Merge only into the #377 feature branch after review; then rerun #377 and later #376 in parent-first order.
5. Keep the original PR #341 open as an audit source until this port is reviewed and validated; do not merge the stale #341 branch blindly.
6. No main merge. GPU rendering, iPhone, target-device performance, and playable Backrooms portal activation remain unverified.