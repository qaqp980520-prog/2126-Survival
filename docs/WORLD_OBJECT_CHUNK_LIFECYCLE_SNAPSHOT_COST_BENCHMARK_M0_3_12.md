# World Object Chunk Lifecycle Snapshot Cost Benchmark — M0.3.12

## Purpose

Measure the M0.3.10 chunk-scoped object-state snapshot policy through the production MineralChunkController load, loaded-state capture, and unload entry points. The earlier M0.3.11 benchmark measured the registry APIs directly; this benchmark adds a matched controller-lifecycle scenario.

## Benchmark contract

- Use the production Godot 4.3 `MineralChunkController`, `WorldObjectStateRegistry`, `MineralVeinRegistry`, and `WorldObjectStatefulProp`.
- Seed 289 unrelated unloaded-chunk records plus 289 saved records for the chunks about to be loaded (578 total registry records).
- Load 289 stateful chunks, capture the complete loaded world-object set once, then unload all 289 chunks.
- Run the same lifecycle with a test-only controller override that restores the pre-M0.3.10 full `to_save_dict()` snapshot policy, and with the production chunk-scoped snapshot policy.
- Both paths execute 579 snapshot transactions: 289 loads + 1 world-state capture + 289 unloads.
- Verify all 578 records survive and preserve their expected state.
- Count top-level registry records copied by each snapshot strategy. Timing is a single matched CI sample per path and informational only; no wall-clock ratio is asserted.

## Deterministic expected result

For this fixed scenario:

- Full-snapshot baseline: 578 records × 579 transactions = 334,662 top-level records copied.
- Production scoped path: 289 load records + 289 capture records + 289 unload records = 867 top-level records copied.
- Expected deterministic top-level record-copy reduction: 386×.

This is a controlled snapshot-policy comparison through the controller lifecycle. The full-snapshot baseline is a test-only override of the snapshot helper; all load/capture/unload logic otherwise uses the same controller source. Counts are top-level registry records, not total nested allocations or bytes.

## Files

- `tests/world_object_chunk_lifecycle_benchmark.gd` — headless matched controller lifecycle benchmark.
- `.github/workflows/godot-validation.yml` — input guard and Full Compatibility Gate execution step.
- `docs/WORLD_OBJECT_CHUNK_LIFECYCLE_SNAPSHOT_COST_BENCHMARK_M0_3_12.md` — this version record.

## Dependencies and import

- Godot 4.3 root project.
- `systems/MineralChunkController.gd`
- `systems/WorldObjectStateRegistry.gd`
- `systems/MineralVeinRegistry.gd`
- `systems/WorldObjectStatefulProp.gd`

Run from the repository root:

```bash
godot --headless --path . --script res://tests/world_object_chunk_lifecycle_benchmark.gd
```

The benchmark is also executed by the Godot Full Compatibility Gate after the M0.3.11 registry API benchmark.

## Validation status at branch creation

- Branch: `perf/world-object-chunk-lifecycle-benchmark-2026-11-24-run397`.
- Parent candidate: PR #420 HEAD `f5c4bce71fdf3c19ae3c245306b51b4bfb2f2d45`.
- Exact-head CI: pending.
- No local Godot executable is available in this environment; do not claim a local engine pass.
- No GPU, target-device, gameplay frame-time, or FPS claim is made.

## Limitations and next steps

- CI timing is a single runner-specific sample per path; deterministic record-copy counts are the primary assertion.
- The benchmark uses 289 chunks with one stateful prop each and 289 unrelated saved records. It does not represent every possible world distribution or multi-prop chunk.
- If this exact-head test passes, record the measured phase timings and complete Full Gate audit, then request independent review.
- Keep this child stacked on PR #420. Do not merge to #420, #419, #418, #279, or main before independent review and parent-first exact-head revalidation.
