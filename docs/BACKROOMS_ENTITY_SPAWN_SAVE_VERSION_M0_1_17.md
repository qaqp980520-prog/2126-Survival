# Backrooms Entity Spawn Algorithm Save Version — M0.1.17

## Purpose

Persist the deterministic entity-spawn algorithm version in the Backrooms maze stream save payload. A restored maze must not silently use a different entity roster or placement algorithm after a future code change.

## Runtime contract

- `systems/BackroomsEntityDirector.gd`
  - Exposes `is_spawn_algorithm_version_supported()`.
  - `get_cell_spawn_descriptors()` accepts an explicit algorithm version and rejects unsupported versions.
  - Spawn descriptors carry the requested version rather than implicitly copying the current constant.
- `systems/BackroomsMazeStreamState.gd`
  - Advances the nested maze stream save schema from 1 to 2.
  - Schema 2 writes `entity_spawn_algorithm_version` alongside the existing layout algorithm version.
  - Schema 1 remains readable and maps to the explicit legacy spawn algorithm version 1.
  - Missing schema-2 version fields, unsupported spawn versions, unsupported layout versions, malformed coordinates and unsupported schema versions fail closed before live state is mutated.
  - Cell descriptors include the saved spawn algorithm version so plan/commit parity includes the version.
- `systems/BackroomsMazeCellRuntime.gd`
  - Passes the candidate stream state's version into each staged cell builder.
  - Requires descriptor/version parity and a supported algorithm before building entity roots.
  - Records the same version on the cell root and every entity root.
  - Reconstructs legacy schema-1 saves using version 1, then writes schema 2 on the next save.
- Tests cover direct version support/rejection, schema-1 migration, schema-2 persistence, missing/unsupported version rejection, unchanged live roots on rejected restore, production root metadata parity, and migration through the active BackroomsLocationSession/TransitionManager restore path.

## Files

- `systems/BackroomsEntityDirector.gd`
- `systems/BackroomsMazeStreamState.gd`
- `systems/BackroomsMazeCellRuntime.gd`
- `tests/backrooms_maze_stream_state_test.gd`
- `tests/backrooms_maze_cell_runtime_test.gd`
- `tests/backrooms_runtime_session_integration_test.gd`
- `docs/BACKROOMS_ENTITY_SPAWN_SAVE_VERSION_M0_1_17.md`

## Dependencies and import

- Parent PR #363 — deterministic production entity roots in SurfaceWorld-owned maze cells.
- Ancestors: PR #345 runtime/session transaction, #344 maze cell runtime, #343 stream state, #342 deterministic maze layout.
- Godot 4.3; no third-party dependencies, new autoloads, Project Settings, scene changes or external assets.

Import:

```sh
godot --headless --path . --import
```

Focused tests:

```sh
godot --headless --path . --script res://tests/backrooms_maze_stream_state_test.gd
godot --headless --path . --script res://tests/backrooms_maze_cell_runtime_test.gd
```

The existing `.github/workflows/godot-validation.yml` already includes both tests; the repository-wide exact-head Godot 4.3 Full Compatibility Gate remains required.

## Save compatibility

- Current writer schema: 2.
- Supported reader schemas: 1 and 2.
- Schema 1 has no spawn-version field and is interpreted as legacy algorithm version 1.
- Schema 2 requires an explicit supported `entity_spawn_algorithm_version`.
- Unsupported versions are rejected without replacing the current stream state or live cell roots.
- A successful schema-1 restore emits schema 2 on the next save.

## Validation status

- Code is committed on child branch `fix/backrooms-spawn-algorithm-save-version-2026-11-15`.
- Static source checks confirm schema-2 emission, schema-1 migration, version propagation into cell descriptors and roots, and regression assertions for unsupported/missing versions.
- Exact-head Godot 4.3 focused and Full Compatibility Gates have not yet completed for this new branch. No engine pass is claimed.
- Local Godot 4.3 is unavailable in this execution environment; GitHub Actions is the engine-validation environment.

## Limitations

- Only spawn algorithm version 1 is implemented and currently supported. A future algorithm change must add an explicit implementation for the new version and decide whether legacy version 1 remains readable; it must not simply change the constant and regenerate old saves.
- This change does not add rendered entity meshes, collision, navigation, AI, animation, perception or combat.
- It does not change the outer combined world-envelope schema or the SurfaceWorld player/session contract.
- Graphical inspection, GPU behavior and iPhone behavior remain unverified.

## Next steps

1. Run the two focused Backrooms maze tests on the exact PR HEAD.
2. Complete the exact-head Godot 4.3 Full Compatibility Gate.
3. Review the schema-1 migration against existing combined SurfaceWorld + Backrooms save fixtures.
4. Only after exact-head CI succeeds, request independent review and consider integration into PR #363's parent chain.
