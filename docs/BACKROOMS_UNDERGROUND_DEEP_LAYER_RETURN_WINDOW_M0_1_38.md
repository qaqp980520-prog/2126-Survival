# M0.1.38 — Deep-Layer Surface Return Window Round-Trip

## Purpose

Extend PR #377's underground return-anchor regression beyond mine layer 0. The production SurfaceWorld save/restore path must preserve a nonzero mine layer while keeping the independent surface stream anchored at the saved return position.

## Implementation

- Extend `tests/production_surface_world_test.gd` with a layer-2 round-trip using the real `UndergroundMineDirector`.
- Move the mine stream to a distant layer-2 window, serialize the active SurfaceWorld/Backrooms state, move to a different layer-2 window, then restore.
- Assert the exact mine position, layer index, mine director layer, surface return anchor and surface loaded-window bounds.
- Re-run auxiliary restore rollback and one-shot surface chunk-factory failure rollback while the baseline is on layer 2.
- Make the base-stream rollback assertion compare the restored mine depth with the captured baseline instead of hard-coding layer 0.
- Restore the captured surface snapshot after the deep-layer test so subsequent portal lifecycle tests retain their original baseline.

## Files

- `tests/production_surface_world_test.gd` — nonzero-layer save/restore and rollback coverage.
- `docs/BACKROOMS_UNDERGROUND_DEEP_LAYER_RETURN_WINDOW_M0_1_38.md` — this version record.

## Dependencies and import

- Godot 4.3.
- PR #376 — reconciled SurfaceWorld portal runtime.
- PR #377 — surface return-window save/restore and failure-atomic rollback.
- Existing `UndergroundMineDirector`, `WorldSessionController`, `MineralGridStreamingDirector`, chunk controller, stamina, quick-use and Backrooms portal director.
- No production runtime code, save schema, scene, autoload, input mapping or Project Settings changes.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Validation status and first-run correction

- Initial M0.1.38 exact-head Full Gate [#43808308762](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43808308762) failed at root-project import, step #7. Godot reported `res://tests/production_surface_world_test.gd:332`: `Parse Error: Expected statement, found "Indent" instead.`
- Cause: the new deep-layer helper invocation had one fewer tab than the surrounding nested test block. This was a test-source indentation error; the new runtime logic was not reached.
- Corrected by commit `5d27a21d4a16166f2ce4a550c6e7f432b7ceaac1` (`fix(test): correct deep-layer regression call indentation`).
- The failed run is not accepted as a pass. A fresh exact-head Godot 4.3 focused/full gate is required for the final branch head after the documentation closeout commits.
- Previous head `27c1a61daa44139ddcf8a82212752ea4290fd9fd` passed 554/554 validation steps, but that run predates M0.1.38 and does not validate this version.
- Local Godot executable is unavailable; no local engine pass is claimed.

## Limitations and next steps

- Layer 2 is an additional representative nonzero-depth case; layer 0 remains covered by the existing regression. All eight deeper layers are not individually round-tripped here.
- Portal activation remains locked until a real Backrooms destination runtime can be staged and activated atomically.
- GPU visuals, Z-fighting, iPhone, chunk pin/retire stress and target-device performance remain unverified.
- Complete all exact-head workflows and scan the full Godot job log before returning PR #377 to Ready for Review.
- After independent review, merge PR #377 into PR #376's feature branch only, then rerun the updated parent exact-head Full Gate.
