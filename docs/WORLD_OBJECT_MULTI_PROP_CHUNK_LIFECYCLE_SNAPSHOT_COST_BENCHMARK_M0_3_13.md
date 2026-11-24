# World Object Multi-Prop Chunk Lifecycle Snapshot Cost Benchmark — M0.3.13

## Purpose

Extend M0.3.12's one-stateful-prop-per-chunk controller lifecycle benchmark with a dense four-prop-per-chunk scenario. This checks that chunk-scoped snapshot accounting scales with all stable IDs in an affected chunk, not just a single object.

## Benchmark contract

- Use the production Godot 4.3 `MineralChunkController`, `WorldObjectStateRegistry`, `MineralVeinRegistry`, and `WorldObjectStatefulProp`.
- Seed 289 unrelated unloaded-chunk records and 4 saved stateful-prop records for each of 289 target chunks (1,445 records total).
- Load 289 real chunk roots with four stateful props each (1,156 live props).
- Verify that all saved states are applied to the live props.
- Interact with every live prop independently, capture all loaded object states once, then unload all chunks.
- Verify all 1,156 changed prop records and all 289 unrelated unloaded records survive with their expected state.
- Compare the production scoped controller with a test-only controller subclass that overrides only the snapshot helper to reproduce the pre-M0.3.10 full `to_save_dict()` policy.
- Both paths execute 579 snapshot transactions: 289 loads + 1 loaded-state capture + 289 unloads.

## Deterministic expected result

- Full-snapshot baseline: 1,445 registry records × 579 transactions = **836,655** top-level records copied.
- Production scoped path: 1,156 affected records × 3 snapshot phases = **3,468** top-level records copied.
- Expected deterministic top-level record-copy reduction: **241.25×**.

These are top-level record counts, not total nested allocations or bytes. The controller lifecycle and state integrity assertions are the correctness gates; timing is one headless CI sample per strategy and informational only.

## Files

- `tests/world_object_multi_prop_chunk_lifecycle_benchmark.gd` — dense four-prop-per-chunk headless lifecycle benchmark.
- `.github/workflows/godot-validation.yml` — input guard and Full Compatibility Gate execution step.
- `docs/WORLD_OBJECT_MULTI_PROP_CHUNK_LIFECYCLE_SNAPSHOT_COST_BENCHMARK_M0_3_13.md` — this version record.

## Dependencies and import

- Godot 4.3 root project.
- `systems/MineralChunkController.gd`
- `systems/WorldObjectStateRegistry.gd`
- `systems/MineralVeinRegistry.gd`
- `systems/WorldObjectStatefulProp.gd`

Run from the repository root:

```
godot --headless --path . --script res://tests/world_object_multi_prop_chunk_lifecycle_benchmark.gd
```

The test is also executed by the Godot Full Compatibility Gate after the M0.3.12 one-prop controller lifecycle benchmark.

## Validation status at branch creation

- Branch: `perf/world-object-multiprop-lifecycle-benchmark-2026-11-24-run398`.
- Parent PR #421 exact HEAD: `3fee5563f71f6427abfb89876e3147433dee7fc8`.
- Exact-head CI: pending.
- No local Godot executable is available in this environment; no local engine pass is claimed.
- No GPU, target-device, gameplay frame-time, or FPS claim is made.

## Limitations and next steps

- One fixed density (four stateful props per chunk) is tested; other object densities and mixed stateful/non-stateful distributions are not exhaustively profiled.
- Timings are a single CI-runner sample; deterministic record-copy counts are the primary assertion.
- The test does not measure GPU, rendered FPS, target-device performance, total nested allocation bytes, or player-visible frame pacing.
- Keep this child stacked on PR #421. Do not merge to #421, #420, #419, #418, #279, or main before independent review and parent-first exact-head revalidation.
