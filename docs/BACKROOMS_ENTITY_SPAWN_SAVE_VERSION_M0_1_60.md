# Backrooms Level-Scoped Entity Spawn Roots and Save Version M0.1.60

## Purpose

Connect the existing level-specific Backrooms entity roster to the SurfaceWorld-owned maze-cell Runtime. Each newly staged maze cell now receives deterministic, renderer-independent entity identity roots. The maze stream save schema records the entity-spawn algorithm version so restored cells cannot silently change spawn identity after a future algorithm update.

This is a selective port of the production entity-root work from historical PRs #363/#364 onto the current combined-world-save PR #388 exact HEAD. No historical branch is merged.

## Level roster and deterministic selection

- Level 0: no entity roots.
- Level 1: Window, Smiler.
- Level 2: Hound, Skin-Stealer.
- Level 3: Clump, Faceling.
- Level 4: Duller.
- Level 5: Deathmoth.

Current spawn chances are deterministic per cell and entity type: Window 18%, Smiler 7%, Hound 8%, Skin-Stealer 5%, Clump 6%, Faceling 8%, Duller 6%, Deathmoth 4%.

The spawn descriptor includes entity ID, owning cell, local position, wall direction and algorithm version. Window is only emitted on a closed north or west wall owned by the current cell; this avoids placing it on a passage or duplicating ownership on the east/south neighbor boundary.

## Runtime behavior

- BackroomsEntityDirector builds deterministic renderer-independent descriptors.
- BackroomsMazeCellRuntime validates whitelist membership, descriptor cell identity, finite/in-cell position, uniqueness, wall direction and algorithm version before attaching a Node3D identity root to the detached cell root.
- Entity roots record entity ID, owning cell, world seed, level ID, algorithm version, wall direction and visual attachment state.
- Entity roots are staged before stream commit and are retired with their owning cell.
- Save/restore rebuilds the same identity roots from the existing maze stream state.
- This version intentionally creates metadata-only identity roots. Rendered meshes, collision, navigation, AI, animation, perception and combat are not included.

## Maze stream save schema

- Advance BackroomsMazeStreamState schema from 1 to 2.
- Schema 2 writes entity_spawn_algorithm_version = 1.
- Schema 1 remains readable and maps explicitly to legacy spawn algorithm version 1; the next save writes schema 2.
- Schema 2 with a missing or unsupported spawn algorithm version fails closed before mutating live stream state.
- The current safe numeric parser's bounds check before float-to-int conversion is preserved. This is important: the historical PR #364 source omitted that guard; this port deliberately retains the hardened parser and the extreme-float regression tests.
- BackroomsLocationSession canonicalizes a legacy nested schema-1 maze stream through MazeStreamState and stores the schema-2 representation.

## Files

- systems/BackroomsEntityDirector.gd
- systems/BackroomsMazeCellRuntime.gd
- systems/BackroomsMazeStreamState.gd
- tests/backrooms_maze_cell_runtime_test.gd
- tests/backrooms_maze_stream_state_test.gd
- tests/backrooms_runtime_session_integration_test.gd
- tests/backrooms_combined_world_save_test.gd
- docs/BACKROOMS_ENTITY_SPAWN_SAVE_VERSION_M0_1_60.md

The existing .github/workflows/godot-validation.yml steps #23, #24, #29 and #213 execute the updated tests; no new workflow step is required.

## Dependencies

- Parent PR #388: combined SurfaceWorld + Backrooms world-save envelope.
- PR #387: production player handoff.
- PR #386: Backrooms Runtime / Session transaction.
- PR #385: SurfaceWorld-owned maze-cell Runtime.
- Existing BackroomsMazeLayout, BackroomsMazeStreamState, BackroomsLocationSession, BackroomsTransitionManager, BackroomsPortalDirector and SurfaceWorld contracts.

## Import / integration

No manual import is required. The scripts use existing res://systems paths and the existing Godot project scan. Open/import the root Godot 4.3 project normally.

## Validation coverage

- Per-level production spawn roots for Level 0–5 and every configured entity.
- Deterministic descriptor parity and repeated staging.
- Window north/west closed-wall ownership.
- Entity metadata and in-cell placement.
- Maze schema-2 save/restore and schema-1 migration.
- Missing/unsupported algorithm version rejection without mutating live roots.
- Extreme finite float save fields rejected before integer conversion.
- Legacy schema-1 nested maze stream migration through BackroomsLocationSession and BackroomsTransitionManager.
- Combined world envelope preserves and restores the nested schema-2 Runtime/Session payload.

Exact-head Godot 4.3 focused tests and Full Compatibility Gate are pending for the new child branch. Local Godot executable is unavailable; no local engine pass is claimed.

## Limitations

- Only spawn algorithm version 1 is implemented/supported. Future algorithm changes must preserve legacy version 1 behavior or provide an explicit migration.
- Spawn roots are metadata-only; no visual factory, collision, navigation, AI, animation, perception or combat.
- Headless tests do not validate graphical placement, lighting, collision feel, GPU cost, iPhone controls or target-device performance.
- The current same-scene vertical-offset Backrooms architecture remains interim.

## Next steps

1. Run the updated Backrooms stream-state, maze-cell Runtime, Runtime/Session and combined-envelope tests on this exact branch HEAD.
2. Complete the full Godot 4.3 gate and inspect the complete job log.
3. Correct any real runtime diagnostics without weakening fail-closed behavior.
4. Record exact-head validation in the PR and Notion M0.1.60 asset page.
5. Obtain independent review; integrate only into PR #388's feature branch after review, then rerun #388. Do not merge main.
