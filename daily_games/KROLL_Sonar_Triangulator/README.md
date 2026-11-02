# KROLL Sonar Triangulator M0.1

A touch-friendly acoustic search puzzle for Godot 4.3.

## Gameplay

- Survey a hidden beacon on an 8×8 seabed grid.
- Four acoustic buoys sit at the grid corners.
- Each ping reports the Euclidean distance rounded to the nearest grid unit.
- Three pings unlock target selection.
- Nereid Wreck and Trench Beacon resolve after three pings.
- Abyssal Relay intentionally leaves two plausible cells after any three pings; use the fourth buoy or eliminate a false return.
- A wrong guess removes only that candidate and applies a score penalty.
- A passed mission can only be scored once. The campaign contains three missions.

## Controls

- 1–4: ping the four buoys.
- Tap/click a candidate cell: select the target.
- Enter: lock the selected target.
- N: advance after a successful survey.
- R: restart the whole campaign.

Every action also has an on-screen button, so the complete campaign is playable with touch controls.

## Scoring

- Base mission score: 100.
- Fourth ping: -15.
- Each false-return guess: -20.
- Minimum mission score: 25.
- Campaign score is cumulative and can only be cleared by restarting the campaign.

## Files

- project.godot
- main.tscn / main_root.tscn
- main.gd
- rules.gd
- tests/rules_test.gd
- tests/game_smoke_test.gd

No third-party plugins, external assets, audio files or network dependencies are required.

## Import

Open this folder as a standalone Godot 4.3 project, or launch the main_root.tscn wrapper from the repository Survival Test Hub.

## Validation

The rules tests exhaustively validate the three mission targets, the intentionally ambiguous second mission, fourth-ping resolution, false-return elimination, scoring and campaign lock. The runtime smoke test exercises both the unique-return and ambiguous-return paths. Full repository CI additionally checks root Test Hub loading.
