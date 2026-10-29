# Run 37 — Skyline Courier and streamed crop offline growth

Date: 2026-10-29
Engine target: Godot 4.3+
Status: feature candidate; final CI is required before merge.

## New playable game: KROLL Skyline Courier M0.1

- Project: `daily_games/KROLL_Skyline_Courier/project.godot`
- Main scene/script: `daily_games/KROLL_Skyline_Courier/main.tscn`, `main.gd`
- Rules: `rules.gd`
- Tests: `tests/rules_test.gd`, `tests/game_smoke_test.gd`
- Dependencies: Godot 4.3+, no external assets or add-ons.
- Import: open the project path in Godot Project Manager.
- Controls: A/Left and D/Right move lanes; on-screen LEFT/CENTER/RIGHT select lanes; R resets; N selects the next seeded route.
- Rules: three lives, 45-second delivery window, dodge hazards and collect six data packets.
- Test plan: shared CI must import the project, run deterministic rule tests and run the scene smoke test.
- Limits: headless tests do not replace manual GUI, GPU performance or iPhone testing.

## Existing system: offline crop growth on streamed chunk reload

- Modified: `systems/CropRegistry.gd`, `systems/CropPlotController.gd`, `systems/MineralChunkController.gd`.
- Added regression: `tests/crop_registry_lifecycle_test.gd`, `tests/crop_chunk_offline_growth_test.gd`.
- A crop's persisted `last_updated_unix` is used to calculate offline elapsed time when its stable-ID chunk is loaded again.
- Catch-up uses the existing schema 1 record; no migration is required.
- Catch-up is bounded to at most one simulated day per invocation. With moisture capped at 100 and drain 0.25/s, the crop reaches the dry steady state within 400 seconds; a longer absence cannot create additional growth after water runs out.
- Multiple crops are advanced as one transaction. A backwards clock leaves the batch unchanged. If later mineral registration rejects the chunk, the crop snapshot is restored before returning failure.
- Limits: this does not create the missing production `scripts/world.gd` controller, nor does it persist every generated terrain/object state. Crop visuals remain a prototype-level scene integration.

## Required acceptance evidence

- Exact candidate SHA must pass the shared Godot 4.3 workflow.
- Expected new steps: Skyline Courier import, rules, runtime smoke; crop offline growth integration.
- Existing root project, crop lifecycle, mineral chunk controller and streamed-world regression tests must also pass.
- Do not merge before all steps pass.
