# M0.1.13 — Transactional Backrooms Maze Stream State

## Purpose

Add a renderer-independent streaming-state contract on top of the deterministic maze topology extracted in M0.1.12. The state model plans a centered cell window, distinguishes cells to load/keep/unload, and commits a window only after the caller confirms that every newly required cell was staged successfully.

This is a logical streaming transaction layer. It deliberately does not own scene nodes or render geometry.

## Runtime contract

- \`systems/BackroomsMazeLayout.gd\` exposes \`ALGORITHM_VERSION = 1\`; persisted stream state is bound to this exact topology algorithm.
- \`BackroomsMazeStreamState.configure()\` accepts only Level 0–5, world seeds in the supported non-negative range, finite positive cell sizes up to 1,024 m, and stream radii from 0 through 8.
- \`plan_window_for_position()\` uses the shared centered-cell mapping; \`plan_window_at_cell()\` is available to restore an already-saved center without round-tripping through floating-point world coordinates.
- Plans contain deterministic cell descriptors: canonical cell key, integer cell coordinate, world origin, level, seed, algorithm version, parent direction and four shared-edge openness flags.
- Each plan separates \`load_cell_keys\`, \`keep_cell_keys\` and \`unload_cell_keys\`. Keys and descriptors are emitted in deterministic order.
- \`commit_window()\` rejects stale generations/configurations, altered plan snapshots, duplicate staged keys and incomplete staged key sets. Rejection leaves the previously committed loaded-cell set unchanged.
- The caller must stage every new cell root off-tree first. Only after \`commit_window()\` succeeds may it retire roots listed in \`unload_cell_keys\`. If staging fails, it discards staged roots and keeps the old window.
- Cell-window bounds are constrained so the complete requested window stays within ±1,000,000 cells; stream radius is capped at 8 and cell size at 1,024 m.

## Persistence contract

- Save schema version: 1.
- Save payload includes \`layout_algorithm_version\`, level ID, world seed, cell size, stream radius and center cell.
- Scene-node references and loaded-cell objects are never serialized.
- Loading validates the complete payload into local candidates before changing live state.
- Unsupported layout versions fail closed with \`unsupported_layout_algorithm_version\`; malformed or out-of-range center windows are rejected without replacing the current state.
- After loading, the caller plans and stages the saved center window again. The regenerated descriptors must match because the seed and algorithm version are explicit.

## Files

- \`systems/BackroomsMazeLayout.gd\` — adds the explicit deterministic topology algorithm version.
- \`systems/BackroomsMazeStreamState.gd\` — pure plan/commit/save/restore state contract.
- \`tests/backrooms_maze_stream_state_test.gd\` — load-first shifting, incomplete/duplicate staging rejection, unload/reload determinism, stale-plan/config rejection, bounds and versioned save/restore.
- \`.github/workflows/godot-validation.yml\` — file guards and a focused Godot 4.3 headless test in the Full Compatibility Gate.
- \`docs/BACKROOMS_MAZE_STREAM_STATE_M0_1_13.md\` — this version record.

## Dependencies and import

- Parent PR #342: deterministic \`BackroomsMazeLayout\` topology core.
- Godot 4.3; no third-party packages, autoloads, scenes, Project Settings or input mappings.
- Import from repository root: \`godot --headless --path . --import\`.
- Focused test: \`godot --headless --path . --script res://tests/backrooms_maze_stream_state_test.gd\`.
- Full validation: exact-head GitHub Actions \`Godot Full Compatibility Gate\`.

## Validation status

- Static diff reviewed for deterministic plan ordering, stale-plan rejection, exact staged-key matching, bounds, atomic save loading and version checks.
- Local Godot executable is unavailable in the current environment; no local engine execution is claimed.
- Exact-head GitHub Actions validation is required before this PR can be marked Ready for Review.

## Limitations

- This state contract does not create or free \`Node3D\` cell roots, meshes, materials, collision bodies, lights or entities.
- It is not yet instantiated by \`SurfaceWorld\`; the production scene still needs a runtime owner and a visual cell builder.
- The caller is responsible for staging and cleaning up scene roots around the state transaction. The state model verifies the exact logical key set, not renderer resource allocation.
- This PR does not change \`BackroomsLocationSession\` save schema; the later production integration must include this stream payload in the existing failure-atomic transition/session transaction.

## Next step

Build the SurfaceWorld-owned cell-root runtime that consumes these plans. Stage new roots and their geometry/collision before calling \`commit_window()\`, retain old roots until the commit succeeds, then retire the unload set. Add a headless metadata-only builder path and integrate the stream payload with the Backrooms location-session save/restore transaction.
