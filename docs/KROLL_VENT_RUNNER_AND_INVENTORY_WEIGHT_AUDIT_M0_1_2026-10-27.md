# Run 25 — KROLL Vent Runner + inventory/mineral weight audit (2026-10-27)

## New game asset

- Path: `daily_games/KROLL_Vent_Runner/`
- Version: M0.1; Godot 4.3+; no external assets/add-ons.
- Gameplay: side-view platform escape; move/jump across hand-authored platforms, collect five cells, avoid two moving hazards, use vent boost surfaces, reach the hatch within 90 seconds and three lives.
- Files: `project.godot`, `main.tscn`, `main.gd`, `rules.gd`, `tests/rules_test.gd`, `tests/game_smoke_test.gd`, `README.md`.
- Validation: canonical Godot 4.3 workflow will import the game, run deterministic rules and a headless scene smoke test. Pending until the exact PR HEAD workflow completes.
- Limitations: custom simple platform collision, no art/audio/level editor, no manual GUI or iPhone device test.

## Existing-system regression

- Added `tests/inventory_mineral_catalog_compatibility_test.gd`.
- Verifies every MineralCatalog ID exists in SurvivalInventory.ITEM_WEIGHTS and both weight values match.
- Verifies all registered item weights are finite and non-negative.
- Injects an unknown key into the public counts dictionary and confirms total_weight_kg applies UNKNOWN_ITEM_WEIGHT_KG rather than granting zero-weight cargo; load_save_dict rejects that unknown-ID payload without mutation.
- This is a regression guard, not a claim that all game items have already been centralized into one catalog. The item list remains duplicated between inventory and mineral catalog, and this test detects drift.

## Git state and test evidence

- Base main: `789ba5fedd90c12afdf4b710c62a322682733bd2`.
- Candidate branch: `feature/run25-vent-runner-inventory-weight-audit-2026-10-27`.
- PR and canonical Godot 4.3 CI result must be recorded after creation and completion; do not merge before exact-head success.

## Next

- Run exact-head Godot 4.3 CI and fix failures before merge.
- Longer-term P1: introduce the actual production world-session controller and wire inventory/mining/save lifecycle; production controller is absent from current main.
- Manual GUI/GPU/iPhone QA remains outstanding because no local Godot executable is available.
