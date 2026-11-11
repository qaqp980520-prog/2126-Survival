# Mineral Chunk Controller Batch Snapshot Failure Fallback — M0.2.13.9

## Problem

M0.2.13.8 introduced a lazy, batch-scoped original Index Patch-map snapshot. The snapshot helper intentionally returns an empty Dictionary when the Index read is unavailable, and leaves the cache uncaptured so a later event can retry.

A static review of the real removal recorder found that an empty return value is ambiguous: it can mean either a valid empty Index or a failed snapshot read. During a Chunk removal, the recorder interprets the failed read as an empty baseline. It can therefore erase the removal delta as though the Patch had been added and removed within the same batch. If the batch then takes the incremental path, the pending Chunk root could be retired while its Patch remains in the committed Index.

The previous transient-read test called the snapshot helper directly and did not exercise this removal/finalization interaction.

## Change

Files:

- `systems/MineralChunkController.gd`
- `tests/mineral_chunk_controller_test.gd`
- `docs/MINERAL_CHUNK_CONTROLLER_BATCH_SNAPSHOT_FAILURE_FALLBACK_M0_2_13_9.md`

Implementation:

- Add `_terrain_adjacency_batch_requires_full_rebind`.
- Any unavailable or invalid baseline snapshot marks the current outer batch for authoritative full Binder reconciliation.
- Keep this marker sticky for the rest of the batch. A later successful snapshot cannot retroactively repair delta classifications already recorded against an empty map.
- `end_terrain_adjacency_batch()` bypasses the incremental coordinator when the marker is set and uses the existing full Binder path over the authoritative live Patch set. Pending-unload Chunk roots are excluded from that set and are only freed after the rebind succeeds.
- If the fallback rebind fails, retain the existing pending-unload rollback and recovery/reconciliation protections; do not silently finalize a partially reconciled batch.
- Clear the marker with the other batch-scoped delta state.

This is a correctness fallback, not a performance optimization. It is used only when the baseline Index snapshot cannot be trusted.

## Regression coverage

A new real Controller integration regression:

1. Loads a real `SurfaceTerrainPatch` Chunk and verifies one committed Index entry.
2. Starts an adjacency batch.
3. Injects a one-shot failure in the baseline Index-map read during `unload_chunk()`.
4. Verifies the batch is marked for full rebind.
5. Ends the batch and verifies the authoritative full Binder path is selected.
6. Verifies the removed Patch is absent from the committed Index, the Chunk root is retired only after rebind success, and no recovery state remains.
7. Verifies the fallback marker is cleared after finalization.

The existing direct transient-read retry test remains in place to verify that a failed read is not cached as an empty snapshot.

## Dependencies and import

- Godot 4.3.
- `MineralChunkController.gd`
- `SurfaceTerrainAdjacencyIndex.gd`
- Existing `SurfaceTerrainAdjacencyBinder.gd`, `SurfaceTerrainAdjacencyCoordinator.gd`, and `SurfaceTerrainTransitionColliderManager.gd`.
- Existing Mineral Chunk lifecycle adapter, vein registry, and WorldObjectStateRegistry (required by the stateful SurfaceTerrainPatch test fixture).

No external packages, autoloads, project settings, scene wiring, save-schema changes, or new runtime assets. Open the repository root or run the existing headless validation workflow; the root import step uses the existing deterministic Godot `--import` barrier.

## Validation status

- Parent PR #315 exact HEAD: `3e1cd1b8dafbb6d1935b8a7d7fe06ca97770ba39`.
- Parent PR #315 Full Godot 4.3 Gate: 554/554 success, 0 failures, 0 skipped.
- This child PR requires its own exact-head Controller integration, Full Godot 4.3 Gate, and production benchmark runs. No child pass is claimed until those exact-head workflows complete.
- Local Godot executable is unavailable in this environment; engine validation is performed by GitHub Actions with Godot 4.3.
- Headless tests do not validate rendered FPS, GPU performance, or physical-device behavior.

## Next steps

1. Run the new Controller integration regression on the exact child HEAD.
2. Complete the full Godot 4.3 compatibility gate and inspect the rollback/final-cleanup steps.
3. Verify the production benchmark remains structurally unchanged and free of engine errors.
4. Keep this child Draft/unmerged until parent-stack review; do not merge main or merge this child ahead of PR #315.
