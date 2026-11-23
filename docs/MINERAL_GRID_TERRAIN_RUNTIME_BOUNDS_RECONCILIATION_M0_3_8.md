# Mineral Grid Runtime Bounds Reconciliation on Terrain Optimization M0.3.8

## Purpose

Port the runtime configuration bounds and validation-before-cancellation contract from the current-main-revalidated Mineral Grid PRs #276 and #277 into the production terrain optimization stack rooted at PR #279. The stacks diverged in `MineralGridStreamingDirector.gd`; this candidate applies the small runtime contract to the optimized implementation rather than merging the old feature branches wholesale.

## Parent and source versions

- Parent PR: [#279 — real production SurfaceChunkFactory benchmark](https://github.com/qaqp980520-prog/2126-Survival/pull/279).
- Parent HEAD used to create this candidate: `f6b0dd1bfe7125a12e4354bcde389aab4cafe099`.
- Runtime radius source: PR #276 HEAD `a8c0fca26b74f7256bc40fded25ccfb0b9a6f721`, current-main merge-tree Full Gate [45140494105](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45140494105).
- Dimension-bound source: PR #277 HEAD `65e199a74514d1175435fd8ffe708dcba479fe95`, current-parent merge-tree Full Gate [45140562757](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45140562757).
- Candidate branch: `integration/mineral-grid-bounds-on-terrain-optimization-2026-11-23-run390`.

## Runtime contract

- Chunk width and depth must be finite and within the inclusive range 1–4096.
- Runtime load radius must be within the inclusive range 0–8, matching the Inspector export range.
- Synchronous requests validate controller, world position and complete grid configuration before cancelling an active asynchronous request.
- Invalid asynchronous requests are rejected before allocating a request ID or superseding the current active request.
- Recovery rejects invalid grid configuration before reconciling or mutating the Director ownership map.
- Coordinate helpers reject invalid configuration through the same shared predicate.

## Files

- `systems/MineralGridStreamingDirector.gd`
- `tests/mineral_grid_streaming_position_validation_test.gd`
- `tests/mineral_grid_streaming_async_test.gd`
- `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`
- `docs/MINERAL_GRID_TERRAIN_RUNTIME_BOUNDS_RECONCILIATION_M0_3_8.md`

## Dependencies and import

- Godot 4.3 root project.
- Existing production MineralGridStreamingDirector, MineralChunkController, SurfaceWorld and SurfaceChunkFactory dependencies.
- Existing FakeMineralChunkController and async staging fixtures.
- No third-party packages, plugins, new scenes, input mappings or save-schema changes.
- Import: `godot --headless --path . --editor --quit`.
- Focused validation: see the commands below.

## Import and test

From repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/mineral_grid_streaming_sync_registration_lifecycle_test.gd
godot --headless --path . --script res://tests/mineral_grid_streaming_async_registration_contract_test.gd
godot --headless --path . --script res://tests/mineral_grid_streaming_position_validation_test.gd
godot --headless --path . --script res://tests/mineral_grid_streaming_async_test.gd
```

## Regression coverage

- Inclusive dimension boundaries 1 and 4096 on both axes.
- Reject widths/depths below 1 or above 4096.
- Reject load radius -1 and 9; accept radius 8.
- Verify rejected sync/recovery requests preserve Director and Controller ownership maps.
- Verify rejected coordinate queries return the safe zero coordinate.
- Verify invalid sync validation does not cancel a valid in-flight async request.
- Verify invalid async validation neither cancels the active request nor consumes a request ID.
- Verify a valid in-flight request still completes after rejected radius and dimension attempts.
- Add a maximum-radius 17×17 async expansion and 289→1 contraction regression, asserting 289 committed chunks, 280 staged additions and 288 stale unloads.

## Validation status and limitations

- Exact-head focused Mineral Grid workflow and full Godot 4.3 Full Compatibility Gate are required for this candidate; pending until GitHub Actions completes on the PR merge ref.
- No local Godot executable is available in this environment; no local engine pass is claimed.
- Headless validation covers runtime configuration, ownership and transaction invariants. It does not establish rendered GPU, target-device frame time, or physical iPhone/iPad behavior.
- The PR #279 benchmark baseline and Issue #282 measurements remain separate; this guard does not change the playable radius default or claim a performance improvement.

## Next steps

1. Run the focused lifecycle workflow and exact-head Full Gate on the PR merge tree.
2. Audit complete Godot logs for actual Script/Parse/Runtime/FAIL diagnostics.
3. Compare the resulting PR head and base against PR #279 after every parent update; rerun exact-head validation after synchronization.
4. Obtain independent review before merging this child into the #279 feature branch.
5. Re-run the real production boundary benchmark after the bounds are integrated; keep headless and device measurements separate.
