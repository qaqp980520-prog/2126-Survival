# KROLL Bastion Array M0.1

A standalone Godot 4.3+ lane-defense strategy game. Build towers on a three-lane, five-column board, then start an incoming wave and protect the reactor core.

## Gameplay

- Three waves contain 4, 5 and 6 enemies.
- The core starts with 20 integrity; each enemy that reaches it deals 4 damage.
- Start with 100 credits. A tower costs 40 credits and attacks enemies in its own lane within 1.75 cells.
- Towers deal 3 damage per shot. Enemies have 6 health, move at 0.62 cells per second and grant 15 credits when defeated.
- Clearing a wave grants 25 credits and 100 campaign points. Each wave reward is granted once; campaign score is capped at 300.
- Build towers only in columns 2–4. Entry and core columns are reserved.
- The enemy lane order is deterministic so each run is reproducible. Build placement and timing still determine whether the core survives.

## Controls

- Click or touch an empty build cell in columns 2–4 to place a tower.
- Space: start the next wave.
- R: restart the campaign.
- Number keys 1–9: build at the corresponding lane/column cell (1–3 first lane, 4–6 second lane, 7–9 third lane).

## Import

Open project.godot in Godot 4.3+ and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, network calls or save integration.

## Tests

- tests/rules_test.gd covers build validation, credits, lane targeting, enemy leaks, core failure and one-time wave rewards.
- tests/game_smoke_test.gd instantiates the real scene, checks all 15 cells, builds towers, starts a wave, advances the simulation and verifies campaign reset.
