# Run 103 — queued-for-deletion chunk root rejection

## Problem
A factory can return a Node3D that is still instance-valid and unparented but has already been queued for deletion. The synchronous streaming path and direct MineralChunkController API previously did not reject that lifecycle state explicitly. A root accepted into ownership could be freed at the end of the frame, leaving stale ownership records. Async staging also needs to reject the state at its boundary rather than relying on a later validity check.

## Production change
- MineralGridStreamingDirector synchronous factory loading, async staging and stale-chunk restoration now reject roots whose `is_queued_for_deletion()` is true.
- The sync/async failure details record `factory_root_queued_for_deletion`.
- `_free_unowned_root()` no longer calls `free()` on a root already queued for deletion.
- MineralChunkController.load_chunk() independently rejects queued roots at the ownership boundary.

## Regression
Run from repository root:
```
godot --headless --path . --script res://tests/mineral_grid_streaming_queued_root_rejection_test.gd
```
The test covers direct controller registration, synchronous loading, async staging and rollback restoration. It verifies no controller/director ownership is created and the scheduled deletion is not double-freed.

## Dependencies and limits
Godot 4.3+. No world-save schema change (schema 1), no new assets/plugins/network dependency. Local Godot is not available in this run; exact engine validation is through cloud Godot 4.3 CI. Rendered GUI/GPU and physical iPhone QA remain separate.
