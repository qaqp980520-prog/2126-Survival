# World Object State Chunk-Scoped Rollback — M0.3.10

## Purpose

Remove repeated full-registry deep copies from MineralChunkController chunk load, chunk unload, and loaded-state capture transactions while preserving rollback semantics.

## Version and source

- Parent PR #418 exact HEAD: `19ecf4ea29d39488dc0a420cd79d1f242d4cd00f`.
- Parent PR #279 exact HEAD: `f6b0dd1bfe7125a12e4354bcde389aab4cafe099`.
- Child branch: `perf/mineral-grid-chunk-scoped-object-state-rollback-2026-11-23-run393`.
- No save-schema change; WorldObjectStateRegistry schema remains version 1.

## Files

- `systems/MineralChunkController.gd`
- `tests/mineral_chunk_controller_test.gd`
- `docs/WORLD_OBJECT_STATE_CHUNK_SCOPED_ROLLBACK_M0_3_10.md`

## Runtime change

- For registries implementing `get_object_state`, `set_object_state`, and `forget_object_state`, capture only the stable IDs owned by the affected chunk.
- Rollback clears/reapplies only those scoped records. If a scoped restore attempt fails, the helper attempts to restore the pre-rollback scoped records and reports an error if that recovery also fails.
- Older/custom registries without `forget_object_state` retain the existing full `to_save_dict` / `restore_save_dict` fallback.
- Whole-world `restore_world_object_states` retains a full-registry snapshot because it intentionally replaces the entire registry payload.

## Complexity estimate

The production factory has one stateful prop per chunk. For the radius-1 → radius-8 expansion, 9 stale unloads, and radius-0 contraction sequence recorded in Run 392:

- Existing full-snapshot implementation: source-derived estimate of 127,413 copied registry records.
- Chunk-scoped implementation: 577 targeted record snapshots for 280 loads + 9 stale unloads + 288 contraction unloads.

This is a source-derived copy-count estimate, not a profiler measurement or a claim of measured frame-time improvement. A low-contention matched-runner benchmark is still required.

## Regression coverage

- A failure after the first default object record is written must remove that newly-created record and preserve unrelated unloaded-chunk records.
- Successful load, save capture, and unload must not call the full-registry serializer when the production registry supports scoped deletion.
- Legacy registries without `forget_object_state` must retain full-snapshot rollback behavior.
- Existing failed object-state application and unload rollback tests remain in place.

## Dependencies and import

Requires the Godot 4.3 root project and the existing MineralChunkController, WorldObjectStateRegistry, WorldObjectStatefulProp, MineralGridStreamingDirector, SurfaceWorld, and chunk lifecycle tests.

Import from the repository root:

```bash
godot --headless --path . --script tests/mineral_chunk_controller_test.gd
```

## Validation status

- Code and test changes are prepared on a child branch of PR #418.
- Godot 4.3 runtime validation is pending the exact-head GitHub Actions Full Gate and focused Mineral Grid lifecycle workflow.
- No local Godot executable is available in this environment; no local engine pass is claimed.
- No GPU, target-device, or performance improvement claim is made.

## Next steps

1. Run focused Mineral Grid lifecycle and full Godot 4.3 Full Gate on the exact child HEAD.
2. Inspect the full logs for Script/Parse/Runtime errors and rollback diagnostics.
3. Compare a low-contention matched-runner benchmark against the Run 392 baseline.
4. Obtain independent review before integrating this child into PR #418, then rerun the resulting exact parent HEAD.
5. Do not merge to main.
