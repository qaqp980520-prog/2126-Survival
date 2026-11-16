# Backrooms All-Layer Regression Parse Correction — M0.1.40

## Purpose

Record and correct the first Godot 4.3 parser failure in the M0.1.39 all-eight-underground-layer return-window regression. The failed run must remain visible as a failure; it must not be reclassified as a pass.

## Root cause

The exact-head Full Compatibility Gate #43811473967 (job 133115526759) failed during root-project import. Godot reported:

- `Expected indented block after "if" block`
- File: `tests/production_surface_world_test.gd`
- Line: 457

The two rollback calls guarded by `if deep_layer_index == 2 or deep_layer_index == max_layer_index:` were indented at the same depth as the guard rather than one level beneath it.

## Change

- Re-indented `_test_auxiliary_restore_rollback(layer_now + 3)`.
- Re-indented `_test_underground_base_stream_failure_rollback(layer_now + 4)`.
- No production runtime code, save schema, dependencies, scenes, project settings, or input mappings changed.
- No test assertions or coverage intent changed.

## Files and commit

- `tests/production_surface_world_test.gd`
- Test correction commit: `199eb771c184b224d06c4b1072c0daf3b099279a`
- Parent all-layer implementation: `028f2b6d424681cbd76cec10377bb00e779a9489`
- Branch: `fix/backrooms-underground-surface-window-on-reconciled-runtime-2026-11-16`
- Parent PR: #376.

## Dependencies and import

- Godot 4.3.
- PR #376 reconciled portal runtime.
- PR #377 underground surface-return-window save/restore and rollback.
- Existing UndergroundMineDirector, WorldSessionController, MineralGridStreamingDirector, chunk controller, stamina, quick-use, registries, and BackroomsPortalDirector.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Validation status

- Failed run: [#43811473967](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43811473967), job 133115526759. Root import failed at line 457. This run is explicitly not a pass.
- Corrected commit: `199eb771c184b224d06c4b1072c0daf3b099279a`.
- A fresh exact-head Godot 4.3 Full Compatibility Gate must complete before M0.1.39 can be considered validated.
- No local Godot executable is available in this environment; no local engine pass is claimed.

## Limitations and next steps

- Await the fresh workflow triggered by the correction commit.
- If import succeeds, inspect Production SurfaceWorld step #207 and confirm all eight layers complete.
- Require the complete Full Gate and full-log scan to pass before marking PR #377 Ready for Review.
- After independent review, integrate #377 into PR #376's feature branch and rerun the parent exact-head gate.
- Do not merge to main as part of this correction.
