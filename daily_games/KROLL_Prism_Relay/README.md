# KROLL Prism Relay M0.1

A deterministic 7×7 mirror-routing puzzle for Godot 4.3+.

## Goal

Rotate the mirrors so the beam from the source reaches the receiver. Three relay layouts are included; each starts unsolved and can be completed within the 18-rotation power budget.

## Controls

- Click/tap a mirror to rotate it.
- R: restart the current relay.
- N: switch to the next relay.

## Import

Open daily_games/KROLL_Prism_Relay/project.godot with Godot 4.3 or later. No external assets or add-ons are required.

## Validation

- tests/rules_test.gd: deterministic setup, invalid-action immutability, solution paths, terminal lock and turn-budget failure.
- tests/game_smoke_test.gd: main-scene import, 49-cell grid and a full two-rotation solve through the live scene.

The game is a standalone prototype. It is not connected to the 2126 Survival save system.
