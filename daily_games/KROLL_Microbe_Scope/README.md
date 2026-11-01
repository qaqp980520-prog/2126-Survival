# KROLL Microbe Scope M0.1

A deterministic microscope-calibration game for Godot 4.3+.

## Objective
Tune four microscope settings to capture three specimens: Diatom Valve, Pollen Grain and Tardigrade.

- Focus: 0–100
- Magnification: 1–5
- Illumination: 0–100
- Stain filter: 0–3

Each specimen allows five capture attempts. A successful capture requires focus and illumination within their tolerances, exact magnification and the correct stain filter. Failed captures report which settings are out of range. Captures add clarity to the campaign score.

## Controls
- A / D: focus −/+ 2
- W / S: magnification −/+ 1
- Q / E: illumination −/+ 5
- Z / X: stain filter −/+ 1
- Space: capture
- R: reset current specimen
- N: advance after a successful capture

The four parameter rows and three action buttons support mouse and touch input.

## Files
- `project.godot`, `main.tscn`: standalone project.
- `main_root.tscn`: root-project entry scene.
- `main.gd`: controls, UI and campaign flow.
- `rules.gd`: deterministic calibration, tolerance, capture and progression rules.
- `specimen_view.gd`: procedural vector microscope imagery for diatom, pollen and tardigrade samples.
- `tests/rules_test.gd`: parameter bounds, calibration, attempts, failure lock, reset and campaign progression.
- `tests/game_smoke_test.gd`: scene, controls, public parameter API, capture and next-specimen smoke test.

No external assets, plugins, audio or network dependencies. The prototype has no campaign save or multiplayer.
