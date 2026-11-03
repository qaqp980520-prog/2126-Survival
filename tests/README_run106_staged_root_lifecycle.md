# Run 106 — Async staged-root lifecycle regression

The Director stages unparented chunk roots across frame boundaries before committing them to MineralChunkController. A root can be valid when first returned by the factory and then be externally queued for deletion or parented while the request is suspended.

The Run 106 guard revalidates every staged root:
- before requesting the next factory result,
- immediately after a factory callback (which may have side effects),
- after every staging yield,
- before commit, and
- before each individual registration during the non-yielding commit phase.

Invalid lifecycle transitions fail with a dedicated diagnostic reason:
- `staged_root_invalid`
- `staged_root_queued_for_deletion`
- `staged_root_parented`

The regression test makes the factory queue the first staged root while producing the second. It verifies that the request aborts before any root reaches the Controller, releases both the queued staged root and the uncommitted second candidate, clears staging state, and releases the active request lock.

No world-save schema or runtime chunk format changes are introduced.

Run with Godot 4.3+ from the repository root:

```sh
godot --headless --path . --script res://tests/mineral_grid_streaming_staged_root_lifecycle_test.gd
```
