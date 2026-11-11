# Mineral Chunk Controller Batch Patch-Scan Elision — M0.2.13.7

## Problem

During an active terrain-adjacency batch, `MineralChunkController.load_chunk()` previously performed these operations for every staged Chunk:

1. Scan every currently loaded `_chunk_objects` map with `_collect_loaded_terrain_patches()`.
2. Build an Array containing all existing patch Nodes.
3. Scan the incoming Chunk's `world_objects` with `_collect_terrain_patches()`.
4. Duplicate the existing Array and append the candidate patches.
5. Pass those collections to `_request_terrain_adjacency_rebind()`.

When `_terrain_adjacency_batch_depth > 0`, that method only marks the batch dirty and returns `{"ok": true, "deferred": true}`; it does not consume either Array or the candidate-object Dictionary. The batch finalizer later calls `_collect_loaded_terrain_patches()` once after all additions and removals have been recorded, then runs the shared incremental transaction.

Therefore the per-Chunk existing/candidate scans and Array allocations are discarded work. For a boundary request staging K Chunks while N Chunks are loaded, the redundant existing-set work is approximately O(K × N), in addition to the one authoritative finalization scan.

## Change

In `systems/MineralChunkController.gd`:

- If `_terrain_adjacency_batch_depth > 0`, call `_request_terrain_adjacency_rebind([], chunk_id, {})` directly.
- Do not build existing or candidate patch Arrays inside the batch.
- Preserve the existing full collection and rebind path when batch depth is zero.
- Keep `_record_terrain_batch_chunk_additions()` and `end_terrain_adjacency_batch()` unchanged. The added stable-ID patch map remains the authoritative source for the final incremental delta.

## Regression test

In `tests/mineral_chunk_controller_test.gd`:

- Add a test-only `CountingController` subclass that counts calls to `_collect_loaded_terrain_patches()`.
- Load two Chunks containing real `SurfaceTerrainPatch` Nodes inside one adjacency batch, with a real `WorldObjectStateRegistry`.
- Assert zero full loaded-patch collections during both per-Chunk registrations.
- Finalize the batch and assert exactly one full loaded-patch collection that includes both committed Patch Nodes.
- Load a third Chunk outside a batch and assert the normal single collection still occurs and sees the two previously loaded Patch Nodes.

This proves the optimization does not suppress the required batch-finalization snapshot or change the non-batched path.

## Dependencies and import

- Godot 4.3.
- Existing `MineralChunkController.gd`, `MineralVeinRegistry.gd`, `WorldObjectStateRegistry.gd`, `SurfaceTerrainPatch.gd`, and terrain adjacency Index / Coordinator / Collider Manager.
- No external packages, new runtime assets, autoloads, scene wiring, project settings, or save-schema changes.
- Open the repository root or use the existing headless import workflow; no manual import is required.

## Validation

- Focused Mineral Chunk Controller integration tests must pass, including the new collection-call-count regression with real Patch Nodes.
- Mineral Grid Streaming Lifecycle must pass.
- Production Surface Chunk Benchmark must pass and produce valid per-Chunk phase samples.
- Full Godot 4.3 compatibility gate must pass on the exact PR head before the change can be considered fully validated.
- Compare per-Chunk Controller Registration samples against PR #313, but do not claim a speedup from cross-run timings alone; runner and scene-tree variance must be accounted for.

## Limitations

- This change only removes redundant collection while a batch is active. It does not change the one authoritative full loaded-patch collection at batch finalization.
- It does not optimize the non-batched in-place terrain edit path.
- The expected complexity reduction is structural; the production Benchmark is required to quantify the actual effect.
- No rendered FPS, iPhone, GPU, target-device memory, touch, or PhysicsServer allocation-failure result is claimed.

## GitHub

- Parent PR #313 exact HEAD at branch creation: `84cd249ce1ba6217623b770c0b46cdca8443a579`.
- Branch: `perf/mineral-chunk-controller-skip-redundant-batch-patch-scan-2026-11-11`.
- This is a child PR in the existing terrain/streaming stack. Keep it Draft / unmerged until exact-head tests and parent-stack review complete.
