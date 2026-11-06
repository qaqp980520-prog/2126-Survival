# Mineral Grid Runtime Dimension Bounds M0.3.6

## Purpose

Complete the shared runtime configuration contract introduced by parent PR #276. The Director's runtime checks now match both Inspector export ranges: chunk dimensions are inclusive 1–4096 and load radius is inclusive 0–8.

This revision includes a small runtime guard correction, boundary regression coverage and a focused workflow static guard.

## Runtime contract

- `chunk_size_x` and `chunk_size_z` must each be finite and within 1–4096 inclusive.
- `load_radius` must remain within 0–8 inclusive.
- Invalid synchronous requests are rejected before an active async request is cancelled.
- Invalid async requests return `-1` before request-ID allocation or staging.
- Recovery rejects invalid configuration before reconciling controller IDs.
- Invalid coordinate queries fail closed.
- Invalid sync/recovery calls preserve both Director-managed IDs and controller-owned roots.

## Files

- Runtime: `systems/MineralGridStreamingDirector.gd`
- Position and recovery regression: `tests/mineral_grid_streaming_position_validation_test.gd`
- Async transaction regression: `tests/mineral_grid_streaming_async_test.gd`
- Focused static/runtime workflow: `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`
- Full compatibility workflow: `.github/workflows/godot-validation.yml`

## Dependencies

- Parent PR [#276 — Enforce runtime cap for Mineral Grid load radius](https://github.com/qaqp980520-prog/2126-Survival/pull/276), which provides the shared configuration validator and radius contract.
- Godot 4.3 root project, existing `MineralChunkController`, and `SurfaceChunkStreamingPlayground.tscn`.
- No external assets, plugins, save-schema changes, chunk-ID changes, registry changes or scene migrations.

## Import and test

From the repository root:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/mineral_grid_streaming_position_validation_test.gd`
- `godot --headless --path . --script res://tests/mineral_grid_streaming_async_test.gd`

The focused Mineral Grid workflow invokes the position-validation and bounded-async test scripts and statically verifies the dimension/radius constants and shared helper.

## Regression coverage

- NaN and infinite chunk dimensions are rejected.
- Zero, negative and sub-minimum dimensions are rejected.
- Both dimensions accept the inclusive Inspector minimum (1) and maximum (4096).
- Values above 4096 are rejected by sync/recovery and the shared coordinate guard.
- Rejected sync/recovery requests preserve controller and Director ownership maps.
- An invalid dimension does not cancel a valid in-flight async request.
- An invalid async request does not allocate an ID, replace the active request or change committed chunk IDs.
- The valid staged request completes after restoring a supported dimension.

## GitHub and validation state

- Stacked branch: `test/mineral-grid-config-dimension-regressions-2026-11-06`.
- Parent branch: `fix/mineral-grid-runtime-radius-cap-2026-11-06`.
- Parent PR: [#276](https://github.com/qaqp980520-prog/2126-Survival/pull/276).
- Stacked PR: [#277](https://github.com/qaqp980520-prog/2126-Survival/pull/277).
- Exact-head validation is required after the final code, test, workflow and documentation commits. Earlier head results are historical and must not be reused.
- Local Godot executable is unavailable; no local engine pass is claimed.

## Limitations and next steps

- Headless CI verifies runtime configuration and transaction behavior, not device performance or visual rendering.
- Keep PR #277 Draft until all exact-head focused and full Godot 4.3 workflows pass.
- This PR is stacked on #276; integrate it into the parent branch and rerun the parent's full exact-head matrix before #276 merges to main.
