# KROLL Core Drill M0.1

A lane-planning mining arcade game for Godot 4.3+. Guide a drill through three eight-row underground sites, collect enough ore, and keep energy, heat and hull integrity within safe limits.

## Controls

- A / D or Left / Right: move the drill one lane left or right.
- Space: drill into the selected lane.
- V: vent heat once per depth row, at an energy cost.
- R: restart the current site.
- N: advance after meeting the current site's ore quota.
- Tap a lane to select it; on-screen LEFT, RIGHT, VENT, DRILL, RESTART and NEXT buttons support touch-only play.

## Tile types

- Rock: low energy and heat cost.
- Copper, iron and titanium: add ore and score, with increasing drill cost.
- Gas: restores a little energy and cools the drill.
- Coolant ice: spends energy to reduce heat.
- Lava and hard rock: dangerous hazards that increase heat or damage the drill housing.

## Objective

Complete all three sites. Each drill action moves one row deeper and may shift at most one lane left or right. Reach the bottom with the site's ore quota while avoiding thermal shutdown, power loss and hull failure.

## Import

Open daily_games/KROLL_Core_Drill/project.godot with Godot 4.3 or newer, then run main.tscn. The game uses procedural 2D drawing and built-in input only; no external assets, audio, add-ons or network access are required.

## Tests

- tests/rules_test.gd: validates all three authored layouts, known winning routes, lane limits, coolant limits, energy failure and thermal shutdown.
- tests/game_smoke_test.gd: validates scene startup, drill/vent actions, touch buttons and sector progression.
- Root CI also validates Survival Test Hub registration and the production SurfaceWorld interaction-target lifecycle guard.
