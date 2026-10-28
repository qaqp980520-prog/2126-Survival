# KROLL Signal Sleuth + Mineral Registry Transactionality M0.1

## New game

Path: daily_games/KROLL_Signal_Sleuth/

A five-by-five nonogram-style deduction game with three deterministic patterns, generated row/column clues, a 60-mark budget, mouse/touch cell cycling, keyboard cursor movement, restart and next-grid controls.

Files: project.godot, main.tscn, main.gd, rules.gd, README.md, tests/rules_test.gd, tests/game_smoke_test.gd.

Dependency/import: Godot 4.3+, no external assets/add-ons. Open daily_games/KROLL_Signal_Sleuth/project.godot in Project Manager.

## Existing system regression

File: tests/mineral_vein_registry_atomicity_test.gd.

The test checks that a multi-record payload with a valid earlier record and invalid later record is rejected without partial mutation; validate_save_dict is side-effect-free; valid multi-record restore works; unknown mineral IDs in unloaded records are rejected without replacing the saved registry; and fractional registry schema versions are rejected atomically.

## Validation

The tests are wired into .github/workflows/godot-validation.yml. Exact-head Godot 4.3 CI is required before merge. No local Godot executable is available, so local GUI/GPU/iPhone testing is not claimed.

## Limits and next steps

The active-world mineral registry now persists stable-ID vein stock, but the full generated chunk scene state and crop persistence remain unintegrated. The formal M1.3 production world controller is still absent. Next: continue world-session integration and add persistence for any crop system once its runtime source is present in main.
