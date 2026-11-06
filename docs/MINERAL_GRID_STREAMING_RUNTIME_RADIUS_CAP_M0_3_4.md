# Mineral Grid Runtime Load-Radius Cap M0.3.4 — 2026-11-06

## Problem

The Director exposes `load_radius` with an Inspector range of 0–8, but Inspector metadata does not constrain values assigned by scripts at runtime. Both synchronous and asynchronous entry points previously rejected negative radii but accepted arbitrarily large positive values. A bad runtime assignment could expand the square request to `(2r+1)^2` chunks, causing excessive factory calls, memory pressure and frame stalls.

## Change

- Introduce `MAX_LOAD_RADIUS = 8` as the runtime contract matching the existing Inspector range.
- Enforce the inclusive 0–8 bound in synchronous sync validation, asynchronous request validation, and the shared safe-grid-position guard.
- Preserve the existing validation report phase for synchronous rejection.
- Reject invalid async requests before allocating a request ID or staging any chunk roots.
- No change to chunk IDs, world-save data, mineral registry, mining rules, or valid radius behavior.

## Regression coverage

- `tests/mineral_grid_streaming_position_validation_test.gd`: verifies radius 8 remains valid, radius 9 is rejected by synchronous sync and coordinate validation, and rejection leaves controller IDs and Director ownership unchanged.
- `tests/mineral_grid_streaming_async_test.gd`: verifies radius 9 is rejected before an async request ID is consumed, no request becomes active, and the existing chunk window is unchanged.

## Files and dependencies

- `systems/MineralGridStreamingDirector.gd`
- `tests/mineral_grid_streaming_position_validation_test.gd`
- `tests/mineral_grid_streaming_async_test.gd`
- Godot 4.3 root project and existing fake/production chunk-controller interfaces.
- No external assets, plugins, or save-schema migration.

## Import and validation

From repository root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/mineral_grid_streaming_position_validation_test.gd
godot --headless --path . --script res://tests/mineral_grid_streaming_async_test.gd
```

Exact-head GitHub Actions validation is required before merge. Local Godot execution is not available in the current environment.

## Limits and next steps

The cap bounds one Director window to at most 289 coordinates. It does not impose a global memory budget across multiple Director instances. Continue monitoring active Director count and chunk-factory cost separately.
