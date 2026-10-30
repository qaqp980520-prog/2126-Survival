# KROLL Field Recorder M0.1

A top-down wildlife photography field survey built with Godot 4.3+.

## Objective

Record three species at each field site, then return to the base. A photograph requires a stable camera, suitable distance, correct facing direction and matching focus. Failed shutter attempts consume a small amount of battery; successful photographs consume more.

## Controls

- WASD / arrow keys: move and set camera facing
- Q / E: decrease / increase focus
- Space: take photograph
- R: restart field site
- N: next field site
- On-screen direction, focus and capture buttons support mouse and touch.

## Import and validation

Open `project.godot` in Godot Project Manager. No external assets, plugins, audio or network access are required. Rules and scene smoke tests are in `tests/`.

## Limits

M0.1 uses three authored field sites and deterministic sinusoidal wildlife patrols. It has no persistent field journal, species encyclopedia, procedural ecosystem or multiplayer. Focus and battery tuning are provisional.
