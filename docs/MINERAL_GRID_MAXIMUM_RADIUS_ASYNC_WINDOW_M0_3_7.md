# Mineral Grid Maximum-Radius Async Window M0.3.7

## Purpose

Extend M0.3.6's runtime configuration-boundary checks with an end-to-end asynchronous lifecycle test for the largest supported chunk window. The upper bound of load radius is not only a valid scalar; it must produce the exact expected active window and cleanly release stale chunks when the radius contracts.

## Scope

- Parent implementation: PR [#276 — Enforce runtime cap for Mineral Grid load radius](https://github.com/qaqp980520-prog/2126-Survival/pull/276).
- Parent regression contract: PR [#277 — Enforce Inspector chunk dimension bounds with Mineral Grid regressions](https://github.com/qaqp980520-prog/2126-Survival/pull/277).
- Branch: `test/mineral-grid-config-dimension-regressions-2026-11-06`.
- Test file: `tests/mineral_grid_streaming_async_test.gd`.
- No runtime implementation, scene, save schema, chunk ID, or external asset changes.

## Regression scenario

Using the deterministic `FaultInjectingChunkController` and `_make_transaction_chunk` fixture:

1. Start from the normal 3×3 window (9 chunks) centered at world X=12000, Z=0.
2. Set `load_radius = 8` and submit an asynchronous request with the maximum staging budget (8).
3. Verify the request completes with `desired_count = 289`, stages exactly 280 new chunks, unloads none of the retained chunks, and leaves controller/Director ownership maps identical.
4. Set `load_radius = 0` and request the same center.
5. Verify the one-chunk window completes and exactly 288 stale chunks are unloaded.
6. Restore the original radius and confirm the normal 3×3 window returns with nine consistent IDs.

This validates both sides of the supported range as actual streaming behavior, not only as configuration predicates.

## Dependencies

- Godot 4.3 root project.
- `systems/MineralGridStreamingDirector.gd` from PR #276 and M0.3.6.
- `FaultInjectingChunkController` and `_make_transaction_chunk` test fixtures in the existing async test.
- Existing Mineral Grid focused workflow; it already runs `tests/mineral_grid_streaming_async_test.gd`.

## Import and test

From repository root:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/mineral_grid_streaming_async_test.gd`

No new workflow file or external dependency is required.

## Validation and limitations

- Exact-head focused and full Godot 4.3 CI must be rerun after this commit; prior M0.3.6 green runs do not validate M0.3.7.
- Local Godot executable is unavailable in this run, so no local engine pass is claimed.
- The fake controller measures ownership, count, staging, and cleanup invariants; it does not measure real terrain generation time, GPU cost, or production memory footprint.
- Physical-device and world-scale performance profiling remain separate follow-up work.

## Next step

Run the exact-head Mineral Grid focused gate and complete Godot 4.3 gate. If the 289→1 lifecycle test fails, inspect the async commit/unload transaction and fix this same branch before review.