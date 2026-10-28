# Run 32 — KROLL Greenhouse Keeper and CropRegistry lifecycle M0.1

Date: 2026-10-28 (Asia/Taipei)

## New playable game

Path: daily_games/KROLL_Greenhouse_Keeper/

- Godot 4.3+, standalone project, no external assets/add-ons.
- Three deterministic crop plots (wheat, tomato, carrot), day counter, limited water, moisture decay, stage progression, harvest yield target, restart and next layout.
- Import: open daily_games/KROLL_Greenhouse_Keeper/project.godot in Godot Project Manager.
- Tests: tests/rules_test.gd and tests/game_smoke_test.gd.
- Validation: exact-head Godot 4.3 CI must pass the import, rules and runtime smoke steps before merge. No local Godot GUI/GPU/iPhone test is claimed.

## Existing system change

systems/CropRegistry.gd is extended from a data-only stable-ID registry with deterministic lifecycle operations:

- water_crop(stable_id, amount, now_unix): accepts only finite positive water amounts, clamps moisture to 100, and does not mutate a saturated crop.
- advance_growth(stable_id, elapsed_seconds, now_unix): accepts bounded finite elapsed time, drains moisture at a fixed rate, grows only while moisture remains, advances multiple stages deterministically and clamps mature crops at stage 4.
- harvest_crop(stable_id, now_unix): only mature crops can be harvested; harvest_count increments and the crop resets to stage zero with a soil-moisture cost.
- All operations validate a detached candidate record before replacing the live record; invalid requests leave the prior record unchanged.

## Compatibility and limits

- Existing schema 1 is unchanged; no new persisted fields are required.
- Existing register/update/save/restore methods remain compatible.
- The active-world save envelope already stores CropRegistry records. This change adds lifecycle methods but does not yet bind them to a production world controller or scene-based planting/harvesting interactions.
- Growth is caller-driven and deterministic; no background timer runs inside CropRegistry.
- Next: connect lifecycle calls to a formal world-session controller, implement crop visuals and interactions, and test unload/reload with crop state in generated chunks.
