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
- Reject canonical-looking IDs outside the supported absolute grid-coordinate bound of 1,000,000,000 before rebuilding the managed map.
- Extend position-validation and recovery tests to prove rejected inputs leave existing controller/director state unchanged.

## Test cleanup

The failure-diagnostics, Cipher Recall, Cargo Tugs, and Vector Rally smoke tests now own their watchdog Timer nodes and stop/free them in the finish path instead of using an unowned SceneTreeTimer. The goal is to remove the non-fatal ObjectDB leak warnings previously observed at test exit.

## Final validation status｜2026-10-27

- PR #67 merged as `408f263648ac88a6097399331cc8fd9398489601`; this is the main SHA confirmed immediately after merge.
- Exact-head Godot 4.3 CI Run ID `40445410307` succeeded with all 78 job steps completed successfully and zero failed steps.
- Mini Golf import, rules tests, and runtime smoke test passed. Mineral streaming diagnostics, recovery, position validation, and director tests passed.
- The exact-head log contains no actual Godot `SCRIPT ERROR:`, `ERROR:`, or `FAIL:` lines and no `ObjectDB instances leaked at exit` warning.
- Local Godot executable unavailable; no local engine, GUI, GPU, or iPhone test is claimed.

## Remaining work

1. Connect the synchronous factory-driven streaming director to the production world generator.
2. Add production-scene load/unload/save/restore acceptance tests and define retry behavior for repeated factory/controller failure.
3. Perform graphical playtesting and iPhone validation in a suitable environment.

## Final repository reconciliation

- Feature PR #67 merge commit: `408f263648ac88a6097399331cc8fd9398489601`.
- Documentation PR #68 merge commit and current main SHA at this reconciliation: `1b7a12fe92696f3087ed6d9bb794d5cc97611ab0`.
- PR #67 exact-head CI Run ID `40445410307`: 78/78 steps successful.
- PR #68 exact-head CI Run ID `40445774345`: 78/78 steps successful.
- Local Godot, GUI, GPU, and iPhone testing are not claimed.
