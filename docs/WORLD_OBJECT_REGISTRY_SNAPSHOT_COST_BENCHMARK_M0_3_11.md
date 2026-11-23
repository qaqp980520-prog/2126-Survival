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
