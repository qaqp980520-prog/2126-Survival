# Run 104 — queued chunk-root recovery

## Problem

Run 103 correctly rejected a factory root already queued for deletion. A separate lifecycle gap remained after a root had already been accepted by the controller and was later queued by another owner: the controller still reported it as loaded, so the director could skip regeneration until the node disappeared. If the director did attempt a reload after that point, the stale ownership entry could reject the replacement.

## Production change

- A queued root is no longer returned by get_chunk_root(), is_chunk_loaded(), get_loaded_chunk_ids(), or the loaded mineral/crop/world-object node enumerators.
- load_chunk() detects an existing root that is still valid but queued for deletion, runs the normal unload path first so mineral and stateful object records are captured, then registers the replacement.
- unload_chunk() does not queue_free() a root a second time when deletion is already scheduled.
- Invalid (already-freed) roots fail closed; this change does not guess or reconstruct lost runtime state.

## Regression

Run from the repository root with Godot 4.3+:
tests/mineral_grid_streaming_queued_root_recovery_test.gd

The test loads a chunk, queues its root externally, verifies live-query semantics, then asks the director to sync the same coordinate. It verifies that the old root is safely retired, a new root is registered, ownership maps remain aligned, and the old root is released after the frame.

## Dependencies and limits

Godot 4.3+. No new assets, plugins, network dependencies or world-save schema changes. World-save schema remains version 1. Local rendered GUI/GPU and physical iPhone QA remain separate.
