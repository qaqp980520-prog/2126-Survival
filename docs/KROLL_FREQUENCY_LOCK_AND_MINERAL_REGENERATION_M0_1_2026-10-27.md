# Run 24 — KROLL Frequency Lock and mineral regeneration guard

## New playable asset

- Project: `daily_games/KROLL_Frequency_Lock/project.godot`
- Scene: `daily_games/KROLL_Frequency_Lock/main.tscn`
- Gameplay: four unique symbols selected from six, eight attempts, exact/misplaced feedback, restart, keyboard/mouse/touch input.
- Rules and tests: `rules.gd`, `tests/rules_test.gd`, `tests/game_smoke_test.gd`.
- Dependency/import: Godot 4.3+, open the game's `project.godot`; no external assets/addons.
- Test status at branch creation: pending exact-head CI; no success claimed until the run completes.
- Limits: no local GUI/GPU/iPhone test; this is a compact code-breaking prototype.

## Existing-system change

- `systems/MineralMiningNode.gd`: manual `restore_vein(units)` now resets the regeneration interval timestamp when stock actually increases. This prevents a recently restored depleted vein from immediately receiving all regeneration intervals accumulated before the restore.
- `tests/mineral_mining_regeneration_test.gd`: deterministic tests for interval boundaries, clock rollback, full-stock timer reset, invalid-save non-mutation, legacy schema-v1 loading, and restore-clock reset.
- Failure scenario: a depleted vein has an old timestamp; a positive restore adds one unit; the next regeneration check must not count the old depleted period as fresh regeneration time.

## Validation gates

- Exact candidate HEAD must pass root-project import, the new game's import/rules/runtime tests, and the mineral regeneration tests.
- Also run existing underground mining integration to verify the inventory/vein transaction remains compatible.
- Do not merge if any step fails.
