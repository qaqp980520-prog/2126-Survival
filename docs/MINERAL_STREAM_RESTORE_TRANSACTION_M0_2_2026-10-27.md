# Mineral stream restore transaction M0.2 — 2026-10-27

## Scope

The surface streaming playground now treats stream-state restore as a transaction across player position, active chunk ownership, and the mineral registry snapshot.

## Behavior

- Validate the complete envelope and finite player position before mutation.
- Snapshot the currently serialized mineral registry before applying a candidate payload.
- Apply the candidate mineral state, then attempt to synchronize the requested chunk window.
- If target chunk generation or registration fails, preserve the original sync report, return the player to the prior position, reconcile the director from the controller's actual loaded IDs, and restore the pre-attempt mineral snapshot.
- Expose get_last_restore_report() with phase, rollback_complete, and target/recovery details so a world host can decide whether to retry or enter a safe state.
- Emit a warning if the rollback itself is incomplete; do not claim recovery succeeded merely because the restore function returned false.

## Files

- prototypes/SurfaceChunkStreamingPlayground.gd
- tests/surface_chunk_streaming_playground_test.gd
- .github/workflows/godot-validation.yml
- daily_games/KROLL_Vertical_Relay/

## Dependencies and import

Godot 4.3+ and the existing MineralChunkController, MineralVeinRegistry, and MineralGridStreamingDirector. Open daily_games/KROLL_Vertical_Relay/project.godot for the standalone game. The survival integration test runs from the root project using tests/surface_chunk_streaming_playground_test.gd.

## Regression coverage

The integration test injects a factory failure after at least one target chunk has loaded. It verifies the old player position, controller IDs, director IDs, saved vein IDs, and live ore count are restored, while the report preserves the original load_factory failure.

## Validation status

This is a PR candidate until the exact-head Godot 4.3 CI completes. No local Godot executable is available in this run, so local GUI or engine execution is not claimed.

## Known limits

The surface playground remains an integration prototype, not the production world generator. The director is synchronous and factory-driven. If the recovery attempt itself fails, the report explicitly indicates incomplete rollback; a production host must decide how to pause streaming or retry safely.
