# KROLL Faultline Cartographer M0.1

A deterministic 7x7 subsurface triangulation game for Godot 4.3+.

## Objective

Locate three hidden deposits by activating three fixed seismic probes. Each probe reports the rounded Euclidean distance to the deposit. Intersect the readings, select the only remaining candidate cell and confirm the survey.

Surveys:
- Iron Vein
- Quartz Seam
- Uranium Pocket

Each completed survey awards 100 points. The campaign score carries between surveys.

## Controls

- 1 / 2 / 3: activate Northwest / Northeast / Southwest probe
- Mouse/touch: activate probe buttons
- Click a remaining candidate cell: select location
- Space: confirm selected location
- R: reset an unfinished survey
- N: advance after a successful survey

The 7x7 map shows the remaining candidate cells after each pulse. The deposit location is not displayed before confirmation.

## Files

- `project.godot`, `main.tscn`: standalone project.
- `main_root.tscn`: root-project Test Hub entry.
- `main.gd`: grid UI, probe controls and campaign flow.
- `rules.gd`: deterministic distance, candidate intersection and survey rules.
- `tests/rules_test.gd`: all three triangulation solutions, invalid/duplicate probes, reset and campaign score.
- `tests/game_smoke_test.gd`: scene, 7x7 grid, three probe controls and first survey completion.

No external assets, plugins, audio or network dependencies. The prototype has no save system, random geology, multiplayer or local renderer/device QA.
