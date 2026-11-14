# Backrooms Production Maze Cell Entity Spawn Roots — M0.1.16

## Purpose

Connect the existing Level 0–5 BackroomsEntityDirector roster to the SurfaceWorld-owned BackroomsMazeCellRuntime. Every newly staged production maze cell now derives a deterministic set of renderer-independent entity roots from its level, cell coordinate, and maze edge descriptor.

This is the first production runtime spawn integration. It is deliberately separate from the Backrooms playground visual factories and does not claim that AI, collision bodies, or rendered entity meshes are attached yet.

## Runtime implementation

- `systems/BackroomsEntityDirector.gd`
  - Adds spawn descriptor algorithm version 1.
  - Adds `get_cell_spawn_descriptors()`, returning entity ID, owning cell, deterministic local position, optional owned wall direction, and algorithm version.
  - Preserves the existing level whitelist and per-cell spawn probabilities.
  - Keeps Window placement on a closed north or west boundary owned by the current cell; a Window candidate without an eligible owned wall is omitted rather than placed in open space.
  - Reuses the existing deterministic position salts from the Backrooms prototype for Smiler, Hound, Skin-Stealer, Clump, Faceling, Duller and Deathmoth.
- `systems/BackroomsMazeCellRuntime.gd`
  - Preloads BackroomsEntityDirector and builds entity Node3D roots while each cell is still detached.
  - Validates entity IDs against the level whitelist, descriptor cell, finite local position, in-cell bounds, duplicate IDs, and Window wall ownership before attaching roots.
  - Stores entity ID, spawn cell, world seed, level, algorithm version and wall direction as metadata.
  - Stores the filtered spawn ID list and spawn algorithm version on the cell root.
  - Entity roots are children of their owning cell, so staging failure, stream unload, destination replacement and save reconstruction follow the existing cell-root lifecycle.
  - Does not create MeshInstance3D, CollisionObject3D, AI or per-entity save records in this milestone.
- `tests/backrooms_maze_cell_runtime_test.gd`
  - Covers Level 0's empty roster.
  - Finds deterministic candidates for every configured entity in Levels 1–5 and verifies production runtime roots, level whitelist, owning cell, seed metadata, algorithm version, in-cell placement and Window wall ownership.
  - Compares actual roots with the Director's filtered descriptors.
  - Verifies deterministic placement across repeated staging and the existing maze save/restore reconstruction path.

## Files

- `systems/BackroomsEntityDirector.gd`
- `systems/BackroomsMazeCellRuntime.gd`
- `tests/backrooms_maze_cell_runtime_test.gd`
- `docs/BACKROOMS_MAZE_CELL_ENTITY_SPAWNING_M0_1_16.md`

## Dependencies and import

- Parent PR #345 — runtime/session transaction.
- PR #344 — SurfaceWorld-owned maze cell runtime.
- PR #342/#343 — deterministic maze layout and transactional stream state.
- Existing BackroomsEntityDirector level rosters from PR #322.
- Godot 4.3; no third-party packages, new autoloads, Project Settings, or save-schema changes.

Import:

    godot --headless --path . --import

Focused test:

    godot --headless --path . --script res://tests/backrooms_maze_cell_runtime_test.gd

The existing `.github/workflows/godot-validation.yml` already runs the Backrooms maze cell runtime test; no new workflow step is required.

## Lifecycle and save behavior

- Spawn roots are staged inside detached cell roots before the logical stream window commits.
- Existing cell roots retain their entity child instances during overlapping-window movement.
- Unloaded cell roots retire their entity children with the parent cell.
- Save restore rebuilds spawn roots deterministically from the existing level, world seed, cell coordinates and layout descriptors; entity instances are not serialized separately.
- No changes are made to the existing Backrooms maze save envelope or schema in this version.

## Validation status and limitations

- Parent PR #345 exact HEAD `c607c7d5cb3ee03ae366494678de0f9aa55aaf26` passed Godot 4.3 Full Compatibility Gate [Run #43358973711](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43358973711): 559/559 workflow steps, 0 failures, 0 skipped.
- This new child HEAD requires its own exact-head focused tests and full compatibility gate; no pass is claimed until those runs complete.
- Local Godot 4.3 is unavailable in this execution environment; engine validation is performed by GitHub Actions.
- The new production roots are metadata-only placeholders with no rendered geometry, collision, navigation, AI, animation, perception or combat. The Duller/Deathmoth visual geometry contract on PR #326 remains in the separate prototype stack and is not yet reused by this production runtime.
- The spawn algorithm version is recorded on each cell/entity root but is not yet a field in the persisted maze stream schema. Do not change spawn selection/placement semantics without adding an explicit save migration/version contract.
- Graphical inspection, collision behavior, AI, GPU performance and iPhone behavior remain unverified.

## Next steps

1. Run the existing Backrooms maze runtime focused test and the exact-head Godot 4.3 Full Compatibility Gate for this PR.
2. Inspect the resulting spawn metadata on the actual SurfaceWorld-owned runtime.
3. Extract a reusable visual factory from the prototype and attach validated visuals to these production roots without adding a second player or session.
4. Add per-entity lifecycle/AI only after visual and collision ownership are independently tested.
