# Surface Terrain Overlay Path-Level Nested Copy-on-Write (M0.3.23)

## Status

Implementation candidate on PR #438. Exact-head Godot 4.3 validation and benchmark results are pending.

## Purpose

Reduce the cost of `apply_nested_patches()`. M0.3.22 cloned each complete top-level nested Array/Dictionary before applying a small number of edits. M0.3.23 changes that staging path to shallow-clone only the root container and the Array/Dictionary containers along each edited path.

## Implementation

- `_get_stored_value()` is an internal-only lookup used by the transaction method; it must never be returned to callers.
- `_clone_container_path()` shallow-clones the root and each container traversed by the requested path. Unmodified descendant subtrees remain shared with the sealed parent snapshot.
- `set`, `erase`, and `append` operate only on the cloned target path.
- Inserted Array/Dictionary values are still deep-cloned before attachment, so caller-owned values cannot leak into a snapshot.
- All top-level keys are staged before any child writes are published. A later invalid operation discards every staged root.
- Public `get_value()`, `materialize()`, `_get_base_dictionary()`, and `_get_overlay_changes()` continue to return detached containers.
- `get_stats()` now reports `path_container_clone_count`, and the benchmark asserts the exact path-copy count.

## Files

- `systems/SurfaceTerrainOverlayMap.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `tests/surface_terrain_adjacency_delta_benchmark.gd`
- `.github/workflows/surface-terrain-adjacency-spatial-index-validation.yml`
- `docs/SURFACE_TERRAIN_OVERLAY_MAP_PATH_LEVEL_NESTED_COW_M0_3_23.md`

## Dependencies and import

- Godot 4.3 root project.
- No third-party packages, scenes, autoloads, Project Settings, or save-schema changes.
- Still isolated to the Overlay Map prototype; no production Index, MineralChunkController, Binder, or Collider wiring.
- Run the contract and benchmark with:

~~~sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd
godot --headless --path . --script res://tests/surface_terrain_adjacency_delta_benchmark.gd
~~~

## Validation

Pending exact-head Focused Spatial Index Validation, Production Surface Chunk Benchmark, and Full Compatibility Gate. The benchmark uses 225, 576, 2,048, and 8,192 entries, five samples per size, nine transactions per sample, eight updated records per transaction, four removals, and four insertions. Each record includes a nested payload with 80 scalar values that remains untouched by the patch set. The batch path must report exactly 360 shallow path-container clones per sample and match the full Dictionary oracle after all nine transactions. Timing excludes assertion and stats-query overhead; patch construction remains included in the batch path because callers must build the transaction payload.

## Complexity and limitations

- For each patch operation, staging copies the root and the container ancestors along the edited path; untouched nested subtrees are shared with sealed ancestors.
- Repeated operations on the same top-level key may clone common ancestors more than once. This is bounded by the sum of edited path depths, not yet a deduplicated per-transaction trie.
- Root construction, defensive reads, explicit materialization, and depth-eight compaction remain O(N).
- `set_value()` and callback-based `mutate_value()` still deep-clone inserted or edited containers.
- Object/Resource references are not cloned and must remain immutable while stored or be represented by stable IDs.
- The complete adjacency Index planner still has candidate scans and graph-closure costs; this utility does not prove end-to-end O(Δ).
- The full Binder rebuild remains the production correctness/recovery oracle.
- Synthetic headless measurements are not production SurfaceWorld, GPU, rendered FPS, mobile, or target-device evidence.

## Provenance

- Parent PR #436 exact HEAD: `84b688b969b170b6466837c6803be5830c594201`.
- Prior PR #438 exact HEAD: `9d9ef25bc6d217eba8bd23738230959e63bccf20`.
- Pre-change backup branch: `backup/pr438-before-path-level-cow-2026-11-26-run11`.
