# KROLL Pulse Rhythm M0.1

A standalone Godot 4 rhythm/timing mini-game using four lanes and a 32-note authored chart.

## Controls
- A / Left Arrow: lane 1
- S / Down Arrow: lane 2
- D / Up Arrow: lane 3
- F / Right Arrow: lane 4
- R: restart after win or failure
- Touch devices: tap the lower hit area in the matching lane

## Rules
- PERFECT (within 0.075 seconds): +300 points.
- GOOD (within 0.16 seconds): +100 points.
- Off-beat input or missed notes consume one of five reactor cores.
- Finish the chart with at least one core to win.

## Requirements and import
- Godot 4.3 or later; no external assets or add-ons.
- Open this folder's `project.godot` in Godot Project Manager.
- Main scene: `res://main.tscn`.

## Validation
The repository CI runs headless project import, rule boundary tests, and a runtime smoke test. Local GUI play and iPhone touch testing have not yet been performed.
