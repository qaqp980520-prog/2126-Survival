# Run 120 — Synchronous Mineral Chunk Registration Lifecycle Guard M0.1

## Source and regression

- Source: systems/MineralGridStreamingDirector.gd.
- Test fixture: tests/helpers/FakeMineralChunkController.gd.
- Regression: tests/mineral_grid_streaming_sync_registration_lifecycle_test.gd.

## Finding

The synchronous sync_to_world_position path checked Controller lifecycle after the factory callback but did not revalidate it after Controller.load_chunk returned. A Controller could detach or queue itself during the final registration callback and the Director could report success or leave an inconsistent managed window.

The existing _restore_unloaded_chunks path already revalidated after registration; this update brings the synchronous streaming path to the same ownership discipline.

## Behavior

- Verify that load_chunk actually registered the requested chunk.
- Recheck Controller validity, scene-tree membership and queued-for-deletion state immediately after the callback.
- Record a newly registered chunk before rollback so a failed unload remains represented in the Director ownership mirror.
- Roll back the entire newly loaded window when a live Controller detaches.
- Never call unload_chunk on a Controller queued for deletion.
- Report incomplete cleanup honestly when the owner is queued/destroyed and its child roots will be released by owner teardown.

## Compatibility

- Public Director method signatures are unchanged.
- Chunk IDs and world-save schema are unchanged.
- Asynchronous staging/commit behavior is unchanged.
- The fake Controller gains deterministic detach/queue callbacks solely for regression tests.

## Verification

Exact-head Godot 4.3 focused and full compatibility CI must pass before merge. Local GUI/GPU/iPhone QA remains separate.
