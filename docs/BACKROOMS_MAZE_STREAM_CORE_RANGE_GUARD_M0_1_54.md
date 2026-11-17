# M0.1.54 — Bounded Deterministic Backrooms Maze and Transactional Stream Core

## Purpose

Port the deterministic maze topology and renderer-independent streamed-window state from the legacy maze stack onto the CI-hardened PR #381 chain. Harden coordinate and save-value conversion boundaries before any integer conversion so extreme finite floats cannot overflow a Godot 4.3 headless test or produce a false-green result.

## Runtime contract

- `BackroomsMazeLayout` preserves the original 8 m centered-cell mapping, stable integer hash constants, spanning-tree parent rule and 34% optional seeded passages.
- Every non-origin cell has a deterministic cardinal parent edge that reduces Manhattan distance by one; shared edges are symmetric and deterministic for a fixed world seed.
- Layout cell size is finite, positive and capped at 1,024 m. World coordinates are bounded before `floori()`; cells and neighboring cells outside ±1,000,000 fail closed.
- `BackroomsMazeStreamState` plans load/keep/unload sets and deterministic descriptors without owning Nodes or rendering resources.
- A plan is bound to generation/configuration revisions and a recomputed snapshot. Commit requires the exact set of newly staged keys; duplicate, missing, altered or stale staging leaves the previous committed window unchanged.
- Save schema 1 stores layout algorithm version, level ID, world seed, cell size, stream radius and center cell. Loaded Node references are never serialized.
- Save loading validates all candidate fields before mutating live state. Float inputs are checked against the field's domain bounds before `int()`, preventing oversized finite values from reaching an overflowing conversion.

## Files

- `systems/BackroomsMazeLayout.gd` — deterministic topology, safe cell mapping and bounded edge evaluation.
- `tests/backrooms_maze_layout_test.gd` — centered boundaries, invalid sizes, extreme finite coordinates, out-of-range cells, spanning-tree connectivity, edge symmetry and seed determinism.
- `systems/BackroomsMazeStreamState.gd` — transactional plan/commit and versioned save/restore.
- `tests/backrooms_maze_stream_state_test.gd` — load/keep/unload planning, partial/duplicate stage rejection, stale plans/configuration, save round-trip, version rejection, and extreme positive/negative finite-float rejection with exact state preservation.
- `prototypes/BackroomsPortalPlayground.gd` — delegates existing topology helpers to the shared Layout module while retaining the hardened headless visual fallback from the active runtime branch.
- `.github/workflows/godot-validation.yml` — input guards and two captured-output Godot 4.3 tests with 45-second timeout and 5-second hard-kill grace.
- `docs/BACKROOMS_MAZE_STREAM_CORE_RANGE_GUARD_M0_1_54.md` — this version record.

## Dependencies and import

- Parent PR #381 exact HEAD at branch creation: `200a226bf199f0d511bec41e8e94dae5422caaa5`.
- Source topology/stream-state implementation: legacy PR #343 branch, selectively ported; no legacy portal parser or workflow history was copied.
- Godot 4.3; no third-party packages, autoloads, new scenes, Project Settings or input mappings.
- Import: `godot --headless --path . --editor --quit`.
- Focused tests:
  - `godot --headless --path . --script res://tests/backrooms_maze_layout_test.gd`
  - `godot --headless --path . --script res://tests/backrooms_maze_stream_state_test.gd`
- Full validation: PR-triggered GitHub Actions Godot 4.3 Full Compatibility Gate on the exact branch head.

## Regression rationale

The legacy `BackroomsMazeStreamState._read_integer()` converted a finite integral float to `int()` before checking the caller's much smaller allowed range. A value such as `1e300` could therefore reach an overflowing conversion. The new guard rejects out-of-domain values before conversion and tests schema version, layout version, seed, radius and both center-cell axes while asserting the previously committed window remains unchanged.

The legacy `BackroomsMazeLayout.try_cell_for_position()` checked only finiteness before `floori()`. An extreme finite world coordinate could reach integer cell conversion. The shared layout now applies the same ±1,000,000-cell safety envelope used by stream state before `floori()`; edge queries reject out-of-range source or neighbor cells before hashing.

## Limitations

- This is a pure topology and logical streaming-state layer. It does not yet create SurfaceWorld-owned Node3D cell roots, meshes, materials, lights, collision or entities.
- The production SurfaceWorld does not yet instantiate this maze stream state; the next integration must stage cell roots off-tree, commit only after complete staging, then retire old roots.
- Portal Activation, graphical rendering, GPU, iPhone and target-device performance are not validated by these headless tests.

## Validation status

- Static review confirms the two conversion guards precede `floori()` / `int()`, the original hash constants and topology rules are preserved, and the workflow uses the hardened output/timeout pattern.
- Exact-head Godot 4.3 Full Gate is pending; no engine pass is claimed before GitHub Actions completes and the full job log is scanned.
- Local Godot executable is unavailable in this environment.
