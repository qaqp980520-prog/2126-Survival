# Mineral Grid Synchronous Window Adjacency Batch — M0.2.11

## Purpose

Bring synchronous `MineralGridStreamingDirector.sync_to_world_position()` window shifts under the same controller-level terrain adjacency batch contract already used by the asynchronous path.

Before this change, the synchronous path called `load_chunk()` and `unload_chunk()` one at a time. A production `MineralChunkController` could therefore perform a full terrain adjacency/collider rebind for each chunk registration or retirement during one player-window move.

The updated path opens one adjacency batch around the complete synchronous shift. Chunk loads and pending retirements are staged inside that batch, and the controller performs one shared rebind when the batch closes.

## Changed files

- `systems/MineralGridStreamingDirector.gd`
  - Public `sync_to_world_position()` now opens a batch when the bound controller supports both `begin_terrain_adjacency_batch()` and `end_terrain_adjacency_batch()`.
  - The previous implementation is retained as `_sync_to_world_position_unbatched()` for controllers without the batch contract.
  - Successful reports include both `newly_loaded_ids` and `unloaded_stale_ids`.
  - If the first batch commit fails after registrations succeeded, the Director opens a recovery batch, retires newly loaded roots, restores any stale roots that were already retired, and reconciles its managed-ID mirror from the controller.
  - If the inner load/registration operation fails, the existing rollback is completed inside the open batch and the wrapper closes that batch before returning.
  - If the Director mirror contains a managed ID whose Controller root is no longer live (for example, an externally queued root), retain the immediate unbatched replacement path. This prevents a same-ID replacement from overwriting the Controller slot while the old root is still a pending batch retirement.

- `tests/mineral_grid_streaming_director_test.gd`
  - Verifies that a nine-chunk initial window produces exactly one controller adjacency rebind.
  - Verifies that a window shift with three new chunks and three stale chunks produces exactly one additional rebind.
  - Verifies that a partial factory failure closes one rollback batch and preserves the previous window.
  - Adds a batch-aware fake controller that injects one batch-commit failure and proves the Director restores the previous nine-chunk window in one recovery batch.
  - Uses the production Controller to verify same-coordinate queued-root recovery retains the immediate unload/reload replacement path and does not enter the pending-unload batch path.

- `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`
  - Adds the Director regression test to pull-request and push path filters.
  - Runs the synchronous window batch/recovery regression in the focused lifecycle workflow.

## Dependencies and integration

- Godot 4.3.
- `MineralGridStreamingDirector`.
- Controller contract:
  - `begin_terrain_adjacency_batch() -> bool`
  - `end_terrain_adjacency_batch() -> Dictionary`
  - Existing `load_chunk()`, `unload_chunk()`, `is_chunk_loaded()`, and `get_loaded_chunk_ids()` methods.

No new assets, imported resources, autoloads, or project settings are required. The change uses the existing controller API and remains compatible with older/fake controllers that do not expose both batch methods.

## Transaction and recovery contract

1. Capture the Director's previous managed chunk map.
2. Begin one controller adjacency batch.
3. Run the existing synchronous load-first / stale-retirement algorithm.
4. Close the batch once.
5. If the inner operation failed, preserve its rollback result and include the batch-close result.
6. If the inner operation succeeded but batch commit failed:
   - Use the captured previous map to identify stale chunks.
   - Roll back newly loaded chunks inside a recovery batch.
   - Restore stale chunks that are no longer loaded.
   - Close the recovery batch.
   - Reconcile the Director mirror from the controller.
7. Report rollback as complete only if both restoration and the recovery batch succeed.

## Validation

The focused test added in this PR is `tests/mineral_grid_streaming_director_test.gd`. It checks the exact rebind count for initial load, successful shift, and failed partial load, plus a commit-failure recovery scenario.

CI status is pending until GitHub Actions runs against the PR head. Do not treat static inspection or a workflow queued/running state as a passing Godot test.

## Limitations

- This change batches synchronous window shifts; it does not yet replace the controller's one-per-batch full Binder rebind with the M0.2.10 Index/Coordinator delta path.
- The asynchronous path already has its own staging/commit batch and is not rewritten here.
- A persistent controller recovery failure remains reported as incomplete; the Director does not claim success or silently discard the controller's ownership state.
- GPU, rendered FPS, mobile device performance, and physics-server allocation failure injection are outside this validation.

## Next step

Integrate the persistent adjacency Index and three-participant Coordinator into the controller batch boundary, retaining this single-batch synchronous wrapper as the outer transaction boundary. Then benchmark a real Radius 8 shift with non-zero Transition Edge and Corner Cap resources.
