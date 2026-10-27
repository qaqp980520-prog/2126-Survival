# Run 18 — KROLL Orbital Mini Golf + stream coordinate guards

## Assets

- Mini game: `daily_games/KROLL_Orbital_Mini_Golf/`
- Streaming coordinator: `systems/MineralGridStreamingDirector.gd`
- Regression tests:
  - `tests/mineral_grid_streaming_position_validation_test.gd`
  - `tests/mineral_grid_streaming_recovery_test.gd`
  - `tests/mineral_grid_streaming_diagnostics_test.gd`
- Workflow: `.github/workflows/godot-validation.yml`

## KROLL Orbital Mini Golf M0.1

A standalone Godot 4.3+ top-down three-course mini-golf game. It uses a small custom 2D ball simulation, pull-back aiming by mouse/touch, keyboard directional shots, course obstacles, wall/obstacle restitution, a 90-second total timer, and a five-stroke per-course limit. No external assets or add-ons are required.

Import with Godot Project Manager by opening `daily_games/KROLL_Orbital_Mini_Golf/project.godot`.

Tests cover shot power limits, no-op tiny drags, friction, cup capture speed, reflection, course advance, timer expiry, restart, and ejection if a ball starts inside an obstacle.

Known limits: the physics is an intentionally small custom approximation rather than a rigid-body engine; no graphical manual or iPhone device test is claimed.

## Mineral grid stream hardening M0.2

- Reject non-finite chunk dimensions before coordinate conversion.
- Reject finite but out-of-range grid coordinates (absolute grid X/Z above 1,000,000,000) before `floori` and before recovery mutates the director's managed map.
- Return `Vector2i.ZERO` from the coordinate helper for invalid dimensions or unsafe positions.
- Reject non-canonical chunk IDs such as `surface/chunk_01_1`, which parse to the same numeric coordinate as `surface/chunk_1_1` but are not the canonical ID produced by the director.
- Extend position-validation and recovery tests to prove rejected inputs leave existing controller/director state unchanged.

## Test cleanup

The failure-diagnostics, Cipher Recall, Cargo Tugs, and Vector Rally smoke tests now own their watchdog Timer nodes and stop/free them in the finish path instead of using an unowned SceneTreeTimer. The goal is to remove the non-fatal ObjectDB leak warnings previously observed at test exit.

## Validation status

Candidate only until the exact-head Godot 4.3 workflow passes. The local environment has no Godot executable, so no local engine or GUI test is claimed. Do not merge the feature PR until the complete CI succeeds.

## Next steps

1. Inspect exact-head CI, including root project import, new mini-golf import/rules/runtime tests, finite-coordinate and canonical-ID regressions, and the full existing suite.
2. If CI succeeds, merge the feature PR and verify the resulting main SHA and main-push run.
3. Update `PROJECT_INDEX.md` and the Notion asset index with final commit and test evidence.
4. Continue integrating the synchronous factory-driven streaming director with the production world generator; asynchronous streaming remains unimplemented.
