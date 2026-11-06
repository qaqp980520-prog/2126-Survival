# Mineral Grid Runtime Dimension Contract Regression M0.3.6

## Purpose

Extend the shared runtime configuration guard regression coverage from load-radius bounds to both chunk dimensions. This is a test-only compatibility layer on top of Mineral Grid PR #276.

## Contract under test

- Both chunk dimensions must be finite and strictly positive.
- A zero or negative dimension is invalid even if the Inspector export hint normally constrains editor input.
- Invalid sync and recovery calls must fail before mutating the Director's managed-ID mirror or the controller's committed roots.
- Invalid coordinate queries must fail closed and return the documented zero coordinate.
- Invalid sync or async requests must not cancel an already valid in-flight async request.
- An invalid async request must not allocate a request ID or change the active request.

## Files

- `tests/mineral_grid_streaming_position_validation_test.gd`
- `tests/mineral_grid_streaming_async_test.gd`
- Runtime dependency: `systems/MineralGridStreamingDirector.gd` from parent PR #276.
- Existing focused workflow: `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`.
- Existing full workflow: `.github/workflows/godot-validation.yml`.

## Import and test

From the repository root:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/mineral_grid_streaming_position_validation_test.gd`
- `godot --headless --path . --script res://tests/mineral_grid_streaming_async_test.gd`

The focused workflow already invokes both test scripts, so no workflow duplication is required.

## Dependencies and scope

- Requires Godot 4.3 and the root project.
- Depends on the shared configuration validator introduced by parent PR #276.
- No runtime gameplay code, save schema, chunk IDs, registry data, scenes, external assets or plugins are changed.

## Validation state

- This branch is stacked on `fix/mineral-grid-runtime-radius-cap-2026-11-06` at parent head `e15765ead6c48940a8fb40a5071bf6203a2cf276`.
- New exact-head CI has not yet run at document creation.
- Local Godot is unavailable; no local engine pass is claimed.

## Limitations and next steps

- Headless regression verifies runtime validation and transaction preservation, not device performance or visual rendering.
- Keep the stacked PR Draft until its exact-head focused and full Godot 4.3 workflows pass.
- After review, integrate this test-only layer into PR #276 before that parent PR is merged, then rerun the parent's exact-head matrix.
