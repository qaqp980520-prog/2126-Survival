# KROLL Fossil Extraction Lab M0.1

A standalone Godot 4.3 excavation game. The player works across three fictional specimen sites and must uncover every fossil fragment while preserving specimen integrity.

## Gameplay

- Each site uses an 8×8 sediment grid labeled A1–H8 and provides a coordinate survey clue.
- Every cell shows its remaining sediment depth; buried fossil locations remain hidden.
- Scanner: spends one scan charge and one action to report how many fossil fragments lie in the selected 3×3 sector.
- Air Scribe: one charge clears one sediment layer from a 3×3 sector without damaging fossils.
- Brush: removes one layer from one cell safely.
- Micro Chisel: removes up to two layers from one cell, but contact with a buried fossil costs 20 integrity.
- Each site begins with 16 actions, 100 integrity, one Air Scribe charge, two chisel charges and two scan charges.
- Expose every fragment before the action budget or specimen integrity reaches zero.

## Campaign and scoring

Three sites: Triceratops Horn, Ammonite Coil and Raptor Claw.

- 100 points: integrity at least 90 and no more than 8 actions.
- 75 points: integrity at least 70.
- 0 points: specimen integrity below the scoring threshold.
- Each site awards campaign points only once, including after a restart.

## Controls

- Mouse or touch: select a tool and tap a grid cell.
- 1: Brush.
- 2: Air Scribe.
- 3: Micro Chisel.
- 4: Scanner.
- R: Restart current site.
- N: Advance after completing a site.
- C: Start a new expedition.

## Import and run

Open this folder's project.godot in Godot 4.3 or later and run main.tscn. No external assets, plugins, audio files or network services are required.

## Tests

- tests/rules_test.gd — mission data, scanner counts, tool effects, integrity, action budget and one-time rewards.
- tests/game_smoke_test.gd — scene construction, 64-cell interface, tool interaction and campaign navigation.

Cloud Godot 4.3 headless CI is the engine-validation target. Local rendered GUI/GPU and physical iPhone QA are separate and must not be inferred from headless tests.
