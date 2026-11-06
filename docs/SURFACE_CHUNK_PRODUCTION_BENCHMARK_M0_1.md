# Production Surface Chunk Factory Benchmark M0.1

## Purpose

Measure the real playable-world chunk factory and controller at supported load radii. This is separate from the deterministic fake-controller transaction regression: it instantiates `world/SurfaceWorld.tscn`, uses the production `SurfaceChunkFactory.make_chunk` callable, and commits/unloads roots through the real `MineralChunkController`.

No production radius cap or default is changed by this benchmark.

## Dependencies

- Godot 4.3 root project.
- `world/SurfaceWorld.tscn` and `world/SurfaceWorld.gd`.
- `systems/SurfaceChunkFactory.gd`.
- `systems/SurfaceTerrainPatch.gd`.
- `systems/MineralChunkController.gd`.
- `systems/MineralGridStreamingDirector.gd`.
- Existing mineral, crop, world-object and terrain-adjacency dependencies loaded by the production SurfaceWorld.

## What is measured

The harness runs radii 1, 2, 3, 4 and 8. For each radius it:

1. Expands to a distant, non-overlapping window using the production async Director and the real factory/controller.
2. Verifies the exact active surface chunk count `(2r + 1)^2`.
3. Verifies Director and Controller surface chunk IDs are identical.
4. Verifies the exact staged, committed and retired chunk counts.
5. Counts every Node below the committed surface chunk roots.
6. Samples process-frame intervals during staging/commit and records average, p95 and maximum intervals.
7. Records process static memory, process node count, factory-call count and factory construction time.
8. Contracts to radius 0, verifies exactly `(2r + 1)^2 - 1` stale roots are unloaded, and checks weak references to departed roots are released after two process frames.

Each request uses `max_staged_per_frame = 1`, matching the current playable-world movement request cadence.

## Output

The script emits ten `SURFACE_CHUNK_BENCHMARK_JSON:` records (expansion and contraction for each radius). The dedicated GitHub Actions workflow captures both the readable log and JSON Lines artifact.

Fields include:

- radius, desired and active surface chunk counts;
- recursive surface-node count and average nodes per active chunk;
- factory calls and factory construction milliseconds;
- total async transaction milliseconds and the non-factory remainder;
- staged, committed and unloaded chunk counts;
- average, p95 and maximum process-frame interval;
- process static memory bytes and process node count;
- rendered object/primitive/draw-call monitors when the display server is not headless;
- display server, OS and processor metadata.

The async transaction duration includes staging, the non-yielding commit and stale-root retirement. Factory construction time is a measured subset. The maximum frame interval exposes the longest observed frame during the transaction, which includes the non-yielding commit/retirement work. Contraction is measured separately with no new roots to stage.

## Run

From the repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

For a rendered desktop/device sample, run the same script without `--headless`:

```sh
godot --path . --script res://tests/surface_chunk_production_benchmark.gd
```

Keep headless and rendered-device records separate. Headless frame intervals are not GPU frame-time evidence. The rendered monitors are reported only when the display server is not headless.

## Interpretation and limits

- The benchmark records measurements; it does not invent pass/fail performance budgets.
- The harness validates real production scene construction and controller registration, but CI hardware is not a substitute for the target iPhone or desktop hardware.
- Static memory is process-wide and resource caches may retain allocations after chunk unload; it is not an isolated per-chunk memory delta.
- The average nodes-per-chunk figure is measured from the actual instantiated chunk trees and may vary between headless and rendered modes.
- No recommended radius is assigned until repeated runs on target hardware establish stable load latency, memory and frame-time budgets.
- The current playable-world default remains radius 1. Radius 8 remains only the supported configuration ceiling.

## Next step

Run the dedicated workflow and retain its JSONL artifact. Repeat the rendered version on target hardware, compare radii 1/2/3/4/8, and only then propose any production radius recommendation or cap/default change.
