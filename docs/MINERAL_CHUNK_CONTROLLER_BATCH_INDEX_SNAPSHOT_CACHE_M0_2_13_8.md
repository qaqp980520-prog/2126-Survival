# Mineral Chunk Controller Batch Index Snapshot Cache — M0.2.13.8

## Problem

M0.2.13.7 removed the per-Chunk loaded-patch and candidate-patch Array construction during an active adjacency batch. A second repeated O(K × P) cost remained: each _record_terrain_batch_chunk_additions(), _record_terrain_batch_chunk_removals(), and _record_terrain_batch_chunk_restored() call invoked _get_terrain_index_patch_map().

That helper asks the persistent Index for its Stable-ID → Patch map and duplicates the returned Dictionary. The Index is not committed or mutated while a Controller adjacency batch is collecting deltas; its candidate generation is only planned and published by the batch finalizer. Re-copying the same baseline map for every staged or retired Chunk is therefore unnecessary.

## Change

In systems/MineralChunkController.gd:

- Add a lazy, batch-scoped original Patch-map snapshot and a captured flag.
- Add _get_terrain_adjacency_batch_original_patch_map(); the first add/remove/restore delta captures the current Index map, and later delta records reuse the same Dictionary.
- Route all three delta-recording methods through the shared baseline helper.
- Clear the cached baseline together with the batch delta maps in _clear_terrain_adjacency_batch_delta().
- Keep the cache lazy: an empty batch or a batch that only records in-place dirty IDs does not copy the Index map.

The cache is scoped to the outer batch. Nested batches share it. Failed finalization retains the baseline with the existing pending delta state so recovery does not silently switch baselines; the existing clear/reset paths release it when the batch is safely reset.

## Complexity and correctness contract

For K add/remove/restore recording events and P indexed Patches:

- Before: up to K Index-map fetches and Dictionary copies, each O(P).
- After: at most one Index-map fetch and copy for the batch, O(P), plus the existing O(number of changed objects) delta recording.

This is a structural copy-count reduction, not a claim of a particular millisecond or FPS improvement.

The design relies on the existing Controller contract that the committed Index generation is immutable while a batch is collecting deltas. The Index is only changed by the batch finalizer/coordinator. Do not add an out-of-band Index mutation inside an active Controller batch.

## Regression coverage

In tests/mineral_chunk_controller_test.gd:

- Extend the test-only CountingController to count _get_terrain_index_patch_map() calls.
- Initialize the incremental Index runtime, then load two real SurfaceTerrainPatch Chunk roots in one batch.
- Assert the first delta captures one baseline and the second addition reuses it.
- Commit and verify both Patches exist in the Index.
- Start a second batch, retire one existing Chunk, cancel that pending retirement, and assert removal plus restoration reuse one baseline snapshot.
- Verify the no-net-change restoration preserves the Index Patch count and loaded Chunk root.

## Dependencies and import

- Godot 4.3.
- Existing MineralChunkController.gd, SurfaceTerrainAdjacencyIndex.gd, SurfaceTerrainAdjacencyCoordinator.gd, SurfaceTerrainPatch.gd, WorldObjectStateRegistry.gd, and the existing terrain transaction stack.
- No external packages, new runtime assets, autoloads, project settings, scene wiring, or save-schema changes.
- Open the repository root or use the existing headless --import workflow; no manual import is required.

## Validation status

- Static review: the original Index map is only fetched lazily by the first batch delta event; add/remove/restore all use the same cached baseline.
- Exact-head Focused Mineral Chunk Controller, Lifecycle, Production Benchmark, and Full Godot 4.3 gates are required.
- No Godot pass is claimed until the exact PR head completes its workflows.
- No production timing improvement is claimed until the exact-head artifact is parsed and compared with a controlled same-runner baseline.

## Limitations and next steps

- The one authoritative full loaded-Patch collection at batch finalization remains unchanged.
- Non-batched in-place terrain edits remain on the existing full Binder fallback.
- This does not eliminate per-Chunk world-object registration or stable-ID construction work.
- The cache is only valid while the Controller-owned Index remains immutable during the active batch.
- After exact-head validation, inspect the Radius-8 per-Chunk registration samples and determine whether Index-map copying was a material portion of the registration tail before planning another optimization.

## GitHub

- Parent PR #314 exact HEAD: b9b98fdcf422524cc3be576388e1a137abbf97ca.
- Branch: perf/mineral-chunk-controller-cache-batch-index-snapshot-2026-11-11.
- Child PR: to be created after the branch diff is reviewed.
- Keep this change Draft / unmerged until exact-head tests and parent-stack review complete.
