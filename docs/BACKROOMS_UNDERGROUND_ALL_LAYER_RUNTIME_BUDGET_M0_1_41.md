# Backrooms All-Layer Regression Runtime Budget — M0.1.41

## Purpose

Give the all-eight-layer SurfaceWorld return-window regression enough execution time without weakening its assertions or output validation.

## Exact-head evidence

- Corrected test head before this adjustment: `399b6c91e2e9820208d07301fce31a1db1d1f168`.
- Workflow [#43820399009](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43820399009), job `133141952503`, passed root import #7 and Backrooms Portal Director #22.
- Production SurfaceWorld #207 reached layers 1–7 and emitted PASS lines for each completed round-trip and surface restoration. The process ended at the existing 40-second timeout before layer 8 completed.
- Full job log contained no actual Godot `SCRIPT ERROR`, `ERROR:`, or test `FAIL:` diagnostic. This is classified as timeout, not an assertion failure or engine error.

## Change

- File: `.github/workflows/godot-validation.yml`.
- Changed only the Production SurfaceWorld integration command timeout from `40s` to `90s`.
- Preserved captured stdout/stderr, shell failure handling, rejection of `SCRIPT ERROR`, `ERROR:`, and `FAIL:`, and the required success banner.
- No production runtime code, test assertions, save schema, scenes, Project Settings, input mappings, or dependencies changed.

## Commit and branch

- CI adjustment commit: `54a80c5341b105ed595dbdcb420be3ec13f2c023`.
- Updated M0.1.39 history commit: pending in the same branch history after the CI adjustment.
- Branch: `fix/backrooms-underground-surface-window-on-reconciled-runtime-2026-11-16`.
- PR: #377, base PR #376.

## Dependencies and invocation

- Godot 4.3.
- Existing Production SurfaceWorld integration test: `res://tests/production_surface_world_test.gd`.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.
- CI invokes the focused test with a 90-second timeout and strict output checks.

## Validation status

- Previous run #43820399009 is a timeout at step #207 and is not a pass.
- Fresh exact-head Full Compatibility Gate for the updated workflow commit is required.
- No local Godot executable is available; no local engine pass is claimed.

## Limitations and next steps

- Confirm Production SurfaceWorld #207 completes all eight layer round-trips and both layer-2/layer-8 rollback injections.
- Require the full 554-step gate and complete log scan to pass.
- Keep PR #377 Draft until that evidence exists; independent review is required before merging to PR #376's feature branch.
- No main merge.