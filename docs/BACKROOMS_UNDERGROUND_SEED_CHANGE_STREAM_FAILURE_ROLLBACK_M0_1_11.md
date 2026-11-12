# M0.1.11 — Underground World-Seed Change + Surface Stream Failure Rollback

## Purpose

Close a combined failure-path gap in the production SurfaceWorld restore transaction. Existing coverage separately tested (a) underground world-seed changes followed by Stamina/Quick Use adapter failure and (b) underground restore followed by a one-shot surface chunk-factory failure. It did not combine the seed-change mine-window rebuild with a subsequent failure while rebuilding the target surface return window.

## GitHub delivery

- Parent: PR #340 — underground surface-window save/restore anchor.
- Parent exact HEAD: `7ecf410a42b66c17203b34ba454e2c365a4627ab`.
- Child branch: `test/backrooms-underground-seed-change-stream-rollback-2026-11-12`.
- PR: #341 (opened after the test and version record are committed).
- Expected runtime scope: test-only; no gameplay runtime or save-schema changes.

## Regression scenario

1. Start from a valid underground SurfaceWorld snapshot with an active production portal.
2. Prepare a candidate snapshot with a different valid world seed, a matching Backrooms portal envelope generated from a director seeded with that candidate seed, and a different surface return position.
3. Install a one-shot SurfaceChunkFactory that fails the first target surface chunk creation and then delegates normally.
4. Call the real `SurfaceWorld.restore_stream_state()`. The seed-change path must clear/rebuild the mine window under the candidate seed before the injected surface stream failure occurs.
5. Require restore to fail with phase `stream_sync` and `rollback_complete=true`.
6. Verify exact restoration of the original world seed, mine player position/layer, surface return position/window, managed mine chunk IDs, registries, original portal director instance/state/seed identity, active portal ID/position, and both origin chunks.

The failure callback records the world seed at the instant the chunk factory rejects creation. The test requires this to equal the candidate seed, proving the failure occurred after the seed-change branch was entered rather than merely exercising the non-seed-change path.

## Files

- `tests/production_surface_world_test.gd` — strengthen `_test_underground_base_stream_failure_rollback()` with a valid candidate-seed portal envelope, failure-phase seed capture, and exact portal/director/origin-chunk assertions.
- `docs/BACKROOMS_UNDERGROUND_SEED_CHANGE_STREAM_FAILURE_ROLLBACK_M0_1_11.md` — this version record.

## Dependencies and import

- Parent PR #340 provides the separate surface-return-window anchor and cross-layer rollback implementation.
- Existing `SurfaceWorld`, `UndergroundMineDirector`, `MineralGridStreamingDirector`, `BackroomsPortalDirector`, mineral registry and world-object registry.
- Godot 4.3; no third-party packages, scenes, Project Settings, autoloads, or input mappings.
- Import: `godot --headless --path . --import`.
- Focused regression: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.
- Exact-head Full Compatibility Gate is required before this PR is marked Ready for Review.

## Validation status

- Test and documentation changes are committed to a child branch of the exact PR #340 HEAD.
- Parent PR #340 exact-head Godot 4.3 Full Compatibility Gate [Run #43230726708](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43230726708) completed successfully: 555/555 steps, 0 failures, 0 skipped. Production SurfaceWorld integration Step #207 and underground save/restore/rollback assertions passed.
- The new combined seed-change + surface-stream-failure regression has not yet run on its own exact HEAD; no pass is claimed until the child PR's CI completes.
- Local Godot executable is unavailable; no local engine pass is claimed.
- Graphical rendering, GPU, portal visuals/Z-fighting, and iPhone touch/performance remain unverified.

## Limitations and next step

- This version only strengthens production rollback regression coverage; it does not implement or activate the playable Backrooms maze runtime.
- Wait for the focused production SurfaceWorld test and the exact-head Full Compatibility Gate. If the combined path fails, fix the runtime rollback before merging.
- After validation, continue with staged Backrooms destination activation and failure-atomic world-layer switching.
