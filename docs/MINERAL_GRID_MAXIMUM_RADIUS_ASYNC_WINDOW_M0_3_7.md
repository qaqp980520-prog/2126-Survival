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

## Run 389 — parent-current exact-merge revalidation checkpoint — 2026-11-23

- Parent PR #276 was revalidated against current main and its head advanced from `e15765ead6c48940a8fb40a5071bf6203a2cf276` to `a8c0fca26b74f7256bc40fded25ccfb0b9a6f721` with a documentation-only checkpoint commit. Current main remains `65b2cabc751637729d58f64c9633f888d3c8b74c`.
- This child branch still contains the prior parent head as its merge base. Live compare now reports 13 commits ahead / 1 behind the updated parent. The only newly introduced parent commit changes the M0.3.4 version document; no runtime/test file conflict is reported by the compare endpoint.
- Recovery branch `backup/pr277-before-parent-current-main-revalidation-2026-11-23-run389` preserves the child head before this checkpoint.
- This documentation-only update triggers a fresh child PR validation against the updated #276 parent merge ref. Exact-head Full Godot 4.3, Mineral Grid focused, and streaming regression results are pending; the November 6 runs validate only the prior base and must not be reused as current-parent evidence.
- PR #277 remains Draft and stacked on #276. Do not merge directly to main; after current-parent CI passes, integrate #277 into #276 and rerun the parent's exact-head matrix.
