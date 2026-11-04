# Run 108 — rollback Controller lifecycle regression

The synchronous rollback helpers must not restore chunk roots through a Controller whose lifecycle has changed.

## Covered cases

1. The chunk factory detaches the Controller while `_restore_unloaded_chunks()` is obtaining a replacement. The candidate must be released and `load_chunk()` must not be called.
2. The Controller detaches itself from its parent inside `load_chunk()`. The just-restored root must be unloaded again, the Director must not claim it, and the helper must return failure.
3. `_rollback_new_loads()` is invoked after its Controller is queued for deletion. It must not call methods on that Controller; it clears stale Director ownership and reports an incomplete rollback when there were IDs to undo.

## Production behavior

- `_restore_unloaded_chunks()` validates Controller readiness and factory availability before each restoration and immediately after the factory callback.
- It revalidates after `load_chunk()`. A root registered while the Controller detaches is rolled back when the Controller is still alive; queued/destroyed Controllers are not called.
- `_rollback_new_loads()` permits cleanup through a detached-but-live Controller, but refuses calls to a queued or invalid Controller and clears the Director's stale managed map.
- No world-save or chunk schema change; schema remains version 1.

Run with Godot 4.3+ from the repository root:

`godot --headless --path . --script res://tests/mineral_grid_streaming_rollback_lifecycle_test.gd`
