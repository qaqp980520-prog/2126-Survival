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


## Run 143 — invalid synchronous requests do not cancel valid async work

- The synchronous entry point previously cancelled an active async request before validating the new position, dimensions and runtime load radius. An invalid sync call could therefore discard a valid in-flight request even though the new request was rejected.
- Move async supersession until after all synchronous validation succeeds. A valid sync request still cancels the active async request before it mutates the chunk window.
- Extend `tests/mineral_grid_streaming_async_test.gd`: stage a valid async request, set the runtime radius above the cap, issue an invalid sync request, verify the active request ID and committed chunk IDs remain unchanged, submit a second invalid async request and verify it neither cancels the active request nor consumes an ID, restore the valid radius, and verify the original async request completes.
- Exact-head CI for the updated branch must be rerun; no pass is claimed until the new head finishes.


## Run 144 — invalid async request preserves an active valid request

- Extend the active-request regression so both invalid synchronous and invalid asynchronous requests are submitted while a valid async chunk window is already staging.
- Verify the invalid async request returns `-1`, leaves the active request ID unchanged, does not consume `_next_async_request_id`, and does not alter committed chunk IDs.
- This validates the existing async validation-before-supersession order alongside Run 143's synchronous guard.
- Exact-head CI must be rerun for the new commit; no pass is claimed until completion.


## Run 145 — validation report message regression

- Correct the synchronous invalid-configuration report to include the supported runtime radius range instead of an accidentally malformed placeholder.
- Extend the position-validation test to assert the report message explains the inclusive 0–8 range, in addition to checking the validation phase and state preservation.
- Exact-head CI must be rerun for the new commit.
