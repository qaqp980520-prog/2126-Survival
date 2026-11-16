# M0.1.39 — All Eight Underground Layers Return-Window Round-Trip

## Purpose

Close the M0.1.38 coverage limitation by validating the SurfaceWorld return-window save/restore path at every supported nonzero underground layer (1 through 8), not only a representative layer.

## Implementation

- Extend `_test_underground_deep_layer_round_trip()` into a data-driven loop over all supported deep layers 1–8.
- Assert the deepest supported layer has a finite floor and layer 9 is rejected by `UndergroundMineDirector.get_layer_floor_y()`.
- For each layer, load a mine window at one world position, serialize the SurfaceWorld/Backrooms envelope, move to a different mine window on the same layer, restore, and assert exact player position, mine depth, director layer, saved surface return anchor and surface loaded-window bounds.
- Restore the captured surface snapshot after each layer so every iteration begins from the same baseline.
- Run the auxiliary stamina/quick-use rollback and injected surface chunk-factory failure rollback at layer 2 and the deepest supported layer 8.
- Require all eight deep layers to complete the full round-trip; a failed layer cannot be hidden by a later successful iteration.

## Files

- `tests/production_surface_world_test.gd` — all-layer round-trip and deepest-layer rollback regression.
- `docs/BACKROOMS_UNDERGROUND_ALL_LAYER_RETURN_WINDOW_M0_1_39.md` — this version record.

## Dependencies and import

- Godot 4.3.
- PR #376 — reconciled SurfaceWorld portal runtime and loaded-window integrity.
- PR #377 — surface return-window save/restore and failure-atomic rollback.
- Existing `UndergroundMineDirector`, `WorldSessionController`, `MineralGridStreamingDirector`, chunk controller, stamina, quick-use, registries and BackroomsPortalDirector.
- No third-party packages, scenes, autoloads, input mappings, Project Settings or save-schema changes.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Initial exact-head CI failure and correction — 2026-11-16

- First M0.1.39 exact-head run [#43811473967](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43811473967), job `133115526759`, failed at root project import before any focused regression executed.
- Godot 4.3 reported `Expected indented block after "if" block` at `tests/production_surface_world_test.gd:457`. The two rollback helper calls under the layer-2/layer-8 guard were aligned with the `if` instead of nested beneath it.
- Corrected both call indents in commit `199eb771c184b224d06c4b1072c0daf3b099279a`. This is a syntax correction only; test intent and production code are unchanged.
- The failed run is not a pass. A new exact-head workflow is required for the corrected commit.

## First all-layer runtime-budget failure and CI adjustment — 2026-11-16

- Corrected parser head `399b6c91e2e9820208d07301fce31a1db1d1f168` imported successfully; Portal Director #22 passed.
- Full Gate [#43820399009](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43820399009), job `133141952503`, reached Production SurfaceWorld step #207. The test output showed successful round-trips through layers 1–7, including layer-2 and layer-8 rollback checks only when reached; the process was terminated at the step's existing 40-second timeout before layer 8 completed.
- The log contains no Godot `SCRIPT ERROR`, `ERROR:`, or `FAIL:` diagnostics. The failure is a test time-budget exhaustion, not a parser or asserted state failure.
- Increased only the Production SurfaceWorld integration step timeout from 40 seconds to 90 seconds in `.github/workflows/godot-validation.yml`, commit `54a80c5341b105ed595dbdcb420be3ec13f2c023`. The command's captured-output error guards and success-banner requirement are unchanged.
- A fresh exact-head workflow is required; the timed-out run is not a pass.

## Validation status

- Code committed to PR #377 feature branch at the new test commit; full Godot 4.3 exact-head validation has been triggered by the updated PR head and is pending.
- No Godot test pass is claimed for M0.1.39 until the new exact-head Production SurfaceWorld regression and the complete Full Compatibility Gate pass.
- Local Godot executable is unavailable; engine validation must run in GitHub Actions.

## Limitations and next steps

- Portal activation remains locked until a real Backrooms destination runtime can be staged and activated atomically.
- GPU visuals, Z-fighting, iPhone, chunk pin/retire stress and target-device performance remain unverified.
- Wait for the current exact-head CI; inspect the Production SurfaceWorld step, all final steps and the complete job log for actual runtime Godot diagnostics.
- Only after successful exact-head validation should PR #377 be marked Ready for Review again. Independent review is still required before merging it into PR #376's feature branch; rerun the updated #376 Full Gate after that merge.
