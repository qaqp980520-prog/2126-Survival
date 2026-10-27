# Run 21 — KROLL Neon Breaker and atomic world save M0.1

## Scope

This candidate contains two independent deliverables:
1. A new standalone Godot 4 mini-game, KROLL Neon Breaker.
2. A safer save-file write/restore path in the active Backrooms Portal Playground, with failure-injection coverage.

## Game asset

- Project: `daily_games/KROLL_Neon_Breaker/project.godot`
- Scene: `daily_games/KROLL_Neon_Breaker/main.tscn`
- Gameplay: `daily_games/KROLL_Neon_Breaker/main.gd`
- Rules: `daily_games/KROLL_Neon_Breaker/rules.gd`
- Tests: `daily_games/KROLL_Neon_Breaker/tests/rules_test.gd`, `daily_games/KROLL_Neon_Breaker/tests/game_smoke_test.gd`
- Dependency: Godot 4.3+, no addons or external assets.
- Import: open `daily_games/KROLL_Neon_Breaker/project.godot` in Godot Project Manager.
- Controls: A/D or arrow keys, mouse, Space/Enter, R; on-screen buttons are available for touch.
- Rules: clear 40 bricks in 60 seconds with three lives; each brick is worth 10 points.
- Validation: exact-head Godot 4.3 CI is required; GUI/GPU/iPhone testing is not claimed.

## Existing-system change

- Controller: `prototypes/BackroomsPortalPlayground.gd`
- Test: `tests/world_session_save_roundtrip_test.gd`
- Save target: `user://backrooms_playground_save.json`
- Write strategy: serialize to a temporary file, flush and parse it back, preserve the previous save as a backup while promoting the new file, and restore the backup if the primary file is missing after an interrupted write.
- Failure-injection tests: obstruct the temporary path and assert that the existing save bytes remain unchanged; then validate replacement JSON and backup recovery.
- Regression: retain existing save/load roundtrip and invalid inventory/non-finite player-position rejection tests.
- Execution: `godot --headless --path . --script res://tests/world_session_save_roundtrip_test.gd` under the CI timeout.

## Current source boundary

`scripts/world.gd` is absent from the repository. This change improves the actual Backrooms Portal Playground controller and does not claim that a separate M1.3 production world controller or crop persistence patches have been integrated.

## Candidate status

- Branch: `feature/run21-neon-breaker-atomic-save-2026-10-27`
- Base: Run 20 documentation merge `31b8038824caf0f368262d243c2052abc4848e8b`
- Candidate PR and exact-head CI status must be recorded after creation. Do not merge before the full Godot 4.3 workflow succeeds.
- Local GUI playtesting and iPhone hardware testing remain outstanding.
