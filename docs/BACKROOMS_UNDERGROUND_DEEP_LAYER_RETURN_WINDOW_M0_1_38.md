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

## Exact-head validation — code/test head passed

- Code/test HEAD `2985f132435517dc8b07ed6d79e624bea5b46e75` passed Godot 4.3 Full Compatibility Gate [#43808677944](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43808677944), job `133105237773`: workflow conclusion Success; 555/555 total job steps completed successfully; 0 failed and 0 skipped.
- Production SurfaceWorld #207 passed with the new layer-2 save/restore between distinct mine windows, exact depth/player/return-anchor/window assertions, and layer-2 auxiliary plus injected base-stream rollback coverage.
- Also passed Backrooms Portal Director #22; underground mining #213; mine director #214; carry/movement #219; interaction prompt #268; camera-ray interaction #273; mineral reload #292; all-mine-layer lift #302; bounded async streaming #361; controller teardown #366; async diagnostics/stress #372; randomized terrain soaks #433/#443; async dependency binding guard #453; and world-bridge restore read-isolation #547.
- Full job log: 7,726,316 bytes / 84,487 lines; zero runtime `SCRIPT ERROR:`, `ERROR:` or `FAIL:` diagnostics.
- The first M0.1.38 attempt [#43808308762](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43808308762) failed at root import step #7 due a test-source indentation error at line 332; commit `5d27a21d4a16166f2ce4a550c6e7f432b7ceaac1` corrected it. The failed attempt is retained as history and not counted as a pass.
- The above pass validates code/test head `2985f...`. Updating this version record and the M0.1.37 record creates documentation-only commits; the final PR head after those commits still requires a fresh exact-head Full Gate before PR #377 can leave Draft.
- Local Godot executable unavailable; no local engine pass is claimed.

## Limitations and next steps

- Layer 2 is an additional representative nonzero-depth case; layer 0 remains covered by the existing regression. All eight deeper layers are not individually round-tripped here.
- Portal activation remains locked until a real Backrooms destination runtime can be staged and activated atomically.
- GPU visuals, Z-fighting, iPhone, chunk pin/retire stress and target-device performance remain unverified.
- Complete all exact-head workflows and scan the full Godot job log before returning PR #377 to Ready for Review.
- After independent review, merge PR #377 into PR #376's feature branch only, then rerun the updated parent exact-head Full Gate.
