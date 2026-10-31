# KROLL Echo Mapper M0.1

A top-down sonar exploration puzzle for Godot 4.3+.

## Objective

Explore three KROLL maintenance sectors, recover all three signal beacons in each sector, then reach the extraction hatch. Unvisited cells remain hidden. A sonar pulse reveals walls and signal markers within a Manhattan radius for a limited number of turns. Bumping an unknown wall briefly reveals the obstruction.

## Controls

- WASD / arrow keys: move
- Space: ping sonar
- R: restart the current mission
- N: advance after successful extraction
- On-screen buttons: equivalent touch controls

## Missions

1. Dockside Echo
2. Coolant Echo
3. Archive Echo

Each mission has a six-pulse sonar budget and a 60-turn exploration limit. Blocked movement costs one turn; an unavailable sonar pulse does not.

## Import

Open this folder's project.godot in Godot 4.3 or newer. The project has no external assets, plugins, audio or network dependencies. It is also registered in the root Survival Test Hub.

## Tests

- tests/rules_test.gd: sonar range/duration, hidden cells, wall contact, charge limits, invalid actions and deterministic routes for all missions.
- tests/game_smoke_test.gd: scene initialization, real touch-button signals and all three live mission completions.
- Root-project compatibility is checked by the Survival Test Hub smoke test.
