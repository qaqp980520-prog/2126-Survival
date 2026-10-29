# KROLL Rotor Rescue M0.1

A deterministic 2D flight-rescue arcade game for Godot 4.3+. No external assets, plugins, or network access are required.

## Import

Open `daily_games/KROLL_Rotor_Rescue/project.godot` in Godot Project Manager and run the main scene.

## Goal

Rescue all three crew markers and return to the green H landing pad before fuel or the 90-second mission timer runs out. Fly slowly near crew and the landing pad. Grey structures are collision hazards.

## Controls

- A/D or Left/Right: horizontal thrust.
- W/S or Up/Down: vertical thrust.
- On-screen LEFT/UP/DOWN/RIGHT buttons: hold for touch thrust.
- R or RESTART: restart the current seed.
- N or NEXT: rotate through the three deterministic layouts.

## Verification

- `tests/rules_test.gd`: deterministic layout, thrust/fuel, speed cap, rescue speed, obstacle collision, safe landing win, terminal lock.
- `tests/game_smoke_test.gd`: scene instantiation, touch controls, rules integration.
- CI: pending until the exact PR head completes the shared Godot 4.3 workflow.

## Limits

This is an arcade prototype with simple vector-drawn visuals and bounded 2D flight physics, not a realistic flight model. GUI/GPU/iPhone hardware QA is not claimed without device testing.
