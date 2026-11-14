# Terrain Adjacency Batch Commit M0.1

## Purpose

Coalesce the terrain adjacency and transition-collider rebuilds performed by one asynchronous streaming window commit. A boundary shift may load several incoming chunks and unload several outgoing chunks in one non-yielding commit; the controller must not rebuild the entire live terrain set after every individual root mutation.

## Implementation

- `MineralChunkController.begin_terrain_adjacency_batch()` opens a nestable batch scope.
- Chunk load, unload, rollback, and terrain-state notifications inside the scope mark adjacency dirty instead of rebuilding immediately.
- `end_terrain_adjacency_batch()` performs one full rebuild against the final committed live chunk set when the outermost scope closes.
- The full `_rebind_terrain_patches()` path remains the authoritative rebuild/oracle and explicit refresh fallback.
- `MineralGridStreamingDirector` opens the scope only after async roots have been staged and validated, immediately before the non-yielding commit. It closes the scope on success and all commit rollback/abort paths.
- If the final rebuild fails, the director attempts to restore the prior loaded window and explicitly refreshes adjacency before reporting the transaction result.

This is a safe batching optimization, not yet the incremental local-neighborhood algorithm requested by Issue #282. It reduces repeated full-set work from once per root to once per async window transaction while preserving the existing full rebuild behavior.

## Regression coverage

The production SurfaceChunkFactory benchmark now reads the controller's rebuild counter around each async transaction and requires exactly one adjacency rebuild for:

- full-window expansion;
- one-chunk eastward boundary crossing;
- contraction to radius zero;

at radii 1, 2, 3, 4, and 8. Existing exact chunk-ID, Director/Controller ownership, root-retention/release, and production-factory-call assertions remain in place.

## Files

- `systems/MineralChunkController.gd`: batch scope, dirty coalescing, and rebuild counter.
- `systems/MineralGridStreamingDirector.gd`: begin/finalize batch around async commit and rollback paths.
- `tests/surface_chunk_production_benchmark.gd`: exact one-rebuild-per-transaction assertions.
- `docs/SURFACE_TERRAIN_ADJACENCY_BATCH_COMMIT_M0_1.md`: this version record.

## Dependencies and import

Godot 4.3 root project; SurfaceWorld; MineralGridStreamingDirector; MineralChunkController; SurfaceTerrainAdjacencyBinder; SurfaceTerrainTransitionColliderManager; production SurfaceChunkFactory and its mineral/crop/world-object dependencies.

From repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

The PR's GitHub Actions workflow also runs the full Godot 4.3 compatibility gate.

## Validation state — exact-head closeout (2026-11-06)

Validated exact PR head: `0f9d3f67e734b9381cb2843fdae3a0ff3d54d62c`.

- Full Godot 4.3 compatibility gate [#42223164700](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/42223164700): 552/552 job steps successful; zero failed and zero skipped.
- Production Surface Chunk Benchmark [#42223164738](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/42223164738): successful. Artifact `13504905678` was downloaded and inspected: 15 valid JSONL records, 165 PASS markers, zero FAIL/ERROR markers, and the completion marker is present.
- All 15 exact rebuild-count assertions passed: expansion, one-chunk eastward boundary crossing, and contraction at radii 1, 2, 3, 4, and 8 each perform exactly one full adjacency rebuild per asynchronous transaction.
- Mineral Grid lifecycle [#42223164862](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/42223164862) and all other focused validation runs associated with this exact head completed successfully.
- Radius-8 one-chunk boundary sample on the headless AMD EPYC 9V45 runner: 965.914 ms transaction total, 953.736 ms maximum observed process-frame interval and p95 across 18 samples. This is a single headless observation, not a target-device performance budget or controlled cross-runner comparison.

Local Godot and target-device GPU/iPhone validation are not available in this environment.

## Limitations and next steps

- The full adjacency binder and transition-collider manager still process the complete final set once per transaction; incremental local patch/edge updates remain outstanding under Issue #282.
- The synchronous `sync_to_world_position()` path is not batched by this version.
- Headless timings are not GPU frame time or target-device performance.
- Local Godot executable is unavailable; use exact-head cloud Godot 4.3 CI.
- Preserve the full rebuild path for terrain edits, recovery, explicit refresh, and fallback.


## Additional batch lifecycle regression coverage

- The real `MineralChunkController` integration test now verifies nested begin/end behavior: inner close defers, outer close performs exactly one rebuild, and an extra close is inactive without another rebuild.
- The async registration fake-controller contract tests now track batch begin/end/depth/finalization across registration failure, rollback failure, unregistered-success cleanup, stale-root restoration failure, controller detach, superseded staging, queued-controller teardown, and factory loss before commit.
- The fake controller only records the Director's transaction boundary; production adjacency correctness remains exercised by the real SurfaceWorld benchmark and real controller nested-scope test.
