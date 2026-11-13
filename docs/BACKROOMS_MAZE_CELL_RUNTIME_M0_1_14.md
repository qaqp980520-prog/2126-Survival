# M0.1.14 — SurfaceWorld-Owned Backrooms Maze Cell Runtime

## Purpose

Turn the validated topology and transactional stream-window state from M0.1.12–M0.1.13 into a SurfaceWorld-owned Node3D runtime. The runtime stages new cell roots before committing the logical window, preserves overlapping roots, retires cells only after commit, and can reconstruct a saved window without serializing Node references.

This is the first scene-owning maze runtime layer. It is not yet a playable world transition: the SurfaceWorld keeps the destination hidden/inactive and the production portal remains locked.

## Files

- `systems/BackroomsMazeCellRuntime.gd` — owns cell roots, metadata-only headless construction, graphical floor/wall meshes and world collision, transactional window shifting, activation/deactivation and atomic stream save/restore.
- `world/SurfaceWorld.gd` — creates and owns one hidden BackroomsMazeCellRuntime; exposes prepare/activate/deactivate methods for the future transition coordinator.
- `tests/backrooms_maze_cell_runtime_test.gd` — focused headless staging failure, overlapping-root retention, unload, deterministic restore, version rejection and activation tests.
- `tests/production_surface_world_test.gd` — verifies SurfaceWorld ownership and keeps portal activation locked until the complete transition integration exists.
- `.github/workflows/godot-validation.yml` — file guards and focused runtime test step.
- `docs/BACKROOMS_MAZE_CELL_RUNTIME_M0_1_14.md` — repository-side version record.

## Dependencies and import

- Parent PR #343: transactional maze stream state, itself based on PR #342 deterministic maze topology.
- `systems/BackroomsMazeLayout.gd` and `systems/BackroomsMazeStreamState.gd`.
- Godot 4.3; no third-party packages, new autoloads, Project Settings or input mappings.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_maze_cell_runtime_test.gd`.
- Full gate: exact-head GitHub Actions Godot Full Compatibility Gate.

## Runtime contract

- SurfaceWorld owns exactly one hidden/inactive runtime instance from its ready lifecycle.
- `prepare_destination()` builds a candidate stream state and all initial cell roots before replacing any existing prepared runtime.
- `sync_to_world_position()` stages every newly required cell root first, commits the exact logical key set, then attaches new roots and retires the unload set.
- A staging or commit rejection disposes detached candidate roots and leaves the previous committed roots and stream-state window unchanged.
- Overlapping cells retain their existing Node3D root instances during a successful shift.
- `load_save_dict()` reconstructs into a detached candidate state and root set; invalid versions or failed staging do not replace the live runtime.
- `activate_destination()` only enables visibility/collision after a prepared non-empty window exists; `deactivate_destination()` disables collision, retires roots and resets the runtime.
- Headless mode creates metadata-only Node3D roots with no MeshInstance3D or PhysicsBody3D. Graphical mode creates floor/wall BoxMesh geometry and matching StaticBody3D collision shapes.
- Cell metadata includes stable cell key/coordinate, level, world seed, layout algorithm version and deterministic open-edge flags.

## Validation

- The focused test injects a cell-builder failure and verifies the previous window and existing origin root instance remain unchanged.
- It verifies a one-cell shift loads 3, keeps 6 and unloads 3; overlapping roots retain identity.
- It verifies save/restore recreates the exact key set and edge descriptors, rejects an unsupported layout algorithm version atomically, and requires explicit activation.
- Local Godot executable is unavailable in this environment; no local engine run is claimed until exact-head GitHub Actions completes.
- Graphical geometry and collision are authored but are not validated by the headless metadata-only test. GPU rendering, wall/floor visual alignment, Z-fighting, lighting and iPhone performance remain untested.

## Scope boundary

- This PR does not switch the player between worlds, pause SurfaceWorld streaming, move the player into the maze, enable portal activation, or complete the Backrooms return transaction.
- The portal remains locked. The runtime is only a prepared/activatable destination owner.
- Cell roots currently contain floor and closed-wall geometry/collision only; lights, ceilings, furniture, level-specific entities, AI and visual materials/textures remain future work.
- Each cell currently owns its own closed edge wall segment; adjacent cells therefore create back-to-back wall thickness at shared closed edges. This is deterministic and avoids renderer z-fighting, but a later shared-edge owner can reduce duplicate collision/geometry if profiling warrants it.
- The runtime currently owns its own versioned stream payload; the next integration must include this payload in BackroomsLocationSession's failure-atomic transaction.

## Next step

Integrate the runtime's versioned stream payload with BackroomsLocationSession and BackroomsTransitionManager. Stage the destination hidden before portal consumption, commit the portal/session only after runtime preparation succeeds, activate only after the SurfaceWorld/player handoff succeeds, and retain the session context if return restoration fails. Then add graphical smoke tests for floor/wall geometry and a true playable transition.
