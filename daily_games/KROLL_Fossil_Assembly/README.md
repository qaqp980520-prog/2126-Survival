# KROLL Fossil Assembly Lab M0.1

A deterministic polyomino reconstruction puzzle for Godot 4.3+.

## Play
Open this folder as a standalone Godot project or launch the root-integrated scene from the Survival Test Hub.

- Select a fragment from the tray.
- Click a target cell to place it with its current orientation.
- Q / E: rotate the selected fragment.
- WASD / arrow keys: move the placement cursor.
- Space: place at the cursor.
- X: remove the most recently placed fragment (undo).
- R: reset the specimen.
- N: advance after a specimen is complete.

The on-screen buttons support mouse and touch input.

## Specimens
1. Triceratops Skull
2. Ammonite
3. Raptor Claw

Each specimen is a five-by-five silhouette covered by three four-cell polyomino fragments. Every authored reference arrangement is validated by the rules test. Placements outside the silhouette, outside the board, or overlapping existing fragments are rejected without mutating the previous state.

## Files
- project.godot / main.tscn: standalone project.
- main_root.tscn: root-project entry scene.
- main.gd: UI, keyboard and touch controls.
- rules.gd: pure deterministic placement and completion rules.
- tests/rules_test.gd: reference solutions, bounds, silhouette, overlap, rotation and undo checks.
- tests/game_smoke_test.gd: root scene and UI integration smoke test.

No external assets or plugins are required. This is a deterministic puzzle prototype; it has no procedural generation, campaign saves, audio or multiplayer.
