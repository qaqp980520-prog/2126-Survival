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

## Validation status

- Code committed to PR #377 feature branch at the new test commit; full Godot 4.3 exact-head validation has been triggered by the updated PR head and is pending.
- No Godot test pass is claimed for M0.1.39 until the new exact-head Production SurfaceWorld regression and the complete Full Compatibility Gate pass.
- Local Godot executable is unavailable; engine validation must run in GitHub Actions.

## Limitations and next steps

- Portal activation remains locked until a real Backrooms destination runtime can be staged and activated atomically.
- GPU visuals, Z-fighting, iPhone, chunk pin/retire stress and target-device performance remain unverified.
- Wait for the current exact-head CI; inspect the Production SurfaceWorld step, all final steps and the complete job log for actual runtime Godot diagnostics.
- Only after successful exact-head validation should PR #377 be marked Ready for Review again. Independent review is still required before merging it into PR #376's feature branch; rerun the updated #376 Full Gate after that merge.
