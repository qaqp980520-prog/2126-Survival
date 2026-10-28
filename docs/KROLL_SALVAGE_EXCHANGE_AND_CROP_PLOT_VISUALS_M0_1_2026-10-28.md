# Run 34 — Salvage Exchange + Crop Plot Visuals M0.1

Date: 2026-10-28 (Asia/Taipei)

## Start-of-run source reconciliation

- GitHub main at start: `56a3ba086a802c601f30c2add4bc140aadc26ff2`; compare main against that SHA returned identical.
- PR #100/#101 from Run 33 are closed/merged; open PR search returned empty.
- Notion asset index and Run 33 daily/CropPlotController pages were fetched. They agree that CropPlotController is API-integrated into BackroomsPortalPlayground, but crop meshes/proximity interaction, formal `scripts/world.gd`, full chunk-scene persistence and asynchronous streaming remain open.
- The main branch has no Run 34 branch at start. Work is isolated on `feature/run34-salvage-exchange-crop-plot-visuals-2026-10-28`.

## New playable game

- Path: `daily_games/KROLL_Salvage_Exchange/`.
- Deterministic single-player trading game: buy/sell Copper, Polymer, Circuit and Alloy; 5% rounded-up transaction fee; cargo capacity 10; contract closes after day 8; target net worth 150.
- Controls: keys 1–4 select item, B buy one, S sell one, Enter close/advance day, R restart, N next seed; on-screen trade buttons support mouse/touch.
- Dependencies: Godot 4.3+, no external assets/add-ons. Import `daily_games/KROLL_Salvage_Exchange/project.godot`.
- Tests: `tests/rules_test.gd`, `tests/game_smoke_test.gd`. Expected route seed 3: copper price 4 on day 1, buy 10 for 42 including fee, sell on day 2 at 16 for 152 net, ending at 210 credits.

## Existing system integration

- Added `systems/CropPlotVisual.gd`, a procedural visible soil bed, stem, mature fruit and Label3D status for stable crop IDs.
- BackroomsPortalPlayground builds four surface plots around the spawn area. Press E near a plot to plant its configured crop; subsequent E interactions water dry plots, advance a bounded 120-second growth interval, and harvest mature plots. CropRegistry remains the source of truth; existing schema 1 is unchanged.
- Added `tests/crop_plot_visual_integration_test.gd` to test the real active-world scene, all four views, planting, growth, water/advance cycles, mature fruit visibility, harvest count and save/reload.

## Validation policy and limits

- Exact-head Godot 4.3 CI must pass the game import/rules/runtime tests, crop visual integration, and all prior regressions before merge.
- Local environment has no Godot executable, so no local engine/GUI/GPU/iPhone hardware test is claimed.
- The crop plots are procedural prototype visuals in the active playground, not the formal production `scripts/world.gd` controller. Full chunk-scene persistence and asynchronous streaming remain open.
