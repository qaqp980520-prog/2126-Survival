# KROLL Sonar Triangulator M0.1

A touch-friendly acoustic search puzzle for Godot 4.3.

## Gameplay

- Survey a hidden beacon on an 8×8 seabed grid.
- Three buoys sit at the north-west, north-east and south-west corners; the fourth is on the southern edge at (4, 7).
- Each ping reports the Euclidean distance rounded to the nearest grid unit.
- Three pings unlock target selection.
- Nereid Wreck and Trench Beacon resolve after three pings.
- Abyssal Relay leaves two plausible cells under the standard A/B/C corner-buoy plan; buoy D on the southern edge breaks that tie. Other three-buoy combinations may resolve sooner. You can also eliminate a false return.
- A wrong guess removes only that candidate and applies a score penalty.
- A passed mission can only be scored once. The campaign contains three missions.

## Controls

- 1–4: ping the four buoys.
- Tap/click a candidate cell: select the target.
- Enter: lock the selected target.
- N: advance after a successful survey.
- R: restart the whole campaign.

Every action also has an on-screen button, so the complete campaign is playable with touch controls. The board and action rows use a compact profile below 520px; 320px and 375px viewport widths are covered by the runtime smoke test.

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
