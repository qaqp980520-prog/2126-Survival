# WorldObjectStateRegistry Snapshot Cost Benchmark — M0.3.11

## Purpose

Add a deterministic, repeatable headless benchmark for the production `WorldObjectStateRegistry` APIs used by PR #419's chunk-scoped rollback.

The benchmark isolates snapshot-copy work from chunk factory, terrain adjacency, GPU rendering, and frame scheduling. It complements (but does not replace) the controller integration regressions.

## Version and dependency

- Benchmark branch: `perf/world-object-registry-snapshot-benchmark-2026-11-23-run395`.
- Parent candidate: PR #419, `853c541912496a7f3d99faaa4b2b1bb013e632ff`.
- Uses the production `systems/WorldObjectStateRegistry.gd` implementation.
- No production runtime code or save schema is changed.
- No third-party dependencies.

## Benchmark design

- Seed the production registry with 289 records, each containing eight bounded primitive properties.
- Perform 577 equivalent snapshot transactions per sample.
- Full path: call `to_save_dict()` for every transaction, counting all returned object records.
- Scoped path: call `get_object_state()` for one target stable ID per transaction, counting returned records.
- Warm up both paths, then run five measured samples in alternating order.
- Report median elapsed microseconds as informational data only.
- Assert exact copy-volume counts and defensive-copy behavior. Do not assert a wall-clock speed ratio.

## Deterministic expected result

Per measured sample:

| Metric | Full registry | Chunk-scoped |
| --- | ---: | ---: |
| Registry records | 289 | 289 |
| Transactions | 577 | 577 |
| Top-level object records copied | 166,753 | 577 |
| Record-copy reduction | — | 289× |

These are top-level record-copy counts for this fixed steady-state microbenchmark. They are not a replay of the Run 392 expansion/contraction timeline, not a full deep-node allocation count, and not an FPS or end-to-end chunk-streaming result.

## Files and import

- `tests/world_object_registry_snapshot_benchmark.gd`
- `.github/workflows/godot-validation.yml`

Run from repository root with Godot 4.3:

```bash
godot --headless --path . --script res://tests/world_object_registry_snapshot_benchmark.gd
```

The script emits a `WORLD_OBJECT_REGISTRY_BENCHMARK_JSON:` line containing the median timings and deterministic record counts.

## Validation status

- The script is wired into the Godot Full Compatibility Gate after the MineralChunkController integration tests.
- Exact-head GitHub Actions validation is required before treating the benchmark as accepted.
- Local Godot execution is not claimed.
- Timings are runner-dependent and informational; no runtime performance improvement is claimed from a timing ratio.

## Next steps

1. Run the exact-head Full Compatibility Gate on the benchmark branch.
2. Inspect the JSON marker and ensure all deterministic assertions pass.
3. Retain the timing values as a reproducible API microbenchmark baseline, not as player-facing frame-time evidence.
4. Keep the PR stacked on #419; obtain independent review before parent-first integration.

## Final exact-head validation — 2026-11-23

- Candidate HEAD: `a7b80be50cf7c922b03aa1f34026b472fa4f67ce`; parent PR #419 exact HEAD: `853c541912496a7f3d99faaa4b2b1bb013e632ff`; compare 4 ahead / 0 behind.
- All 19/19 PR-triggered workflow runs succeeded.
- Godot 4.3 Full Compatibility Gate [45208355851](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45208355851): 554/554 job steps successful, 0 failed, 0 skipped.
- The benchmark step emitted:
  - Full snapshot median: 410,903 µs per 577 transactions.
  - Scoped snapshot median: 1,456 µs per 577 transactions.
  - Top-level object records copied per sample: 166,753 full versus 577 scoped (289× deterministic count reduction).
- Mineral Grid Streaming Lifecycle [45208356072](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45208356072): 14/14 successful steps.
- Full Gate log audit: 7,742,928 characters / 84,713 lines / 78,359 PASS matches / 23 retained warnings; 0 actual Script/Parse/Runtime/FAIL diagnostics, 0 ObjectDB leaks, 0 Orphan StringName diagnostics.
- The 23 warnings remain: 19 filled draw_rect width notices, 1 nested-project notice, 1 stale-unload rollback warning, and 2 synchronous-registration rollback warnings. None is claimed fixed.
- Timings are runner-specific and informational. The benchmark isolates production registry snapshot API calls; it is not a controller end-to-end, Run 392 lifecycle replay, full nested-allocation count, GPU, or FPS measurement. No gameplay performance improvement is claimed.
- No local Godot executable, GPU, or target-device pass is claimed.

## Review and integration status

- Child PR [#420](https://github.com/qaqp980520-prog/2126-Survival/pull/420) is Open / Ready for Review / Mergeable / Unmerged.
- Independent review submissions: 0; inline review threads: 0.
- Keep PR #420 stacked on #419; integrate only after independent review and parent-first validation. No merge to main.
