# Mineral Grid Streaming Recovery M0.2 — 2026-10-27

## Scope

Add an explicit recovery entry point to MineralGridStreamingDirector for a failed transactional window shift. It rebuilds the director's managed-ID map from the controller's actual loaded IDs, validates that every ID follows the director's stable grid-ID format, then retries synchronization around a supplied world position.

## Files

- systems/MineralGridStreamingDirector.gd
- tests/mineral_grid_streaming_diagnostics_test.gd
- docs/MINERAL_GRID_STREAMING_RECOVERY_M0_2_2026-10-27.md
- .github/workflows/godot-validation.yml
- PROJECT_INDEX.md

## Contract

- recover_to_world_position(world_position, now_unix) requires a controller exposing get_loaded_chunk_ids().
- IDs must match surface/chunk_X_Z with integer X and Z. Unknown IDs are rejected before the director changes its managed map.
- A valid actual-ID snapshot becomes the new managed map, then the normal transactional sync is retried.
- A retry can still fail; callers must inspect get_last_sync_report() and must not assume recovery always succeeds.
- This is a recovery API for the existing synchronous/factory-driven director, not production world-generator wiring or asynchronous streaming.

## Test plan

The diagnostics test injects an incomplete rollback, then disables the injected factory failure and retries toward the previous world position. It asserts that the missing chunk is restored and the controller/director ID sets match. It also injects an unknown controller ID and verifies recovery rejects it without mutating the director's previous map.

## Dependencies and import

Godot 4.3+, existing MineralChunkController contract, MineralVeinRegistry and the fake controller in tests/helpers. Open the repository root project.godot; CI imports root resources before root-level tests.

## Validation status

Candidate only until the exact PR head Godot 4.3 workflow passes. No local Godot executable, GUI/GPU, or iPhone test is claimed.

## Remaining limitations

- The production world generator is not connected.
- Chunk loading remains synchronous.
- Recovery cannot recreate a chunk if the factory or controller continues failing; the diagnostic report remains the source of truth.

## Next

Validate the candidate on GitHub Actions, merge only after exact-head success, then update this document and PROJECT_INDEX with final merge SHA and post-merge main CI evidence.
