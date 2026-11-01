# KROLL Faultline Cartographer M0.2

A deterministic 7x7 subsurface triangulation game for Godot 4.3+.

## Objective

Locate three hidden deposits by activating three fixed seismic probes. Each probe reports the rounded Euclidean grid distance to the deposit. The grid origin is the northwest cell `(0,0)`; X increases east and Y increases south.

Combine the three readings to infer the hidden coordinate. After all probes fire, all 49 cells become selectable, but the game does not highlight the answer. A wrong coordinate fails the current survey; reset the failed survey to try again.

Surveys:
- Iron Vein
- Quartz Seam
- Uranium Pocket

Each completed survey awards 100 points. The campaign score carries between surveys.

## Controls

- 1 / 2 / 3: activate Northwest / Northeast / Southwest probe
- Mouse/touch: activate probe buttons
- Click any grid cell after all three pulses: submit a coordinate candidate
- Space: confirm the selected coordinate
- R: reset an unfinished or failed survey
- N: advance after a successful survey

## Files

- `project.godot`, `main.tscn`: standalone project.
- `main_root.tscn`: root-project Test Hub entry.
- `main.gd`: grid UI, probe controls, hidden-answer presentation and campaign flow.
- `rules.gd`: deterministic distance, candidate intersection, guess validation and survey rules.
- `tests/rules_test.gd`: all three triangulation solutions, all probes, deliberate wrong guesses, reset and campaign score.
- `tests/game_smoke_test.gd`: scene, grid controls, wrong-guess failure, retry and successful survey completion.

No external assets, plugins, audio or network dependencies. The prototype has no save system, random geology, multiplayer or local renderer/device QA.
