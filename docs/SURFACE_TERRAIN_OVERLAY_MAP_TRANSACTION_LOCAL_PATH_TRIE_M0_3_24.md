# Surface Terrain Overlay Transaction-Local Path Trie (M0.3.24)

## Status

Implementation candidate on PR #439, stacked on PR #438. Exact-head Godot 4.3 Focused, Production Benchmark, and Full Compatibility Gate are pending.

## Purpose

M0.3.23 shallow-clones the root and every container on a changed path, but repeats those clones for every operation. Multiple edits under the same nested Dictionary/Array therefore clone common ancestors more than once.

M0.3.24 adds a transaction-local path trie per top-level key in `apply_nested_patches()`. The root container is cloned once per key, each distinct nested container is cloned on first traversal, and later operations reuse the cached cloned node.

## Implementation

- Create one private shallow clone of the stored root value for each top-level key in a batch.
- Create a transaction-local trie node for that root.
- Resolve each operation path through the trie; clone and attach a nested Dictionary/Array only when its path node is first visited.
- Reuse cached ancestors for subsequent operations that share the same path prefix.
- Invalidate a cached child when a Dictionary/Array leaf is replaced or erased.
- Clear all cached children beneath an Array after `erase`, because positional indices after the erased element shift.
- Keep Array `append` cache entries valid because existing indices do not move.
- Stage all top-level keys and operations before publishing any `_writes`; one invalid operation discards the entire candidate batch.
- Expose `path_trie_node_count` and `path_trie_cache_hit_count` in `get_stats()`.

## Files

- `systems/SurfaceTerrainOverlayMap.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `tests/surface_terrain_adjacency_delta_benchmark.gd`
- `.github/workflows/surface-terrain-adjacency-spatial-index-validation.yml`
- `docs/SURFACE_TERRAIN_OVERLAY_MAP_TRANSACTION_LOCAL_PATH_TRIE_M0_3_24.md`

## Dependencies and import

- Godot 4.3 root project.
- No third-party dependencies, scenes, autoloads, Project Settings, save-schema changes, or production controller wiring.
- The existing focused workflow runs the contract tests and benchmark; the full repository workflow remains the compatibility gate.
- Local commands:

~~~sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd
godot --headless --path . --script res://tests/surface_terrain_adjacency_delta_benchmark.gd
~~~

## Correctness contract

- Repeated operations under the same Dictionary ancestor reuse one cloned ancestor.
- Replacing a Dictionary leaf invalidates any cached descendant node beneath that leaf.
- Replacing an Array element invalidates that element's cached descendant.
- Erasing an Array element clears cached child nodes beneath that Array to prevent stale index reuse.
- Appending to an Array preserves cached nodes for existing indices.
- Invalid later operations do not publish any staged top-level key.
- The final materialized snapshot must exactly match the full Dictionary oracle.

## Benchmark contract

The nested-COW benchmark uses 225, 576, 2,048, and 8,192 top-level entries, five samples per size, and nine transactions per sample. Each transaction updates eight records, removes four keys, and inserts four keys. Each updated record performs four operations: set revision, append samples, set metadata.last_transaction, and set metadata.phase.

For each updated record, the path-trie batch is expected to clone exactly three path containers (root, samples Array, metadata Dictionary) and record one cache hit for the repeated metadata ancestor. Per transaction this is 24 path-container clones, 8 cache hits, and 24 trie nodes; per sample it is 216 clones and 72 cache hits. Stats collection is outside the timed interval. Final deep Dictionary parity remains mandatory.

The Dictionary full-copy and callback-COW implementations receive the same logical metadata update. Timing is synthetic headless data and is not production SurfaceWorld, rendered FPS, GPU, mobile, or target-device evidence.

## Complexity and limitations

- For each top-level key, the batch now clones its root once plus each distinct traversed nested container. Work is proportional to the root shallow-copy size plus the distinct container paths touched, not simply to the number of operations.
- Root cloning per key, inserted nested values, explicit reads/materialization, and depth-eight compaction can still be O(N).
- The transaction-local trie is discarded after staging; it is not a persistent cross-transaction index.
- Array erases conservatively invalidate all cached descendants under the affected Array.
- Object/Resource references are not cloned and must remain immutable while stored or be represented by stable IDs.
- The complete adjacency Index planner still has candidate scans and graph-closure costs. This does not establish end-to-end O(Δ).
- The full Binder rebuild remains the production correctness/recovery oracle.
- No production Index, MineralChunkController, Binder, Collider, scene, or save integration is included.

## Provenance

- Parent PR #438 exact HEAD: `26122588fd5c951429d133316b3f3a3d83bf57ca`.
- New branch: `perf/terrain-overlay-transaction-local-path-trie-2026-11-26-run436`.
- Run 436 is a child candidate only. Keep Draft until parent-chain independent review and exact-head validation are complete.
