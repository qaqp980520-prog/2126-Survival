# Mineral Chunk Controller M0.1.1 — Failure atomicity hardening — 2026-10-26

## Files
- systems/MineralChunkController.gd
- tests/mineral_chunk_controller_test.gd
- .github/workflows/godot-validation.yml

## Change
A failed chunk registration now detaches the candidate Node3D root and returns false without freeing it. The world generator retains ownership of the failed candidate and may inspect, repair, or retry it. This aligns failed-load behavior with the existing failed-unload contract: a failed operation must not silently destroy caller state.

Added integration coverage for:
- duplicate stable-ID load rejection while preserving the unparented caller root;
- unload failure after an earlier vein was unregistered, verifying the earlier registration is rolled back and the chunk root remains owned;
- repairing the invalid vein record and retrying unload successfully.

## Dependencies / integration
Godot 4.3; MineralChunkController, MineralChunkLifecycleAdapter, MineralVeinRegistry, MineralMiningNode, MineralCatalog. The world generator still creates chunk roots and must call load_chunk/unload_chunk explicitly.

## Validation status
- Code head `92568e240abe1bd25149bba5a8da47d41ab451ce` passed Godot 4.3 CI Run #123 (`40290454611`) on 2026-10-26. The expanded MineralChunkController integration tests passed, including failed-load ownership preservation and failed-unload rollback.
- A documentation/index reconciliation commit follows that validated code head; the final-head CI run must succeed before merge.
- No local GUI or iPhone test is claimed.

## Limitations / next step
The controller remains a lifecycle adapter, not a distance-based or asynchronous world streamer. Next integrate it with a formal world chunk producer and test end-to-end chunk creation, unloading, save/restore, and regeneration.
