# KROLL Biome Balance M0.1

A deterministic ecosystem-management puzzle built with Godot 4.3+.

## Objective

Stabilize three habitats over six turns. Each turn allows two interventions. At the end of turn six, every habitat must have flora >= 2, herbivores >= 2 and predators <= 2; total biodiversity must be at least 18 and at least six interventions must have been used.

## Controls

- 1 / 2 / 3: select the active habitat.
- P: plant one flora unit.
- G: introduce one grazer.
- W: add two water units.
- C: remove one predator.
- Enter: advance the turn.
- R: restart the current seed.
- N: next deterministic habitat ordering.
- Mouse/touch: use the on-screen selector and buttons.

## Rules

- Flora grows by one when a habitat has at least two water units; growth consumes two water units. Otherwise any remaining water decays by one.
- Flora at level three or higher supports natural grazer growth. A habitat with no flora loses a grazer.
- A predator population grows when at least three grazers are present and predators already exist. A habitat without grazers loses one predator.
- Resources are bounded: three seed tokens, three grazer releases and four water cells per survey. Each turn allows two interventions.
- Seeds 17, 29 and 41 deterministically reorder the same three starting habitat profiles.

## Import and dependencies

Open daily_games/KROLL_Biome_Balance/project.godot with Godot 4.3 or later. No external assets, plugins or network dependencies are required.

## Validation

- tests/rules_test.gd: deterministic layouts, invalid actions, per-turn action limit, stable solution for all seeds and failure when predator pressure is ignored.
- tests/game_smoke_test.gd: scene controls, all three complete six-turn runs, restart and next-layout behavior.

This is a discrete ecosystem puzzle, not a scientific population model or a real-world conservation simulator.
