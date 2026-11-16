# M0.1.35 — Backrooms Loaded Surface Window Integrity

## Purpose

Make the production Backrooms portal spawn window fail closed unless every surface chunk represented by the calculated bounds is actually loaded in the bound chunk controller.

## Finding

PR #337 derived a geometrically correct rectangular window from the player's grid coordinate, chunk dimensions, and load radius. However, the original getter did not inspect the controller's live chunk roots. If a surface chunk were removed or became invalid after a successful streaming sync, the getter could still return a positive rectangle and allow the portal director to accept an area containing a missing chunk.

## Implementation

- Reject bounds while a surface streaming request is pending.
- Resolve the controller from the production streaming director and verify it is alive, inside the SceneTree, and exposes is_chunk_loaded().
- Enumerate every expected surface/chunk_x_z ID in the configured radius.
- Return an empty Rect2 if any expected chunk is absent.
- Keep configure_backrooms_portal_director() fail-closed; an incomplete window cannot mutate the candidate director's spawn policy.

## Regression coverage

The production SurfaceWorld test deliberately unloads one edge chunk from the initial 3×3 surface window and verifies:

1. The bounds getter returns an empty rectangle.
2. Portal configuration is rejected.
3. The previous portal director bounds remain unchanged.
4. The streaming director can restore the missing chunk.
5. The complete original bounds return after restoration.

## Files

- world/SurfaceWorld.gd
- tests/production_surface_world_test.gd
- docs/BACKROOMS_SURFACEWORLD_LOADED_WINDOW_INTEGRITY_M0_1_35.md

## Dependencies and import

- Parent PR #337 exact base HEAD: b1ce10b52ef334fbb16f323f121437f1467eec8c.
- Uses the existing MineralGridStreamingDirector.chunk_controller getter and MineralChunkController.is_chunk_loaded() / unload_chunk() contracts.
- Godot 4.3; no third-party dependencies, new scenes, autoloads, Project Settings, save schema, or input mapping.
- Import: godot --headless --path . --import.
- Focused test: godot --headless --path . --script res://tests/production_surface_world_test.gd.

## Validation

- Code changes are pushed to a child branch of PR #337.
- Exact-head Godot 4.3 CI is required; no engine pass is claimed until the new focused regression and full compatibility gate complete.
- Local Godot executable is unavailable, so no local engine run is claimed.

## Limitations and next step

- This validates the integrity of the loaded rectangular surface window, not final portal visuals, chunk pin/retire lifecycle, live portal ticking, transition activation, GPU rendering, or iPhone behavior.
- After this child PR passes, merge it into PR #337's feature branch only, rerun PR #337 on the resulting exact head, and continue parent-first integration. Never merge directly to main.
