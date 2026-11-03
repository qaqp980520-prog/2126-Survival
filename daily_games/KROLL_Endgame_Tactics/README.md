# KROLL Endgame Tactics M0.1

A compact, turn-based rook endgame puzzle. In each of three authored 8×8 positions, find the unique legal rook move that delivers checkmate.

## Missions

1. Back-Rank Seal
2. Reverse File
3. Side-File Lock

Each solved puzzle awards 100 points once. A legal non-mating move consumes one of three attempts and restores the starting position. Three failed attempts lock the current puzzle until reset. A solved puzzle cannot be reset or replayed for duplicate points.

## Controls

- Mouse/touch: tap the white rook, then tap a destination square.
- Arrow keys: move the board cursor.
- Enter: select or move on the cursor square.
- Escape: clear rook selection.
- R: reset the current unsolved puzzle.
- N: advance after solving a puzzle.
- C: restart the full campaign.

The on-screen RESET POSITION, NEXT PUZZLE and RESTART CAMPAIGN controls are available for touch users.

## Rules scope

This is an authored rook mate-in-one trainer, not a complete chess implementation. The validator models rook sliding, white-king adjacency attacks, the black king's adjacent escape squares, and fixed black-pawn blockers. Castling, en passant, pawn movement, promotion and a general-purpose chess engine are intentionally outside M0.1.

## Files

- project.godot — Godot 4.3 standalone project.
- main.tscn and main_root.tscn — standalone and repository-root entry scenes.
- main.gd — responsive board UI, keyboard/mouse/touch input and one-time campaign scoring.
- rules.gd — deterministic rook movement, check detection and checkmate validation.
- tests/rules_test.gd — unique-solution, movement, immutability and checkmate tests.
- tests/game_smoke_test.gd — campaign progression and duplicate-score smoke test.

## Dependencies and import

- Godot 4.3+.
- No external assets, add-ons, audio files, network access or world-save dependency.
- Standalone: open daily_games/KROLL_Endgame_Tactics/project.godot and run main.tscn.
- Repository root: launch daily_games/KROLL_Endgame_Tactics/main_root.tscn from the Survival Test Hub. The main script resolves rules.gd relative to its own resource path.

## Validation status

Pending exact-head cloud Godot 4.3 CI. Local rendered GUI, GPU and physical iPhone touch QA remain untested.
