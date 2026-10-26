# MineralGridStreamingDirector failure diagnostics M0.1 — 2026-10-27

## Files
- systems/MineralGridStreamingDirector.gd
- tests/mineral_grid_streaming_diagnostics_test.gd
- tests/helpers/FakeMineralChunkController.gd (existing failure-injection controller; no behavior change required)
- .github/workflows/godot-validation.yml
- PROJECT_INDEX.md

## Changes
- Adds the sync_failed(report) signal and get_last_sync_report() snapshot API.
- Reports success, phase, message, rollback completeness, failure chunk ID, newly loaded IDs, stale IDs restored/attempted, and snapshots of director-managed versus controller-loaded IDs.
- Makes get_grid_coordinate() return Vector2i.ZERO for invalid chunk dimensions instead of dividing by zero.
- Incomplete rollback emits a warning with an explicit pointer to the diagnostic report rather than only an opaque error line. The sync call still returns false.
- Adds failure injection where a stale unload fails after one stale chunk was removed and the factory then fails to recreate that removed chunk. The test confirms the incomplete rollback is observable and the report matches the actual active set.

## Dependencies and import
- Godot 4.3+.
- Uses the existing MineralChunkController, MineralVeinRegistry and FakeMineralChunkController.
- No external assets or addons.
- Open the repository root project.godot in Godot Project Manager; CI imports the root project before running root-level tests.

## Validation
- Exact-head Godot 4.3 CI Run #272 (`40356509039`) passed on feature head `656d3727c41551ef9ef38ecbc8c34213a4afa23f`. The diagnostics test passed with the expected WARNING for injected incomplete rollback; workflow guards found no SCRIPT ERROR, ERROR, or FAIL output.
- PR #58 merged as `d2eef1c4a30c67116f8bc8a1cb9c3df94bacc561`.
- Main push CI Run #273 (`40356977715`) passed on that merge commit.
- This environment has no local Godot executable; no local engine test or graphical playtest is claimed.
- No iPhone device test is claimed.

## Limits and next steps
- The director remains synchronous and factory-driven. It is not yet wired into a production world generator and does not provide asynchronous loading, terrain/biome generation, networking, or mobile movement.
- If a world factory repeatedly fails during rollback, the previous active set cannot be fully reconstructed; the new report makes this partial state explicit so the world host can retry or transition to a recovery path.
