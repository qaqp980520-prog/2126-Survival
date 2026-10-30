# KROLL Fossil Lab M0.1

A deterministic fossil-fragment assembly puzzle built with Godot 4.3+.

## Objective

Reconstruct each amber fossil silhouette by selecting, rotating and placing four three-cell bone fragments. Every fragment must fit fully inside the target outline without overlap.

## Controls

- 1–4: select a fragment
- WASD: move the placement cursor
- Q / E: rotate left / right
- Space: place the selected fragment
- Backspace: return the selected fragment to the tray
- R: restart the current blueprint
- N: next blueprint
- Mouse: click a board cell to place the selected fragment
- On-screen buttons support mouse and touch

## Blueprints

Dockside Hadrosaur, Ridge Raptor and Floodplain Triceratops. Each blueprint has a deterministic authored solution and a twelve-cell fossil outline.

## Import and tests

Open `project.godot` in Godot Project Manager. No external assets, plugins, audio or network access are required.

Run `tests/rules_test.gd` and `tests/game_smoke_test.gd` from the project root.

## Limits

M0.1 uses four fixed triomino fragments and three authored silhouettes. It has no procedural fossil generation, campaign save or multiplayer.
