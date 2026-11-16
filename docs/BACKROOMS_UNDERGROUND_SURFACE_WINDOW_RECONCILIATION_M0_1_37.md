# M0.1.37 — Underground Surface Return Window on Reconciled Portal Runtime

## Purpose

Port the underground SurfaceWorld save/restore anchor and failure-atomic rollback fix from PR #340 onto the validated-parent portal runtime reconciliation in PR #376, while preserving the stronger loaded-window contract introduced by PR #375.

## Source and target

- Parent PR #376 exact source HEAD: 7415a72ebbf10b5814c11fbfcd65ee926729a927.
- Parent PR #376 branch: integration/backrooms-portal-runtime-on-validated-parent-2026-11-16.
- Source PR #340 HEAD: 7ecf410a42b66c17203b34ba454e2c365a4627ab.
- New child branch: fix/backrooms-underground-surface-window-on-reconciled-runtime-2026-11-16.
- Target parent: PR #376 only; no main changes.

## Implementation

- Add get_loaded_surface_window_bounds_at(reference_position) and select _surface_return_position while underground.
- Preserve the parent loaded-window safeguards: pending-stream rejection, live controller binding/lifecycle checks, finite and ±1,000,000,000 safe grid validation, load radius 0–8, valid chunk dimensions, and per-chunk existence checks.
- Serialize the portal envelope against the actual loaded surface window at the saved return anchor rather than the underground player's unrelated X/Z position.
- For underground restore, stream the SurfaceWorld around the saved return anchor first, then restore the player to the saved mine position.
- For rollback from an underground state, rebuild the previous surface stream around the previous return anchor, restore the exact mine position/velocity, and refresh the portal visual after rollback.
- Preserve the detached portal director candidate and failure-atomic transaction ordering.

## Additional regression discovered during port

The original PR #340 helper did not retain PR #375's pending-stream guard and also lacked the parent's upper load-radius bound and safe-grid check. This port deliberately keeps all of those stronger parent checks and adds a direct regression proving that reference-position bounds remain empty during pending asynchronous streaming, including while underground.

## Files

- world/SurfaceWorld.gd
- tests/production_surface_world_test.gd
- docs/BACKROOMS_UNDERGROUND_SURFACE_WINDOW_RECONCILIATION_M0_1_37.md

## Dependencies and import

- Godot 4.3.
- Parent PR #376 supplies SurfaceWorld-owned portal runtime, persistence envelope, active portal visual lifecycle and owner-first retirement.
- Parent PR #337/#375 supplies canonical loaded-window integrity and safe-coordinate validation.
- Existing WorldSessionController, MineralGridStreamingDirector, UndergroundMineDirector, chunk controller, stamina, quick-use, mineral/object registries and BackroomsPortalDirector.
- No third-party packages, new autoloads, new scenes, input mappings, Project Settings or save-schema changes.
- Import: godot --headless --path . --import.
- Focused regression: godot --headless --path . --script res://tests/production_surface_world_test.gd.
- Portal director regression: godot --headless --path . --script res://tests/backrooms_portal_director_test.gd.

## Regression coverage

- Underground player moves horizontally beyond the loaded surface return window.
- Save remains valid using the exact surface return anchor.
- Restore starts from a different mine window, rebuilds the surface window at the saved return anchor, then returns the player to the saved mine coordinates.
- Active portal visual remains attached when its owner surface chunk remains loaded.
- Stamina and Quick Use apply failures restore both streaming windows and the exact portal RNG envelope.
- Mine-origin chunk assertion is baseline-aware: rollback preserves whether the origin chunk was loaded in the captured mine window, rather than incorrectly requiring it to be loaded for every underground position.
- A one-shot SurfaceWorld chunk-factory failure during underground restore is injected; rollback must restore the exact mine window, surface window, return position, player position/velocity, world seed, registries and portal state.
- Reference-position loaded-window bounds fail closed while asynchronous streaming is pending, including while underground.
- The canonical parent safe-grid, radius and per-chunk checks remain intact.

## Validation status

- Static patch port and exact source comparison completed.
- Exact-head Godot 4.3 focused tests and Full Compatibility Gate are pending on this branch.
- Parent PR #376 Full Gate is still running; this child is not considered validated until its own exact-head run completes.
- Local Godot executable unavailable; no local engine pass is claimed.

## Limitations and next steps

- Portal activation remains locked until a real Backrooms destination runtime can be staged and activated atomically.
- GPU final visuals, Z-fighting, iPhone, chunk pin/retire stress and target-device performance remain unverified.
- After this child passes exact-head validation, reconcile/close PR #340 as superseded, then rerun PR #376 on the resulting exact head.
- Keep main unchanged until independent review and parent-first integration are complete.
