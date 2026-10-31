# KROLL Star Chart M0.1

A small Godot 4 telescope-alignment puzzle. Track four stars in each of three authored sectors before the signal window closes.

## Controls

- `W/A/S/D` or arrow keys: adjust the reticle vertically and horizontally.
- `Q/E`: zoom out/in. Higher zoom gives a tighter lock tolerance.
- `Space`: lock the current star.
- `R`: restart the current sector.
- `N`: advance after completing a sector.
- Left mouse click: place the reticle.
- Right mouse click: lock the current star.
- Touch: tap to aim, drag to fine-adjust, tap the on-screen LOCK TARGET control.

**Touch limitation:** M0.1 does not yet expose touch buttons for restart or next sector. A touch-only player can aim and lock, but needs a keyboard for full campaign navigation.

## Rules

- Each sector contains four ordered stars.
- The reticle must be within the current lock tolerance to register a star.
- A failed lock costs 1.5 seconds.
- A successful lock adds a score based on zoom and remaining time.
- Complete all three sectors to finish the survey.

## Import

Open `project.godot` in Godot 4.3 or later, or launch KROLL Star Chart from the repository's Survival Test Hub. A small scene-script shim supports both the nested standalone project root and the repository root. The project uses only built-in 2D drawing and has no external assets or add-ons.

## Tests

- `tests/rules_test.gd`: mission data, normalized bounds, lock tolerance and progress rules.
- `tests/game_smoke_test.gd`: scene instantiation, target locking, retry behavior and touch-drag input.
- Root CI also tests the Survival Test Hub launch path and production SurfaceWorld camera-ray interaction integration.

Cloud CI runs the import, rules and runtime smoke tests. Manual GUI, GPU and iPhone QA are separate and are not implied by headless CI.
