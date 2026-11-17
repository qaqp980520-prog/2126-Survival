# M0.1.56 — SurfaceWorld-Owned Backrooms Maze Cell Runtime on Hardened Chain

## Purpose

Port the previously exercised SurfaceWorld-owned maze cell runtime onto the current CI-hardened PR #384 branch. Convert the deterministic, renderer-independent maze plan into real Node3D cell roots while preserving the stage-before-commit invariant.

## Files

- `systems/BackroomsMazeCellRuntime.gd` — owns a hidden/activatable destination, stages detached cell roots, commits the exact logical stream plan, preserves overlapping roots, retires unloaded roots after commit, and supports versioned runtime save/restore.
- `world/SurfaceWorld.gd` — creates and owns one hidden runtime and exposes explicit prepare/activate/deactivate helpers.
- `tests/backrooms_maze_cell_runtime_test.gd` — verifies metadata-only root creation, invalid positions, injected builder failure, old-root identity retention, one-cell load/keep/unload counts, save/restore, version rejection and activation lifecycle.
- `tests/production_surface_world_test.gd` — verifies SurfaceWorld ownership, hidden startup, invalid-level rejection, initial 3×3 preparation, explicit activation and deactivation.
- `.github/workflows/godot-validation.yml` — file guards and a dedicated focused runtime test.
- `docs/BACKROOMS_MAZE_CELL_RUNTIME_M0_1_56.md` — repository-side version record.

## Dependencies and import

- Parent PR #384: bounded deterministic topology, transactional stream-state core and exact crop rollback; exact base HEAD `383ac68d586c46e8a22eb7e97a61232646951568`.
- `systems/BackroomsMazeLayout.gd` and `systems/BackroomsMazeStreamState.gd`.
- Godot 4.3; no third-party packages, new autoloads, Project Settings or input mappings.
- Import: `godot --headless --path . --editor --quit`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_maze_cell_runtime_test.gd`.
- Production integration test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.
- Full validation: exact-head GitHub Actions Godot 4.3 Full Compatibility Gate.

## Runtime contract

- SurfaceWorld owns exactly one hidden/inactive runtime instance from its ready lifecycle.
- `prepare_destination()` builds a detached candidate stream state and the full initial cell-root set before replacing any previously prepared destination.
- `sync_to_world_position()` stages every newly required root first, commits the exact `BackroomsMazeStreamState` key set, attaches the staged roots, and only then retires the unload set.
- Failed staging or logical commit disposes detached candidates and preserves the previously committed roots and stream window.
- Overlapping cells retain their existing Node3D root instances during a successful shift.
- `load_save_dict()` reconstructs a detached candidate state/root set; unsupported versions or staging failures do not replace the live runtime.
- Activation requires a prepared non-empty window. Deactivation disables collision, retires roots and resets the stream state.
- Headless mode creates metadata-only Node3D roots. Graphical mode creates floor/wall BoxMesh geometry and matching StaticBody3D collision shapes.
- The production portal remains locked; these helpers do not switch the player, consume a portal, pause SurfaceWorld streaming or perform a Backrooms transition.

## Validation status

- Source implementation was previously exercised in legacy PR #344, but that branch carried a separate portal-RNG false-green issue. This port is on the corrected PR #384 ancestry and must receive its own exact-head validation.
- New focused and Production SurfaceWorld tests are pending the PR #385 Godot 4.3 Full Gate.
- Local Godot executable is unavailable; no local engine result is claimed.
- Graphical mesh/collision appearance, wall/floor alignment, lighting, GPU cost and iPhone behavior remain unverified until graphical/device QA.

## Known limitations

- The runtime owns a versioned stream payload but is not yet included in `BackroomsLocationSession` / `BackroomsTransitionManager` failure-atomic transactions.
- Lights, ceilings, furniture, level-specific entities, AI, final materials/textures and player handoff are not included.
- Each cell owns its closed-edge wall segment, so adjacent cells create back-to-back wall thickness at shared closed edges. This avoids coplanar z-fighting but duplicates geometry/collision.
- The runtime can be explicitly activated by its API, but the production portal remains locked until transition/session integration is complete.

## Next step

Integrate the runtime payload into `BackroomsLocationSession` and `BackroomsTransitionManager`: stage the destination hidden before portal consumption, commit session/portal state only after runtime preparation succeeds, activate only after player handoff succeeds, and preserve session context if return restoration fails. Then add graphical smoke tests for the generated geometry and collision.
