# Surface Terrain Overlay Batched Nested Patch Transactions — M0.3.22

## Purpose

Reduce repeated nested-container copying for transaction-shaped updates while preserving the M0.3.21 sealed-snapshot isolation contract. The existing callback API remains available for arbitrary local mutations; the new data-driven batch API provides an atomic path for callers that can describe edits as operations.

This is still an isolated prototype. It does not replace any Dictionary in SurfaceTerrainAdjacencyIndex and does not change MineralChunkController, Binder, Collider Manager, scenes, save data, or runtime behavior.

## Files

- `systems/SurfaceTerrainOverlayMap.gd` — adds `apply_nested_patches()`, nested path resolution, and data-driven set/erase/append operations.
- `tests/surface_terrain_adjacency_index_test.gd` — verifies multi-key commit, Dictionary and Array path updates, caller-value isolation, sealed-map rejection, duplicate-key rejection, and all-or-nothing behavior when a later path is invalid.
- `tests/surface_terrain_adjacency_delta_benchmark.gd` — compares Dictionary deep-copy, per-key callback COW, and atomic batch-patch COW at 225/576/2,048/8,192 entries; preserves depth-eight compaction and deep parity checks.
- `docs/SURFACE_TERRAIN_OVERLAY_MAP_BATCHED_NESTED_PATCH_M0_3_22.md` — this record.

## API contract

`apply_nested_patches(patches: Array) -> bool` accepts entries shaped as:

~~~gdscript
{
    "key": "record/stable-id",
    "operations": [
        {"op": "set", "path": ["metadata", "revision"], "value": 4},
        {"op": "append", "path": ["history"], "value": 4},
        {"op": "erase", "path": ["metadata", "obsolete"]}
    ]
}
~~~

- `set` updates a Dictionary key or an existing Array index.
- `append` appends to an Array resolved by the supplied path; an empty path targets a top-level Array value.
- `erase` removes an existing Dictionary key or Array index.
- Each top-level key must exist, be unique within the batch, and contain a Dictionary or Array.
- Every target is cloned and all operations are staged before any write is published.
- One invalid key, path, operation, or value aborts the entire batch without publishing earlier staged keys.
- Inserted Array/Dictionary values are cloned before attachment, so caller-owned references cannot mutate committed snapshots.
- Staged target containers are transferred into the child map only after validation; unlike callback-based `mutate_value()`, the batch path does not perform a second full clone of each target container.
- A sealed snapshot rejects a batch. An empty batch is a no-op on an unsealed snapshot.

## Benchmark protocol

For each fixture size (225, 576, 2,048, 8,192), five samples execute nine sequential transactions. Each transaction updates eight nested records, removes four keys, inserts four keys, and checks the same touched-key checksums.

Three paths are compared:

1. Dictionary deep-copy oracle.
2. Overlay fork plus one callback-based `mutate_value()` per updated record.
3. Overlay fork plus one atomic `apply_nested_patches()` call for all updated records.

Patch construction is included in the batch timing. The ninth transaction includes depth-eight compaction. Final materialized Dictionary equality and cached-size parity are mandatory for both overlay paths.

## Dependencies and execution

- Godot 4.3 root project; no third-party packages, scenes, autoloads, Project Settings, or save-schema changes.
- Focused workflow: Surface Terrain Adjacency Spatial Index Validation.
- Contract command:

~~~sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd
~~~

- Benchmark command:

~~~sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_delta_benchmark.gd
~~~

## Limitations

- This remains an isolated prototype; no production Index/Controller/Binder/Collider adoption.
- Root construction, defensive reads, explicit materialization, and depth-eight compaction remain O(N) boundaries.
- Each touched top-level nested value is still cloned once; this is not a persistent tree with path-level structural sharing inside a nested value.
- Object/Resource references are not cloned and must remain immutable while stored or be represented by stable IDs.
- Synthetic headless timings are not production SurfaceWorld, GPU, rendered FPS, mobile, or target-device evidence.
- The full Binder rebuild remains the production correctness/recovery oracle.

## Provenance

- Parent PR #436 exact HEAD: `84b688b969b170b6466837c6803be5830c594201`.
- PR #438 prior exact HEAD: `0e56815cbe5001daa9a548e1be9fbeee317ed41a`.
- Working branch: `work/pr438-batch-nested-patch-2026-11-25-run433`.
- Backup branch: `backup/pr438-before-batch-nested-patch-2026-11-25-run433`.
- No production behavior, main branch, or save schema is changed by this prototype.
## Exact-head validation

The implementation and benchmark code were tested on code HEAD `25cdcd6f9e7b810d1ff24cacb4400f33567fae4f`:

- Focused Godot 4.3 spatial-index workflow [45642336073](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45642336073): 14/14 steps, 4,893 PASS lines, zero FAIL/ERROR/SCRIPT ERROR diagnostics; the log includes the new batch contract assertions and all four nested-COW fixture records.
- Production Surface Chunk Benchmark [45642336100](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45642336100): 11/11 steps, 301 PASS, 21 JSONL records, zero FAIL/ERROR/SCRIPT ERROR diagnostics. This is a baseline only; the overlay prototype is not wired into production.
- Full Godot 4.3 Compatibility Gate [45642336138](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45642336138): 559/559 steps successful, 78,952 PASS lines, zero failed steps, zero skipped steps. The complete log was independently fetched and audited (7,806,627 characters / 85,364 lines); after excluding echoed shell-guard commands there are zero actual Godot Script/Parse/Runtime/ERROR/FAIL diagnostics, zero ObjectDB leaks, and zero Orphan StringName diagnostics.
- The Full Gate has 23 existing Godot warnings: 19 filled-mode `draw_rect()` width warnings, 1 nested KROLL project warning, 1 stale mineral-unload rollback warning, and 2 synchronous mineral-registration rollback warnings. One GitHub Actions Node.js 20 deprecation warning also remains.
- Focused artifact 15033489917 ZIP SHA-256: `2671291380da7fc3317f2b2c73f04785d837af1f5a5e056b53ea362e9ceb317b`.
- Production artifact 15036490896 ZIP SHA-256: `9a4b7e686d1eaf66ea346a30e3a3f7e9611b759cf89d2548c4e73bacfe28ab7d`.
- No local Godot executable is available; engine tests ran on GitHub Actions Godot 4.3.
- A documentation-only follow-up commit records these results. It does not change the tested GDScript or test files; the Full Gate workflow also watches `docs/**`, so the documentation-only HEAD receives its own Full Gate run.
