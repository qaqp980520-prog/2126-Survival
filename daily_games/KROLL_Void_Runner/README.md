# KROLL Void Runner M0.1

A real-time three-lane reflex runner built with Godot 4.3+.

## Objective

Reach the exit in each of three fixed routes while collecting the required data cells. Avoid barriers by jumping, low gates by sliding, and drones by changing lanes. Two integrity points are available per run.

## Controls

- A / Left: move one lane left
- D / Right: move one lane right
- Space / W: jump
- S / Down: slide
- R: restart route
- N: next route
- On-screen buttons support mouse and touch.

## Import and validation

Open `project.godot` with Godot Project Manager. No external assets, add-ons, audio or network access are required. Rules and scene smoke tests are in `tests/`.

## Limits

M0.1 uses deterministic authored obstacle schedules and a single-screen 2D view. It has no procedural endless mode, high-score persistence or multiplayer.
