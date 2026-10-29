# Run 38 — KROLL Echo Survey and WorldSessionController M0.1

Date: 2026-10-29

## Deliverable A: KROLL Echo Survey

Path: daily_games/KROLL_Echo_Survey/

A deterministic 8×8 turn-based sonar exploration game. The player scans hidden terrain, avoids rocks, recovers three salvage caches and returns to the extraction cell before oxygen reaches zero. Three fixed layouts are provided (seeds 11, 23 and 37). A ping costs two battery and one oxygen, revealing cells within Manhattan radius two. Movement costs one oxygen; walking into an unseen rock reveals it but does not move the player.

Files:
- project.godot and main.tscn: self-contained project entry point.
- main.gd: keyboard, mouse and touch controls plus drawn grid presentation.
- rules.gd: deterministic rules/state transitions.
- tests/rules_test.gd: layout reachability, oxygen route budget, sonar, wall collision, invalid input, exhaustion and extraction.
- tests/game_smoke_test.gd: scene load and live controls.
- README.md: import and controls.

Dependencies: Godot 4.3+, no external assets or plugins. Open daily_games/KROLL_Echo_Survey/project.godot with Godot Project Manager.

## Deliverable B: formal world-session base

Path: scripts/world.gd; adopted by prototypes/SurfaceChunkStreamingPlayground.gd.

WorldSessionController is the shared composition root for the existing streamed-world prototype. It owns MineralVeinRegistry, CropRegistry, CropPlotController, SurvivalWorldBridge, MineralChunkController and MineralGridStreamingDirector; the derived scene supplies its chunk factory, environment, player, HUD and chunk geometry. Save/restore and failure-reporting methods were moved to the base class without changing the schema-1 envelope. The stream save now includes an optional inventory payload alongside minerals/crops; restore validates inventory in a temporary model before mutation and rolls it back if target streaming fails. Legacy schema-1 saves without inventory remain loadable and preserve the current inventory. get_world_session_status() provides a stable diagnostic snapshot.

New regression: tests/world_session_controller_test.gd verifies idempotent initialization, component status, initial 3×3 stream window, save/restore, and invalid-schema no-mutation.

Limitations: this is the first reusable world-session controller, not a finished production world. The streamed prototype still supplies the player and chunk factory; full generated terrain/object mutation persistence and asynchronous streaming remain open. GUI/GPU/iPhone testing is not claimed without a local Godot executable.

## Candidate verification

The candidate branch is feature/run38-echo-survey-world-session-controller-2026-10-29. The shared Godot 4.3 CI has been extended with Echo Survey import/rules/runtime checks and the world-session integration test. Final status must be based on the exact candidate HEAD CI; until then, tests are pending, not passed.
